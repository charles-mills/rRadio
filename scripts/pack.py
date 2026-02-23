#!/usr/bin/env python3
"""Pack/unpack rRadio data files between human-readable per-entity Lua files
and minified packed files for Workshop releases.

Usage:
    python scripts/pack.py unpack   # One-time migration: packed -> per-entity
    python scripts/pack.py pack     # CI release: per-entity -> packed (in-place)
    python scripts/pack.py validate # Check all unpacked files for errors
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths (relative to repo root)
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parent.parent
LUA_ROOT = REPO_ROOT / "lua" / "rradio" / "client"

STATIONS_DIR = LUA_ROOT / "stations"
STATIONPACKS_DIR = LUA_ROOT / "data" / "stationpacks"  # legacy only
LOCALES_DIR = LUA_ROOT / "lang" / "locales"

# Legacy paths (only used by unpack for migration)
LANGPACKS_DIR = LUA_ROOT / "data" / "langpacks"
LOCALISATION_FILE = LUA_ROOT / "lang" / "cl_localisation_strings.lua"

PACK_SIZE_LIMIT = 63 * 1024  # 63 KB

# ---------------------------------------------------------------------------
# Lua string escaping
# ---------------------------------------------------------------------------

_LUA_ESCAPE_MAP = {
    "\\": "\\\\",
    "'": "\\'",
    "\n": "\\n",
    "\r": "\\r",
    "\t": "\\t",
}
_LUA_ESCAPE_RE = re.compile(r"[\\'\n\r\t]")


def lua_escape(s: str) -> str:
    """Escape a string for use inside Lua single quotes."""
    return _LUA_ESCAPE_RE.sub(lambda m: _LUA_ESCAPE_MAP[m.group()], s)


def lua_escape_double(s: str) -> str:
    """Escape a string for use inside Lua double quotes."""
    return (
        s.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )


# ---------------------------------------------------------------------------
# Lua parsing helpers
# ---------------------------------------------------------------------------


def parse_lua_string(text: str, pos: int) -> tuple[str, int]:
    """Parse a Lua string literal starting at *pos*. Returns (value, end_pos)."""
    quote = text[pos]
    assert quote in ("'", '"'), f"Expected quote at pos {pos}, got {quote!r}"
    i = pos + 1
    parts: list[str] = []
    while i < len(text):
        ch = text[i]
        if ch == "\\":
            nxt = text[i + 1]
            if nxt == "n":
                parts.append("\n")
            elif nxt == "r":
                parts.append("\r")
            elif nxt == "t":
                parts.append("\t")
            elif nxt == "\\":
                parts.append("\\")
            elif nxt == "'":
                parts.append("'")
            elif nxt == '"':
                parts.append('"')
            else:
                parts.append(nxt)
            i += 2
        elif ch == quote:
            return "".join(parts), i + 1
        else:
            parts.append(ch)
            i += 1
    raise ValueError(f"Unterminated string starting at pos {pos}")


def skip_ws(text: str, pos: int) -> int:
    """Skip whitespace and Lua line/block comments."""
    length = len(text)
    while pos < length:
        if text[pos] in (" ", "\t", "\n", "\r"):
            pos += 1
        elif text[pos : pos + 2] == "--":
            if text[pos + 2 : pos + 4] == "[[":
                end = text.find("]]", pos + 4)
                pos = end + 2 if end != -1 else length
            else:
                nl = text.find("\n", pos)
                pos = nl + 1 if nl != -1 else length
        else:
            break
    return pos


def expect(text: str, pos: int, ch: str) -> int:
    pos = skip_ws(text, pos)
    if pos >= len(text) or text[pos] != ch:
        got = text[pos] if pos < len(text) else "EOF"
        raise ValueError(f"Expected {ch!r} at pos {pos}, got {got!r}")
    return pos + 1


# ---------------------------------------------------------------------------
# Station pack parsing & writing
# ---------------------------------------------------------------------------


def parse_station_pack(text: str) -> dict[str, list[dict[str, str]]]:
    """Parse a station pack file: return{['country']={{n='...',u='...'},...},...}"""
    result: dict[str, list[dict[str, str]]] = {}
    pos = skip_ws(text, 0)
    if text[pos : pos + 6] == "return":
        pos = skip_ws(text, pos + 6)

    pos = expect(text, pos, "{")

    while True:
        pos = skip_ws(text, pos)
        if text[pos] == "}":
            break
        if text[pos] == ",":
            pos += 1
            continue

        pos = expect(text, pos, "[")
        pos = skip_ws(text, pos)
        country, pos = parse_lua_string(text, pos)
        pos = skip_ws(text, pos)
        pos = expect(text, pos, "]")
        pos = skip_ws(text, pos)
        pos = expect(text, pos, "=")
        pos = skip_ws(text, pos)

        pos = expect(text, pos, "{")
        stations: list[dict[str, str]] = []
        while True:
            pos = skip_ws(text, pos)
            if text[pos] == "}":
                pos += 1
                break
            if text[pos] == ",":
                pos += 1
                continue

            pos = expect(text, pos, "{")
            station: dict[str, str] = {}
            while True:
                pos = skip_ws(text, pos)
                if text[pos] == "}":
                    pos += 1
                    break
                if text[pos] == ",":
                    pos += 1
                    continue
                key_start = pos
                while text[pos] not in ("=", " ", "\t", "\n"):
                    pos += 1
                key = text[key_start:pos]
                pos = skip_ws(text, pos)
                pos = expect(text, pos, "=")
                pos = skip_ws(text, pos)
                val, pos = parse_lua_string(text, pos)
                station[key] = val
            stations.append(station)

        result[country] = stations

    return result


def write_station_file(path: Path, country: str, stations: list[dict[str, str]]) -> None:
    """Write a single per-country station file in readable Lua format.

    Stations are sorted alphabetically by name (case-insensitive).
    """
    lines = ["return {"]
    lines.append(f"    ['{lua_escape(country)}'] = {{")
    for s in sorted(stations, key=lambda s: s["n"].lower()):
        name = lua_escape(s["n"])
        url = lua_escape(s["u"])
        lines.append(f"        {{ n = '{name}', u = '{url}' }},")
    lines.append("    }")
    lines.append("}")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def minify_station_country(country: str, stations: list[dict[str, str]]) -> str:
    """Produce minified Lua fragment for one country."""
    entries = ",".join(
        f"{{n='{lua_escape(s['n'])}',u='{lua_escape(s['u'])}'}}" for s in stations
    )
    return f"['{lua_escape(country)}']={{{entries}}}"


# ---------------------------------------------------------------------------
# Legacy langpack parsing (for unpack from old packed format)
# ---------------------------------------------------------------------------


def parse_legacy_langpack(text: str) -> dict[str, dict[str, str]]:
    """Parse old minified langpack: local CountryTranslations=... CountryTranslations["lang"]={...}"""
    result: dict[str, dict[str, str]] = {}
    pattern = re.compile(r'CountryTranslations\["([^"]+)"\]\s*=\s*\{')
    for m in pattern.finditer(text):
        lang = m.group(1)
        pos = m.end()
        translations: dict[str, str] = {}
        while True:
            pos = skip_ws(text, pos)
            if pos >= len(text) or text[pos] == "}":
                break
            if text[pos] == ",":
                pos += 1
                continue
            pos = expect(text, pos, "[")
            pos = skip_ws(text, pos)
            key, pos = parse_lua_string(text, pos)
            pos = skip_ws(text, pos)
            pos = expect(text, pos, "]")
            pos = skip_ws(text, pos)
            pos = expect(text, pos, "=")
            pos = skip_ws(text, pos)
            val, pos = parse_lua_string(text, pos)
            translations[key] = val
        result[lang] = translations
    return result


def minify_langpack_lang(lang: str, translations: dict[str, str]) -> str:
    """Produce minified fragment: CountryTranslations["lang"]={["key"]="value",...}"""
    entries = ",".join(
        f'["{lua_escape_double(k)}"]="{lua_escape_double(v)}"'
        for k, v in sorted(translations.items())
    )
    return f'CountryTranslations["{lang}"]={{{entries}}}'


# ---------------------------------------------------------------------------
# Legacy localisation file parsing (for unpack from old packed format)
# ---------------------------------------------------------------------------


def parse_legacy_localisation_file(text: str) -> dict[str, dict]:
    """Parse old cl_localisation_strings.lua with TRANSLATIONS and THEME_TRANSLATIONS tables."""
    result: dict[str, dict] = {}

    def extract_table(name: str) -> dict[str, dict[str, str]]:
        pattern = re.compile(rf"(?:local\s+)?{name}\s*=\s*\{{")
        m = pattern.search(text)
        if not m:
            raise ValueError(f"Could not find table {name}")
        pos = m.end()
        table: dict[str, dict[str, str]] = {}
        while True:
            pos = skip_ws(text, pos)
            if pos >= len(text) or text[pos] == "}":
                break
            if text[pos] == ",":
                pos += 1
                continue
            if text[pos] == "[":
                pos = expect(text, pos, "[")
                pos = skip_ws(text, pos)
                lang, pos = parse_lua_string(text, pos)
                pos = skip_ws(text, pos)
                pos = expect(text, pos, "]")
            else:
                key_start = pos
                while pos < len(text) and text[pos] not in ("=", " ", "\t", "\n", ",", "}"):
                    pos += 1
                lang = text[key_start:pos]
            pos = skip_ws(text, pos)
            pos = expect(text, pos, "=")
            pos = skip_ws(text, pos)
            pos = expect(text, pos, "{")

            entries: dict[str, str] = {}
            while True:
                pos = skip_ws(text, pos)
                if text[pos] == "}":
                    pos += 1
                    break
                if text[pos] == ",":
                    pos += 1
                    continue
                if text[pos] == "[":
                    pos = expect(text, pos, "[")
                    pos = skip_ws(text, pos)
                    key, pos = parse_lua_string(text, pos)
                    pos = skip_ws(text, pos)
                    pos = expect(text, pos, "]")
                else:
                    ks = pos
                    while pos < len(text) and text[pos] not in ("=", " ", "\t", "\n"):
                        pos += 1
                    key = text[ks:pos]
                pos = skip_ws(text, pos)
                pos = expect(text, pos, "=")
                pos = skip_ws(text, pos)
                val, pos = parse_lua_string(text, pos)
                entries[key] = val
            table[lang] = entries
        return table

    ui_translations = extract_table("TRANSLATIONS")
    theme_translations = extract_table("THEME_TRANSLATIONS")

    all_langs = set(ui_translations.keys()) | set(theme_translations.keys())
    for lang in all_langs:
        result[lang] = {
            "ui": ui_translations.get(lang, {}),
            "themes": theme_translations.get(lang, {}),
        }

    return result


# ---------------------------------------------------------------------------
# Locale file parsing & writing (unified format with ui, themes, countries)
# ---------------------------------------------------------------------------


def parse_locale_file(text: str) -> dict[str, dict]:
    """Parse: return { ["lang"] = { ui = { ... }, themes = { ... }, countries = { ... } } }

    Returns {lang: {ui: {...}, themes: {...}, countries: {...}}, ...}
    """
    result: dict[str, dict] = {}
    pos = skip_ws(text, 0)
    if text[pos : pos + 6] == "return":
        pos = skip_ws(text, pos + 6)
    pos = expect(text, pos, "{")
    while True:
        pos = skip_ws(text, pos)
        if pos >= len(text) or text[pos] == "}":
            break
        if text[pos] == ",":
            pos += 1
            continue
        # ["lang"] = { ... }
        pos = expect(text, pos, "[")
        pos = skip_ws(text, pos)
        lang, pos = parse_lua_string(text, pos)
        pos = skip_ws(text, pos)
        pos = expect(text, pos, "]")
        pos = skip_ws(text, pos)
        pos = expect(text, pos, "=")
        pos = skip_ws(text, pos)
        pos = expect(text, pos, "{")

        lang_data: dict[str, dict[str, str]] = {}
        while True:
            pos = skip_ws(text, pos)
            if pos >= len(text) or text[pos] == "}":
                pos += 1
                break
            if text[pos] == ",":
                pos += 1
                continue
            # sub-table name (ui, themes, or countries)
            ks = pos
            while pos < len(text) and text[pos] not in ("=", " ", "\t", "\n"):
                pos += 1
            sub_name = text[ks:pos]
            pos = skip_ws(text, pos)
            pos = expect(text, pos, "=")
            pos = skip_ws(text, pos)
            pos = expect(text, pos, "{")
            entries: dict[str, str] = {}
            while True:
                pos = skip_ws(text, pos)
                if pos >= len(text) or text[pos] == "}":
                    pos += 1
                    break
                if text[pos] == ",":
                    pos += 1
                    continue
                if text[pos] == "[":
                    pos = expect(text, pos, "[")
                    pos = skip_ws(text, pos)
                    ekey, pos = parse_lua_string(text, pos)
                    pos = skip_ws(text, pos)
                    pos = expect(text, pos, "]")
                else:
                    eks = pos
                    while pos < len(text) and text[pos] not in ("=", " ", "\t", "\n"):
                        pos += 1
                    ekey = text[eks:pos]
                pos = skip_ws(text, pos)
                pos = expect(text, pos, "=")
                pos = skip_ws(text, pos)
                val, pos = parse_lua_string(text, pos)
                entries[ekey] = val
            lang_data[sub_name] = entries

        result[lang] = lang_data
    return result


def write_locale_file(path: Path, lang: str, data: dict) -> None:
    """Write a per-language locale file with ui, themes, and countries sub-tables."""
    lines = ["return {"]
    lines.append(f'    ["{lang}"] = {{')

    if data.get("ui"):
        lines.append("        ui = {")
        for key in sorted(data["ui"].keys()):
            val = lua_escape_double(data["ui"][key])
            lines.append(f'            ["{lua_escape_double(key)}"] = "{val}",')
        lines.append("        },")

    if data.get("themes"):
        lines.append("        themes = {")
        for key in sorted(data["themes"].keys()):
            val = lua_escape_double(data["themes"][key])
            lines.append(f"            {key} = \"{val}\",")
        lines.append("        },")

    if data.get("countries"):
        lines.append("        countries = {")
        for key in sorted(data["countries"].keys()):
            val = lua_escape_double(data["countries"][key])
            lines.append(f'            ["{lua_escape_double(key)}"] = "{val}",')
        lines.append("        },")

    lines.append("    }")
    lines.append("}")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def read_locale_files(directory: Path) -> dict[str, dict]:
    """Read all per-language locale .lua files from a directory."""
    result: dict[str, dict] = {}
    if not directory.exists():
        return result
    for f in sorted(directory.glob("*.lua")):
        text = f.read_text(encoding="utf-8")
        data = parse_locale_file(text)
        for lang, ld in data.items():
            if lang not in result:
                result[lang] = {}
            for sub in ("ui", "themes", "countries"):
                if sub in ld:
                    if sub not in result[lang]:
                        result[lang][sub] = {}
                    result[lang][sub].update(ld[sub])
    return result


def minify_locale_lang(lang: str, data: dict) -> str:
    """Produce minified Lua for one language (ui, themes, and countries)."""
    parts = []
    if data.get("ui"):
        ui_entries = ",".join(
            f'["{lua_escape_double(k)}"]="{lua_escape_double(v)}"'
            for k, v in sorted(data["ui"].items())
        )
        parts.append(f"ui={{{ui_entries}}}")
    if data.get("themes"):
        theme_entries = ",".join(
            f'{k}="{lua_escape_double(v)}"'
            for k, v in sorted(data["themes"].items())
        )
        parts.append(f"themes={{{theme_entries}}}")
    if data.get("countries"):
        country_entries = ",".join(
            f'["{lua_escape_double(k)}"]="{lua_escape_double(v)}"'
            for k, v in sorted(data["countries"].items())
        )
        parts.append(f"countries={{{country_entries}}}")
    return f'["{lang}"]={{{",".join(parts)}}}'


# ---------------------------------------------------------------------------
# Pack helpers (produce <= 63KB output files)
# ---------------------------------------------------------------------------


def pack_into_files(
    fragments: list[tuple[str, str]],
    output_dir: Path,
    header: str = "return{",
    footer: str = "}",
    separator: str = ",",
) -> list[Path]:
    """Pack (key, lua_fragment) pairs into numbered data_N.lua files <= PACK_SIZE_LIMIT.

    Uses First-Fit Decreasing bin-packing to minimise file count.
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    overhead = len(header.encode("utf-8")) + len(footer.encode("utf-8"))
    sep_size = len(separator.encode("utf-8"))

    # Calculate fragment sizes and sort largest-first (FFD)
    sized: list[tuple[int, str, str]] = []
    for key, frag in fragments:
        sized.append((len(frag.encode("utf-8")), key, frag))
    sized.sort(key=lambda x: x[0], reverse=True)

    # Bins: each is (remaining_capacity, [fragments])
    bins: list[tuple[int, list[str]]] = []
    capacity = PACK_SIZE_LIMIT - overhead

    for frag_size, key, frag in sized:
        if frag_size > capacity:
            raise ValueError(
                f"Fragment {key!r} is {frag_size} bytes, exceeds pack capacity "
                f"{capacity} bytes (limit {PACK_SIZE_LIMIT} incl. wrapper)"
            )
        # Cost of adding this fragment: fragment + separator (unless bin is empty)
        placed = False
        for i, (remaining, parts) in enumerate(bins):
            cost = frag_size + (sep_size if parts else 0)
            if cost <= remaining:
                parts.append(frag)
                bins[i] = (remaining - cost, parts)
                placed = True
                break

        if not placed:
            bins.append((capacity - frag_size, [frag]))

    # Write bins to files
    files: list[Path] = []
    for file_num, (_remaining, parts) in enumerate(bins, 1):
        content = header + separator.join(parts) + footer
        if len(content.encode("utf-8")) > PACK_SIZE_LIMIT:
            raise ValueError(
                f"Packed file data_{file_num}.lua exceeds {PACK_SIZE_LIMIT} bytes"
            )
        path = output_dir / f"data_{file_num}.lua"
        path.write_text(content, encoding="utf-8")
        files.append(path)

    return files


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------


