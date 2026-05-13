#!/usr/bin/env python3
"""Validate rRadio canonical data and generated artifacts.

Usage:
    python scripts/pack.py validate     # Run all checks
    python scripts/pack.py --help       # Show options

Can also be imported and called from pack.py.
"""

from __future__ import annotations

import re
import sys
import json
from pathlib import Path

import build_locale_artifacts
import build_station_artifacts
from generated_payloads import (
    CLIENT_SENT_LZMA_HARD_LIMIT,
    CLIENT_SENT_LZMA_TARGET,
    lua_sent_lzma_size,
    parse_payload_lua_wrapper,
)
from pack import (
    LOCALE_SOURCE_DIR,
    PACK_SIZE_LIMIT,
    STATIONS_DIR,
    expect,
    minify_station_country,
    parse_station_pack,
    parse_lua_string,
    skip_ws,
)

REPO_ROOT = Path(__file__).resolve().parent.parent
STATION_SOURCE_PATH = REPO_ROOT / "data" / "stations.json"
SERVER_STATION_ARTIFACT = REPO_ROOT / "lua" / "rradio" / "server" / "stations" / "builtin_registry.lua"
CLIENT_STATION_ARTIFACT = REPO_ROOT / "lua" / "rradio" / "client" / "stations" / "builtin_catalog.lua"
CLIENT_STATION_CHUNKS = REPO_ROOT / "lua" / "rradio" / "client" / "stations" / "generated"
CLIENT_LOCALE_ARTIFACTS = REPO_ROOT / "lua" / "rradio" / "client" / "lang"
CLIENT_LUA_ROOT = REPO_ROOT / "lua" / "rradio" / "client"
STATION_ID_RE = re.compile(r"^[A-Za-z0-9_\-:.]+$")
STATION_URL_RE = re.compile(r"^(https?|mms)://", re.IGNORECASE)
UI_KEY_PATTERNS = (
    re.compile(r'rRadio\.L\(\s*"([^"]+)"'),
    re.compile(
        r'\b(?:labelKey|helpKey|buttonKey|confirmTitleKey|'
        r'confirmMessageKey|confirmActionKey)\s*=\s*"([^"]+)"'
    ),
)
SERVER_STATION_ROW_RE = re.compile(r'\["(?:\\.|[^"\\])*"\]=\{"')
SERVER_FUNCTION_RE = re.compile(
    r'^local function addServerStations\d+\( countries \)\n(?P<body>.*?)^end$',
    re.MULTILINE | re.DOTALL,
)


def _format_country_key(raw_key: str) -> str:
    """Replicate rRadio.util.FormatCountryKey: underscore to space, title-case words."""
    return re.sub(
        r"([a-zA-Z])([a-zA-Z']*)",
        lambda m: m.group(1).upper() + m.group(2).lower(),
        raw_key.replace("_", " "),
    )


def _is_localisation_scan_target(path: Path) -> bool:
    relative = path.relative_to(CLIENT_LUA_ROOT)
    parts = relative.parts
    if parts and parts[0] == "lang":
        return False
    if len(parts) >= 2 and parts[0] == "stations" and parts[1] == "generated":
        return False

    return True


def _extract_client_ui_keys() -> set[str]:
    keys: set[str] = set()
    if not CLIENT_LUA_ROOT.exists():
        return keys

    for path in sorted(CLIENT_LUA_ROOT.rglob("*.lua")):
        if not _is_localisation_scan_target(path):
            continue

        text = path.read_text(encoding="utf-8")
        for pattern in UI_KEY_PATTERNS:
            for key in pattern.findall(text):
                if key.endswith("."):
                    continue
                keys.add(key)

    return keys


