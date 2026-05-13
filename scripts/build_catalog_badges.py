#!/usr/bin/env python3
"""Generate README badge JSON from canonical catalog data."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
from pathlib import Path
import sys


REPO_ROOT = Path(__file__).resolve().parent.parent
STATIONS_PATH = REPO_ROOT / "data" / "stations.json"
LOCALES_DIR = REPO_ROOT / "data" / "locales"
BADGES_DIR = REPO_ROOT / "docs" / "badges"
EXCLUDED_COUNTRY_KEYS = frozenset({"unknown"})


@dataclass(frozen=True)
class Badge:
    name: str
    label: str
    message: str
    color: str
    label_color: str = "555555"


@dataclass(frozen=True)
class CatalogStats:
    station_count: int
    country_count: int
    language_count: int


def load_stats() -> CatalogStats:
    stations = json.loads(STATIONS_PATH.read_text(encoding="utf-8"))
    if not isinstance(stations, list):
        raise ValueError(f"{STATIONS_PATH.relative_to(REPO_ROOT)} must contain a JSON array")

    country_keys: set[str] = set()
    for index, station in enumerate(stations):
        if not isinstance(station, dict):
            raise ValueError(f"station[{index}] must be an object")
        country_key = station.get("countryKey")
        if not isinstance(country_key, str) or not country_key:
            raise ValueError(f"station[{index}] missing non-empty countryKey")
        if country_key not in EXCLUDED_COUNTRY_KEYS:
            country_keys.add(country_key)

    locale_paths = sorted(LOCALES_DIR.glob("*.json"))
    if not locale_paths:
        raise ValueError(f"no locale JSON files found in {LOCALES_DIR.relative_to(REPO_ROOT)}")

    return CatalogStats(
        station_count=len(stations),
        country_count=len(country_keys),
        language_count=len(locale_paths),
    )


def format_count(value: int) -> str:
    return f"{value:,}"


def badges_for(stats: CatalogStats) -> tuple[Badge, ...]:
    return (
        Badge("stations", "stations", format_count(stats.station_count), "f97316"),
        Badge("countries", "countries", format_count(stats.country_count), "0969da"),
        Badge("languages", "languages", format_count(stats.language_count), "d29922"),
    )


def shields_json(badge: Badge) -> str:
    payload = {
        "schemaVersion": 1,
        "label": badge.label,
        "message": badge.message,
        "color": badge.color,
        "labelColor": badge.label_color,
        "style": "for-the-badge",
    }
    return json.dumps(payload, indent=2) + "\n"


def stats_json(stats: CatalogStats) -> str:
    payload = {
        "stationCount": stats.station_count,
        "countryCount": stats.country_count,
        "languageCount": stats.language_count,
        "excludedCountryKeys": sorted(EXCLUDED_COUNTRY_KEYS),
    }
    return json.dumps(payload, indent=2) + "\n"


def expected_files(stats: CatalogStats) -> dict[Path, str]:
    files = {BADGES_DIR / "catalog-stats.json": stats_json(stats)}
    for badge in badges_for(stats):
        files[BADGES_DIR / f"{badge.name}.json"] = shields_json(badge)
    return files


def write_files(files: dict[Path, str]) -> None:
    BADGES_DIR.mkdir(parents=True, exist_ok=True)
    for path, content in sorted(files.items()):
        path.write_text(content, encoding="utf-8")


def check_files(files: dict[Path, str]) -> int:
    stale: list[Path] = []
    for path, expected in sorted(files.items()):
        if not path.exists() or path.read_text(encoding="utf-8") != expected:
            stale.append(path)

    if not stale:
        return 0

    print("Catalog badge files are stale. Run:", file=sys.stderr)
    print("  python3 scripts/build_catalog_badges.py", file=sys.stderr)
    print("", file=sys.stderr)
    for path in stale:
        print(f"- {path.relative_to(REPO_ROOT)}", file=sys.stderr)
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify generated badge files without writing them",
    )
    args = parser.parse_args()

    stats = load_stats()
    files = expected_files(stats)

    if args.check:
        return check_files(files)

    write_files(files)
    print(
        "Generated catalog badge JSON: "
        f"{format_count(stats.station_count)} stations, "
        f"{format_count(stats.country_count)} countries, "
        f"{format_count(stats.language_count)} languages."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