def cmd_unpack(_args: argparse.Namespace) -> int:
    """Unpack packed data files into per-entity files.

    Handles both legacy formats (stationpacks/, old langpacks, cl_localisation_strings.lua)
    and current packed formats (stations/data_N.lua, langpacks/data_N.lua, locales/data_N.lua).
    Country translations are merged into locale files alongside ui and themes.
    """
    errors = 0

    # --- Stations ---
    station_source = None
    if STATIONPACKS_DIR.exists() and list(STATIONPACKS_DIR.glob("data_*.lua")):
        station_source = STATIONPACKS_DIR
    elif STATIONS_DIR.exists() and list(STATIONS_DIR.glob("data_*.lua")):
        station_source = STATIONS_DIR

    if station_source:
        STATIONS_DIR.mkdir(parents=True, exist_ok=True)
        total_countries = 0
        for f in sorted(station_source.glob("data_*.lua")):
            text = f.read_text(encoding="utf-8")
            try:
                data = parse_station_pack(text)
            except Exception as e:
                print(f"ERROR: Failed to parse {f.name}: {e}", file=sys.stderr)
                errors += 1
                continue
            for country, stations in data.items():
                write_station_file(STATIONS_DIR / f"{country}.lua", country, stations)
                total_countries += 1
        for f in STATIONS_DIR.glob("data_*.lua"):
            f.unlink()
        print(f"Stations: unpacked {total_countries} countries into {STATIONS_DIR}")
    else:
        print("Stations: no packed data_*.lua files found, skipping")

    # --- Collect all translation data from various sources ---
    locale_data: dict[str, dict] = {}

    # Legacy langpacks: local CountryTranslations=... CountryTranslations["lang"]={...}
    if LANGPACKS_DIR.exists():
        for f in sorted(LANGPACKS_DIR.glob("data_*.lua")):
            text = f.read_text(encoding="utf-8")
            try:
                data = parse_legacy_langpack(text)
                for lang, translations in data.items():
                    if lang not in locale_data:
                        locale_data[lang] = {}
                    locale_data[lang]["countries"] = translations
            except Exception as e:
                print(f"ERROR: Failed to parse {f.name}: {e}", file=sys.stderr)
                errors += 1

    # Legacy cl_localisation_strings.lua (ui + themes)
    if LOCALISATION_FILE.exists():
        text = LOCALISATION_FILE.read_text(encoding="utf-8")
        try:
            legacy_data = parse_legacy_localisation_file(text)
            for lang, ld in legacy_data.items():
                if lang not in locale_data:
                    locale_data[lang] = {}
                for sub in ("ui", "themes"):
                    if sub in ld:
                        locale_data[lang][sub] = ld[sub]
        except Exception as e:
            print(f"ERROR: Failed to parse {LOCALISATION_FILE.name}: {e}", file=sys.stderr)
            errors += 1

    # Packed locales: locales/data_N.lua (ui + themes + countries)
    if LOCALES_DIR.exists():
        for f in sorted(LOCALES_DIR.glob("data_*.lua")):
            text = f.read_text(encoding="utf-8")
            try:
                data = parse_locale_file(text)
                for lang, ld in data.items():
                    if lang not in locale_data:
                        locale_data[lang] = {}
                    for sub in ("ui", "themes", "countries"):
                        if sub in ld:
                            locale_data[lang][sub] = ld[sub]
            except Exception as e:
                print(f"ERROR: Failed to parse {f.name}: {e}", file=sys.stderr)
                errors += 1

    # --- Write merged per-language locale files ---
    if locale_data:
        LOCALES_DIR.mkdir(parents=True, exist_ok=True)
        for lang in sorted(locale_data):
            write_locale_file(LOCALES_DIR / f"{lang}.lua", lang, locale_data[lang])

        # Clean up packed/legacy files
        for f in LOCALES_DIR.glob("data_*.lua"):
            f.unlink()
        if LANGPACKS_DIR.exists():
            for f in LANGPACKS_DIR.glob("data_*.lua"):
                f.unlink()
        if LOCALISATION_FILE.exists():
            LOCALISATION_FILE.unlink()

        print(f"Locales: unpacked {len(locale_data)} languages into {LOCALES_DIR}")
    else:
        print("Locales: no packed translation files found, skipping")

    return 1 if errors else 0


