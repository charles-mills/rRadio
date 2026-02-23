#!/usr/bin/env python3
"""Validate rRadio unpacked data files for completeness and correctness.

Usage:
    python scripts/validate.py          # Run all checks
    python scripts/validate.py --help   # Show options

Can also be imported and called from pack.py.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from pack import (
    LOCALES_DIR,
    PACK_SIZE_LIMIT,
    STATIONS_DIR,
    minify_station_country,
    parse_locale_file,
    parse_station_pack,
)


def _format_country_key(raw_key: str) -> str:
    """Replicate rRadio.utils.FormatCountryKey: underscore to space, title-case words."""
    return re.sub(
        r"([a-zA-Z])([a-zA-Z']*)",
        lambda m: m.group(1).upper() + m.group(2).lower(),
        raw_key.replace("_", " "),
    )


def validate(
    stations_dir: Path = STATIONS_DIR,
    locales_dir: Path = LOCALES_DIR,
) -> int:
    """Validate all unpacked data files. Returns 0 on success, 1 on errors."""
    errors = 0
    warnings = 0

    # --- Stations ---
    print("Validating stations...")
    station_files = sorted(stations_dir.glob("*.lua")) if stations_dir.exists() else []
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

    # Derive reference country keys from station data (the actual keys that need translating)
    ref_country_keys: set[str] = set()
    for raw_key in all_countries:
        ref_country_keys.add(_format_country_key(raw_key))

    # --- Locales (ui + themes + countries) ---
    print("Validating locales...")
    locale_files = sorted(locales_dir.glob("*.lua")) if locales_dir.exists() else []
    all_locales: dict[str, dict] = {}
    all_locale_langs: dict[str, Path] = {}
    for f in locale_files:
        text = f.read_text(encoding="utf-8")
        try:
            data = parse_locale_file(text)
        except Exception as e:
            print(f"  ERROR: {f.name}: parse failed: {e}", file=sys.stderr)
            errors += 1
            continue
        for lang, ld in data.items():
            if lang in all_locale_langs:
                print(
                    f"  ERROR: duplicate locale '{lang}' in {f.name} "
                    f"(also in {all_locale_langs[lang].name})",
                    file=sys.stderr,
                )
                errors += 1
            all_locale_langs[lang] = f
            all_locales[lang] = ld

    # Reference UI and theme keys from English
    en_data = all_locales.get("en", {})
    en_ui_keys = set(en_data.get("ui", {}).keys())
    en_theme_keys = set(en_data.get("themes", {}).keys())

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

    print(f"  {len(locale_files)} files, {len(all_locale_langs)} languages, {langs_with_countries} with country translations")

    # --- Summary ---
    print()
    if errors:
        print(f"FAILED: {errors} error(s), {warnings} warning(s)")
        return 1
    status = "OK" if warnings == 0 else f"OK with {warnings} warning(s)"
    print(f"PASSED: {status}")
    return 0


def main() -> int:
    return validate()


if __name__ == "__main__":
    sys.exit(main())