def _extract_client_station_ids(chunk_text: str) -> set[str]:
    station_ids: set[str] = set()
    pos = skip_ws(chunk_text, 0)
    if chunk_text[pos : pos + 6] == "return":
        pos = skip_ws(chunk_text, pos + 6)

    pos = expect(chunk_text, pos, "{")
    while True:
        pos = skip_ws(chunk_text, pos)
        if pos >= len(chunk_text):
            raise ValueError("unterminated client station chunk")
        if chunk_text[pos] == "}":
            return station_ids
        if chunk_text[pos] == ",":
            pos += 1
            continue

        pos = expect(chunk_text, pos, "{")
        pos = skip_ws(chunk_text, pos)
        country_key, pos = parse_lua_string(chunk_text, pos)
        pos = expect(chunk_text, pos, ",")
        pos = skip_ws(chunk_text, pos)
        _country_name, pos = parse_lua_string(chunk_text, pos)
        pos = expect(chunk_text, pos, ",")
        pos = expect(chunk_text, pos, "{")

        prefix = f"builtin:{country_key}:"
        while True:
            pos = skip_ws(chunk_text, pos)
            if pos >= len(chunk_text):
                raise ValueError("unterminated client station country block")
            if chunk_text[pos] == "}":
                pos += 1
                break
            if chunk_text[pos] == ",":
                pos += 1
                continue

            pos = expect(chunk_text, pos, "{")
            pos = skip_ws(chunk_text, pos)
            station_id, pos = parse_lua_string(chunk_text, pos)
            pos = expect(chunk_text, pos, ",")
            pos = skip_ws(chunk_text, pos)
            _station_name, pos = parse_lua_string(chunk_text, pos)
            pos = expect(chunk_text, pos, "}")
            if station_id.startswith("builtin:"):
                station_ids.add(station_id)
            else:
                station_ids.add(prefix + station_id)

        pos = expect(chunk_text, pos, "}")


def _check_client_sent_size(path: Path) -> int:
    sent_size = lua_sent_lzma_size(path.read_text(encoding="utf-8"))
    if sent_size > CLIENT_SENT_LZMA_HARD_LIMIT:
        print(
            f"  ERROR: {path.name} exceeds AddCSLuaFile hard limit: {sent_size}",
            file=sys.stderr,
        )
        return 1
    if sent_size > CLIENT_SENT_LZMA_TARGET:
        print(
            f"  ERROR: {path.name} exceeds compressed target: {sent_size}",
            file=sys.stderr,
        )
        return 1

    return 0


def _extract_client_station_rows_from_payload(
    payload: dict,
) -> tuple[dict[str, str], dict[str, list[tuple[str, str]]]]:
    station_rows: dict[str, str] = {}
    country_rows: dict[str, list[tuple[str, str]]] = {}
    countries = payload.get("countries")
    if not isinstance(countries, list):
        raise ValueError("missing countries list")

    for country_block in countries:
        if not isinstance(country_block, list) or len(country_block) < 3:
            raise ValueError("invalid country block")

        country_key = country_block[0]
        country_name = country_block[1]
        stations = country_block[2]
        if not isinstance(country_key, str) or not isinstance(country_name, str):
            raise ValueError("invalid country station block")
        if not isinstance(stations, list):
            raise ValueError("invalid country station rows")
        if country_key in country_rows:
            raise ValueError(f"duplicate country block {country_key!r}")
        if country_name != _format_country_key(country_key):
            raise ValueError(f"country {country_key!r} has generated name {country_name!r}")

        rows: list[tuple[str, str]] = []
        country_rows[country_key] = rows
        prefix = f"builtin:{country_key}:"
        for row in stations:
            if (
                not isinstance(row, list)
                or len(row) < 2
                or not isinstance(row[0], str)
                or not isinstance(row[1], str)
            ):
                raise ValueError("invalid station row")

            station_id = row[0] if row[0].startswith("builtin:") else prefix + row[0]
            if station_id in station_rows:
                raise ValueError(f"duplicate station row {station_id!r}")
            station_rows[station_id] = row[1]
            rows.append((station_id, row[1]))

    return station_rows, country_rows


def _parse_lua_int(text: str, pos: int) -> tuple[int, int]:
    pos = skip_ws(text, pos)
    match = re.match(r"\d+", text[pos:])
    if not match:
        got = text[pos] if pos < len(text) else "EOF"
        raise ValueError(f"Expected integer at pos {pos}, got {got!r}")
    return int(match.group(0)), pos + len(match.group(0))