def cmd_pack(_args: argparse.Namespace) -> int:
    """Pack per-entity files into minified data_N.lua files for release.

    - stations/<country>.lua -> stations/data_N.lua
    - locales/<lang>.lua -> locales/data_N.lua (ui + themes + countries all together)
    """
    errors = 0

    # --- Stations ---
    stations: dict[str, list[dict[str, str]]] = {}
    if STATIONS_DIR.exists():
        for f in sorted(STATIONS_DIR.glob("*.lua")):
            text = f.read_text(encoding="utf-8")
            data = parse_station_pack(text)
            for country, st_list in data.items():
                stations[country] = st_list

    if stations:
        fragments = [
            (c, minify_station_country(c, stations[c])) for c in sorted(stations)
        ]
        for f in STATIONS_DIR.glob("*.lua"):
            f.unlink()
        packed = pack_into_files(fragments, STATIONS_DIR)
        print(f"Stations: packed {len(stations)} countries into {len(packed)} files")
    else:
        print("Stations: no per-country files found, skipping")

    # --- Locales (ui + themes + countries all packed together) ---
    locales = read_locale_files(LOCALES_DIR)
    if locales:
        locale_fragments = [
            (lang, minify_locale_lang(lang, locales[lang]))
            for lang in sorted(locales)
        ]
        for f in LOCALES_DIR.glob("*.lua"):
            f.unlink()
        packed = pack_into_files(locale_fragments, LOCALES_DIR)
        print(f"Locales: packed {len(locales)} languages into {len(packed)} files")
    else:
        print("Locales: no per-language locale files found, skipping")

    return errors