def _parse_client_catalog_index(text: str) -> tuple[int, list[tuple[str, str, int, list[str]]]]:
    station_count_match = re.search(r"\bstationCount\s*=\s*(\d+)", text)
    if not station_count_match:
        raise ValueError("missing stationCount")

    countries_match = re.search(r"\bcountries\s*=", text)
    if not countries_match:
        raise ValueError("missing countries table")

    pos = skip_ws(text, countries_match.end())
    pos = expect(text, pos, "{")
    countries: list[tuple[str, str, int, list[str]]] = []

    while True:
        pos = skip_ws(text, pos)
        if pos >= len(text):
            raise ValueError("unterminated countries table")
        if text[pos] == "}":
            return int(station_count_match.group(1)), countries
        if text[pos] == ",":
            pos += 1
            continue

        pos = expect(text, pos, "{")
        pos = skip_ws(text, pos)
        country_key, pos = parse_lua_string(text, pos)
        pos = expect(text, pos, ",")
        pos = skip_ws(text, pos)
        country_name, pos = parse_lua_string(text, pos)
        pos = expect(text, pos, ",")
        station_count, pos = _parse_lua_int(text, pos)
        pos = expect(text, pos, ",")
        pos = expect(text, pos, "{")

        chunk_names: list[str] = []
        while True:
            pos = skip_ws(text, pos)
            if pos >= len(text):
                raise ValueError("unterminated country chunk table")
            if text[pos] == "}":
                pos += 1
                break
            if text[pos] == ",":
                pos += 1
                continue
            chunk_name, pos = parse_lua_string(text, pos)
            chunk_names.append(chunk_name)

        pos = expect(text, pos, "}")
        countries.append((country_key, country_name, station_count, chunk_names))


def _numbered_names(prefix: str, count: int) -> set[str]:
    return {f"{prefix}_{index:03d}.lua" for index in range(1, count + 1)}


def _validate_client_catalog_index(
    text: str,
    canonical_stations: list[dict[str, str]],
    chunk_country_rows: dict[str, dict[str, list[tuple[str, str]]]],
) -> list[str]:
    errors: list[str] = []
    try:
        station_count, actual_countries = _parse_client_catalog_index(text)
    except Exception as exc:
        return [f"client station index parse failed: {exc}"]

    if station_count != len(canonical_stations):
        errors.append(f"client station index has {station_count} stations, expected {len(canonical_stations)}")

    expected_country_rows: dict[str, list[tuple[str, str]]] = {}
    expected_countries: list[tuple[str, str, int]] = []
    for country in build_station_artifacts.build_client_country_index(canonical_stations):
        country_key = str(country["key"])
        rows = [
            (str(station["id"]), str(station["name"]))
            for station in country["stations"]
        ]
        expected_country_rows[country_key] = rows
        expected_countries.append((country_key, str(country["name"]), len(rows)))
    if len(actual_countries) != len(expected_countries):
        errors.append(
            f"client station index has {len(actual_countries)} countries, expected {len(expected_countries)}"
        )

    referenced_chunks: set[str] = set()
    seen_countries: set[str] = set()
    for index, (country_key, country_name, country_count, chunk_names) in enumerate(actual_countries):
        if country_key in seen_countries:
            errors.append(f"client station index contains duplicate country {country_key!r}")
        seen_countries.add(country_key)

        if index < len(expected_countries):
            expected_key, expected_name, expected_count = expected_countries[index]
            if (country_key, country_name, country_count) != (
                expected_key,
                expected_name,
                expected_count,
            ):
                errors.append(
                    "client station index country mismatch at "
                    f"{index}: got {(country_key, country_name, country_count)!r}, "
                    f"expected {(expected_key, expected_name, expected_count)!r}"
                )
                continue

        if len(set(chunk_names)) != len(chunk_names):
            errors.append(f"client station index repeats a chunk reference for {country_key!r}")

        indexed_rows: list[tuple[str, str]] = []
        for chunk_name in chunk_names:
            referenced_chunks.add(chunk_name)
            chunk_rows = chunk_country_rows.get(chunk_name)
            if chunk_rows is None:
                errors.append(f"client station index references missing chunk {chunk_name}")
                continue
            country_rows = chunk_rows.get(country_key)
            if country_rows is None:
                errors.append(
                    f"client station index references {chunk_name} for {country_key!r}, "
                    "but the chunk has no matching country block"
                )
                continue
            indexed_rows.extend(country_rows)

        if len(indexed_rows) != country_count:
            errors.append(
                f"client station index references {len(indexed_rows)} rows for {country_key!r}, "
                f"expected {country_count}"
            )
        elif indexed_rows != expected_country_rows.get(country_key, []):
            errors.append(f"client station index row order for {country_key!r} does not match canonical JSON")

    actual_chunks = set(chunk_country_rows)
    if referenced_chunks != actual_chunks:
        missing = sorted(actual_chunks - referenced_chunks)
        extra = sorted(referenced_chunks - actual_chunks)
        if missing:
            errors.append(f"client station index does not reference chunks: {', '.join(missing)}")
        if extra:
            errors.append(f"client station index references unknown chunks: {', '.join(extra)}")

    return errors


def validate(
    stations_dir: Path = STATIONS_DIR,
    locale_source_dir: Path = LOCALE_SOURCE_DIR,
) -> int:
    """Validate canonical data and generated artifacts. Returns 0 on success, 1 on errors."""
    errors = 0
    warnings = 0

    # --- Canonical JSON station source and generated runtime artifacts ---
    print("Validating canonical station source...")
    source_station_count = 0
    source_station_ids: set[str] = set()
    canonical_stations: list[dict[str, str]] = []
    if not STATION_SOURCE_PATH.exists():
        print(f"  ERROR: missing {STATION_SOURCE_PATH.relative_to(REPO_ROOT)}", file=sys.stderr)
        errors += 1
    else:
        try:
            stations_json = json.loads(STATION_SOURCE_PATH.read_text(encoding="utf-8"))
            if not isinstance(stations_json, list):
                raise ValueError("top-level value must be a list")

            expected_order = sorted(
                stations_json,
                key=lambda station: (station.get("countryKey", ""), station.get("name", ""), station.get("id", "")),
            )
            if stations_json != expected_order:
                print("  ERROR: canonical station JSON is not in deterministic order", file=sys.stderr)
                errors += 1

            seen_station_ids: set[str] = set()
            seen_urls: dict[str, int] = {}
            for index, station in enumerate(stations_json):
                if not isinstance(station, dict):
                    print(f"  ERROR: station[{index}] must be an object", file=sys.stderr)
                    errors += 1
                    continue

                station_id = station.get("id", "")
                if not isinstance(station_id, str) or not STATION_ID_RE.match(station_id):
                    print(f"  ERROR: station[{index}] has invalid id", file=sys.stderr)
                    errors += 1
                elif station_id in seen_station_ids:
                    print(f"  ERROR: duplicate station id {station_id}", file=sys.stderr)
                    errors += 1
                else:
                    seen_station_ids.add(station_id)

                for field in ("name", "url", "countryKey", "source"):
                    if not isinstance(station.get(field), str) or not station[field]:
                        print(f"  ERROR: station[{index}] missing {field}", file=sys.stderr)
                        errors += 1

                url = station.get("url", "")
                if isinstance(url, str) and url and not STATION_URL_RE.match(url):
                    print(f"  ERROR: station[{index}] has unsupported URL scheme", file=sys.stderr)
                    errors += 1
                elif isinstance(url, str) and url:
                    seen_urls[url] = seen_urls.get(url, 0) + 1

                if station.get("source") != "builtin":
                    print(f"  ERROR: station[{index}] source must be builtin", file=sys.stderr)
                    errors += 1

            duplicate_url_count = sum(1 for count in seen_urls.values() if count > 1)
            duplicate_url_rows = sum(count - 1 for count in seen_urls.values() if count > 1)
            if duplicate_url_count:
                print(f"  {duplicate_url_count} duplicate URL groups ({duplicate_url_rows} duplicate rows)")

            source_station_count = len(stations_json)
            source_station_ids = seen_station_ids
            canonical_stations = sorted(
                stations_json,
                key=lambda station: (station["countryKey"], station["name"], station["id"]),
            )
        except Exception as e:
            print(f"  ERROR: failed to parse canonical station JSON: {e}", file=sys.stderr)
            errors += 1

    for artifact in (SERVER_STATION_ARTIFACT, CLIENT_STATION_ARTIFACT):
        if not artifact.exists():
            print(f"  ERROR: missing generated artifact {artifact.relative_to(REPO_ROOT)}", file=sys.stderr)
            errors += 1

    if SERVER_STATION_ARTIFACT.exists():
        server_count = 0
        server_payload: dict | None = None
        try:
            server_wrapper = parse_payload_lua_wrapper(SERVER_STATION_ARTIFACT)
            if server_wrapper.kind != "server_station_registry":
                print("  ERROR: server station artifact has invalid payload kind", file=sys.stderr)
                errors += 1

            server_payload = server_wrapper.payload
            if server_payload.get("version") != 1:
                print("  ERROR: server station artifact has invalid payload version", file=sys.stderr)
                errors += 1

            countries = server_payload.get("countries")
            if not isinstance(countries, dict):
                print("  ERROR: server station artifact missing countries object", file=sys.stderr)
                errors += 1
            else:
                for country_key, country_stations in countries.items():
                    if not isinstance(country_stations, dict):
                        print(
                            f"  ERROR: server country {country_key!r} is not an object",
                            file=sys.stderr,
                        )
                        errors += 1
                        continue
                    server_count += len(country_stations)
        except Exception as e:
            print(f"  ERROR: server station artifact decode failed: {e}", file=sys.stderr)
            errors += 1

        if server_count != source_station_count:
            print(
                f"  ERROR: server station artifact has {server_count} stations, expected {source_station_count}",
                file=sys.stderr,
            )
            errors += 1
        elif canonical_stations:
            if server_payload is not None:
                expected_payload = build_station_artifacts.build_server_registry_payload(canonical_stations)
                if server_payload != expected_payload:
                    print(
                        "  ERROR: server station artifact payload does not match canonical station JSON",
                        file=sys.stderr,
                    )
                    errors += 1

    client_count = 0
    client_rows: dict[str, str] = {}
    chunk_country_rows: dict[str, dict[str, list[tuple[str, str]]]] = {}
    chunk_texts: dict[str, str] = {}
    if CLIENT_STATION_CHUNKS.exists():
        for chunk in sorted(CLIENT_STATION_CHUNKS.glob("catalog_*.lua")):
            errors += _check_client_sent_size(chunk)
            chunk_text = chunk.read_text(encoding="utf-8")
            chunk_texts[chunk.name] = chunk_text
            try:
                wrapper = parse_payload_lua_wrapper(chunk)
                if wrapper.kind != "client_station_catalog_chunk":
                    print(f"  ERROR: {chunk.name} has invalid payload kind", file=sys.stderr)
                    errors += 1
                if wrapper.payload.get("version") != 1:
                    print(f"  ERROR: {chunk.name} has invalid payload version", file=sys.stderr)
                    errors += 1

                chunk_rows, country_rows = _extract_client_station_rows_from_payload(wrapper.payload)
                for station_id, station_name in chunk_rows.items():
                    if station_id in client_rows:
                        print(f"  ERROR: duplicate client station row {station_id}", file=sys.stderr)
                        errors += 1
                    else:
                        client_rows[station_id] = station_name
                chunk_country_rows[chunk.name] = country_rows
                client_count += len(chunk_rows)
            except Exception as e:
                print(f"  ERROR: {chunk.name}: decode failed: {e}", file=sys.stderr)
                errors += 1

    if chunk_texts and set(chunk_texts) != _numbered_names("catalog", len(chunk_texts)):
        print("  ERROR: client station chunk files are not a contiguous catalog_### sequence", file=sys.stderr)
        errors += 1

    if client_count != source_station_count:
        print(
            f"  ERROR: client station chunks have {client_count} stations, expected {source_station_count}",
            file=sys.stderr,
        )
        errors += 1
    elif source_station_ids and set(client_rows) != source_station_ids:
        print("  ERROR: client station chunk IDs do not match canonical station IDs", file=sys.stderr)
        errors += 1
    elif canonical_stations:
        expected_names = {station["id"]: station["name"] for station in canonical_stations}
        mismatched_names = [
            station_id
            for station_id, expected_name in expected_names.items()
            if client_rows.get(station_id) != expected_name
        ]
        if mismatched_names:
            print(
                f"  ERROR: client station chunk names do not match canonical JSON: {mismatched_names[0]}",
                file=sys.stderr,
            )
            errors += 1

    if canonical_stations and CLIENT_STATION_ARTIFACT.exists():
        errors += _check_client_sent_size(CLIENT_STATION_ARTIFACT)
        client_index = CLIENT_STATION_ARTIFACT.read_text(encoding="utf-8")
        for index_error in _validate_client_catalog_index(
            client_index,
            canonical_stations,
            chunk_country_rows,
        ):
            print(f"  ERROR: {index_error}", file=sys.stderr)
            errors += 1

    print(f"  {source_station_count} canonical stations")

    # --- Stations ---
    print("Validating legacy station packs...")
    station_files = []
    if stations_dir.exists():
        for f in sorted(stations_dir.glob("*.lua")):
            text = f.read_text(encoding="utf-8")
            if text.lstrip().startswith("return"):
                station_files.append(f)

    all_countries: dict[str, Path] = {}
    total_stations = 0
    for f in station_files:
        text = f.read_text(encoding="utf-8")
        try:
            data = parse_station_pack(text)
        except Exception as e:
            print(f"  ERROR: {f.name}: parse failed: {e}", file=sys.stderr)
            errors += 1
            continue
        for country, st_list in data.items():
            if country in all_countries:
                print(
                    f"  ERROR: duplicate country '{country}' in {f.name} "
                    f"(also in {all_countries[country].name})",
                    file=sys.stderr,
                )
                errors += 1
            all_countries[country] = f
            for i, s in enumerate(st_list):
                if "n" not in s:
                    print(f"  ERROR: {f.name}: {country}[{i}] missing 'n' field", file=sys.stderr)
                    errors += 1
                if "u" not in s:
                    print(f"  ERROR: {f.name}: {country}[{i}] missing 'u' field", file=sys.stderr)
                    errors += 1
                total_stations += 1
            frag = minify_station_country(country, st_list)
            if len(frag.encode("utf-8")) > PACK_SIZE_LIMIT:
                print(f"  ERROR: {country} exceeds {PACK_SIZE_LIMIT} bytes when minified", file=sys.stderr)
                errors += 1

    print(f"  {len(station_files)} files, {len(all_countries)} countries, {total_stations} stations")

    # Derive reference country keys from canonical station data first. Legacy
    # station packs are intentionally absent in the rebuilt runtime.
    ref_country_keys: set[str] = set()
    for station in canonical_stations:
        ref_country_keys.add(_format_country_key(station["countryKey"]))

    for raw_key in all_countries:
        ref_country_keys.add(_format_country_key(raw_key))

    # --- Canonical locale JSON source and generated runtime artifacts ---
    print("Validating canonical locale source...")
    locale_files = sorted(locale_source_dir.glob("*.json")) if locale_source_dir.exists() else []
    all_locales: dict[str, dict] = {}
    if not locale_files:
        print(f"  ERROR: missing locale JSON files in {locale_source_dir}", file=sys.stderr)
        errors += 1
    else:
        try:
            all_locales = build_locale_artifacts.load_locales(locale_source_dir)
        except Exception as e:
            print(f"  ERROR: failed to load canonical locale JSON: {e}", file=sys.stderr)
            errors += 1

    # Reference UI and theme keys from English
    en_data = all_locales.get("en", {})
    en_ui_keys = set(en_data.get("ui", {}).keys())
    en_theme_keys = set(en_data.get("themes", {}).keys())
    used_ui_keys = _extract_client_ui_keys()
    missing_used_ui = used_ui_keys - en_ui_keys
    if missing_used_ui:
        print(f"  ERROR: English locale missing client UI keys: {', '.join(sorted(missing_used_ui))}", file=sys.stderr)
        errors += 1

    en_country_keys = set(en_data.get("countries", {}).keys())
    if ref_country_keys:
        missing_en_countries = sorted(ref_country_keys - en_country_keys)
        extra_en_countries = sorted(en_country_keys - ref_country_keys)
        if missing_en_countries:
            print(
                f"  ERROR: English locale missing {len(missing_en_countries)} country keys (vs stations): "
                f"{', '.join(missing_en_countries)}",
                file=sys.stderr,
            )
            errors += 1
        if extra_en_countries:
            print(
                f"  ERROR: English locale has {len(extra_en_countries)} extra country keys (vs stations): "
                f"{', '.join(extra_en_countries)}",
                file=sys.stderr,
            )
            errors += 1

    # Check each non-English locale
    langs_with_countries = 0
    for lang in sorted(all_locales):
        if lang == "en":
            continue
        ld = all_locales[lang]

        # UI keys
        lang_ui_keys = set(ld.get("ui", {}).keys())
        missing_ui = en_ui_keys - lang_ui_keys
        extra_ui = lang_ui_keys - en_ui_keys
        if missing_ui:
            print(f"  WARNING: {lang} missing UI keys: {', '.join(sorted(missing_ui))}")
            warnings += 1
        if extra_ui:
            print(f"  WARNING: {lang} has extra UI keys: {', '.join(sorted(extra_ui))}")
            warnings += 1

        # Theme keys
        lang_theme_keys = set(ld.get("themes", {}).keys())
        missing_themes = en_theme_keys - lang_theme_keys
        extra_themes = lang_theme_keys - en_theme_keys
        if missing_themes:
            print(f"  WARNING: {lang} missing theme keys: {', '.join(sorted(missing_themes))}")
            warnings += 1
        if extra_themes:
            print(f"  WARNING: {lang} has extra theme keys: {', '.join(sorted(extra_themes))}")
            warnings += 1

        # Country keys (compared against station-derived reference)
        # Only check for missing keys — extra translations for countries without
        # stations are harmless and expected.
        lang_countries = ld.get("countries", {})
        if lang_countries:
            langs_with_countries += 1
            if ref_country_keys:
                lang_country_keys = set(lang_countries.keys())
                missing_countries = ref_country_keys - lang_country_keys
                if missing_countries:
                    print(f"  WARNING: {lang} missing {len(missing_countries)} country keys (vs stations)")
                    warnings += 1

    if all_locales:
        actual_files = sorted(CLIENT_LOCALE_ARTIFACTS.glob("*.lua")) if CLIENT_LOCALE_ARTIFACTS.exists() else []
        actual_names = {path.name for path in actual_files}
        actual_locales: dict[str, dict[str, dict[str, str]]] = {}
        seen_locale_keys: set[tuple[str, str, str]] = set()

        if actual_names and actual_names != _numbered_names("data", len(actual_names)):
            print("  ERROR: generated locale chunks are not a contiguous data_### sequence", file=sys.stderr)
            errors += 1

        for path in actual_files:
            errors += _check_client_sent_size(path)
            try:
                wrapper = parse_payload_lua_wrapper(path)
                if wrapper.kind != "locale_chunk":
                    print(f"  ERROR: {path.name} has invalid payload kind", file=sys.stderr)
                    errors += 1
                if wrapper.payload.get("version") != 1:
                    print(f"  ERROR: {path.name} has invalid payload version", file=sys.stderr)
                    errors += 1

                payload_locales = wrapper.payload.get("locales")
                if not isinstance(payload_locales, dict):
                    print(f"  ERROR: {path.name} missing locales object", file=sys.stderr)
                    errors += 1
                else:
                    for lang, lang_data in payload_locales.items():
                        if not isinstance(lang, str) or not isinstance(lang_data, dict):
                            print(f"  ERROR: {path.name} has invalid locale payload", file=sys.stderr)
                            errors += 1
                            continue

                        target_lang = actual_locales.setdefault(lang, {})
                        for section, rows in lang_data.items():
                            if section not in build_locale_artifacts.SECTIONS or not isinstance(rows, dict):
                                print(
                                    f"  ERROR: {path.name} has invalid {lang!r} locale section",
                                    file=sys.stderr,
                                )
                                errors += 1
                                continue

                            target_section = target_lang.setdefault(section, {})
                            for key, value in rows.items():
                                marker = (lang, section, key)
                                if (
                                    not isinstance(key, str)
                                    or not isinstance(value, str)
                                    or marker in seen_locale_keys
                                ):
                                    print(
                                        f"  ERROR: {path.name} has duplicate or invalid {lang}.{section} row",
                                        file=sys.stderr,
                                    )
                                    errors += 1
                                    continue
                                seen_locale_keys.add(marker)
                                target_section[key] = value
            except Exception as e:
                print(f"  ERROR: {path.name}: decode failed: {e}", file=sys.stderr)
                errors += 1

        missing_langs = sorted(set(all_locales) - set(actual_locales))
        extra_langs = sorted(set(actual_locales) - set(all_locales))
        if missing_langs:
            print(f"  ERROR: generated locale payloads missing languages: {', '.join(missing_langs)}", file=sys.stderr)
            errors += 1
        if extra_langs:
            print(f"  ERROR: generated locale payloads have unexpected languages: {', '.join(extra_langs)}", file=sys.stderr)
            errors += 1
        if not missing_langs and not extra_langs:
            for lang in sorted(all_locales):
                if actual_locales.get(lang) != all_locales[lang]:
                    print(
                        f"  ERROR: generated locale payload for {lang} does not match canonical JSON",
                        file=sys.stderr,
                    )
                    errors += 1
                    break

    print(
        f"  {len(locale_files)} files, {len(all_locales)} languages, "
        f"{langs_with_countries} with country translations"
    )

    # --- Summary ---
    print()
    if errors or warnings:
        print(f"FAILED: {errors} error(s), {warnings} warning(s)")
        return 1
    print("PASSED: OK")
    return 0


def main() -> int:
    return validate()


if __name__ == "__main__":
    sys.exit(main())