def cmd_validate(_args: argparse.Namespace) -> int:
    """Validate all unpacked data files (delegates to scripts/validate.py)."""
    from validate_localisation import validate

    return validate()


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _parse_return_kv_table(text: str) -> dict[str, dict[str, str]]:
    """Parse: return { ["key"] = { ["k"] = "v", ... }, ... }"""
    result: dict[str, dict[str, str]] = {}
    pos = skip_ws(text, 0)
    if text[pos : pos + 6] == "return":
        pos = skip_ws(text, pos + 6)
    pos = expect(text, pos, "{")
    while True:
        pos = skip_ws(text, pos)
        if pos >= len(text) or text[pos] == "}":
            break
        if text[pos] == ",":
            pos += 1
            continue
        pos = expect(text, pos, "[")
        pos = skip_ws(text, pos)
        key, pos = parse_lua_string(text, pos)
        pos = skip_ws(text, pos)
        pos = expect(text, pos, "]")
        pos = skip_ws(text, pos)
        pos = expect(text, pos, "=")
        pos = skip_ws(text, pos)
        pos = expect(text, pos, "{")
        entries: dict[str, str] = {}
        while True:
            pos = skip_ws(text, pos)
            if pos >= len(text) or text[pos] == "}":
                pos += 1
                break
            if text[pos] == ",":
                pos += 1
                continue
            if text[pos] == "[":
                pos = expect(text, pos, "[")
                pos = skip_ws(text, pos)
                ekey, pos = parse_lua_string(text, pos)
                pos = skip_ws(text, pos)
                pos = expect(text, pos, "]")
            else:
                ks = pos
                while pos < len(text) and text[pos] not in ("=", " ", "\t", "\n"):
                    pos += 1
                ekey = text[ks:pos]
            pos = skip_ws(text, pos)
            pos = expect(text, pos, "=")
            pos = skip_ws(text, pos)
            val, pos = parse_lua_string(text, pos)
            entries[ekey] = val
        result[key] = entries
    return result


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(description="Pack/unpack rRadio data files")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("unpack", help="Unpack packed data files into per-entity files")
    sub.add_parser("pack", help="Pack per-entity files into minified data_N.lua files")
    sub.add_parser("validate", help="Validate all unpacked data files")
    args = parser.parse_args()

    commands = {
        "unpack": cmd_unpack,
        "pack": cmd_pack,
        "validate": cmd_validate,
    }
    return commands[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
