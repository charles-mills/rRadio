#!/usr/bin/env python3
"""Check rRadio station URLs against Google Safe Browsing.

Usage:
    GOOGLE_SAFE_BROWSING_API_KEY=... python3 scripts/check_safe_browsing.py
    python3 scripts/check_safe_browsing.py --country australia --limit 500
    python3 scripts/check_safe_browsing.py --force
    python3 scripts/check_safe_browsing.py --prune-only
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SOURCE = REPO_ROOT / "data" / "stations.json"
DEFAULT_OUTPUT = Path(__file__).resolve().parent / "safe_browsing_results.json"
API_ENDPOINT = "https://safebrowsing.googleapis.com/v4/threatMatches:find"
DEFAULT_BATCH_SIZE = 500
MAX_BATCH_SIZE = 500
DEFAULT_THREAT_TYPES = [
    "MALWARE",
    "SOCIAL_ENGINEERING",
    "UNWANTED_SOFTWARE",
    "POTENTIALLY_HARMFUL_APPLICATION",
]


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_stations(path: Path, country_filter: set[str] | None) -> tuple[dict[str, list[dict[str, str]]], int]:
    rows = json.loads(path.read_text(encoding="utf-8"))
    urls: dict[str, list[dict[str, str]]] = {}
    skipped = 0

    for station in rows:
        country = station.get("countryKey", "")
        if country_filter and country not in country_filter:
            continue

        url = station.get("url", "")
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme.lower() not in {"http", "https"}:
            skipped += 1
            continue

        urls.setdefault(url, []).append({
            "id": station.get("id", ""),
            "name": station.get("name", ""),
            "countryKey": country,
        })

    return urls, skipped


def load_results(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {
            "version": 1,
            "generatedAt": utc_now(),
            "source": str(DEFAULT_SOURCE.relative_to(REPO_ROOT)),
            "checks": {},
        }

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise ValueError(f"failed to parse existing results file {path}: {e}") from e

    if not isinstance(data, dict):
        raise ValueError(f"existing results file {path} must contain a JSON object")
    if "checks" not in data or not isinstance(data["checks"], dict):
        data["checks"] = {}

    return data


def save_results(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False, sort_keys=True), encoding="utf-8")
    tmp.replace(path)


def chunked(items: list[str], size: int) -> list[list[str]]:
    return [items[index:index + size] for index in range(0, len(items), size)]


def request_matches(
    api_key: str,
    urls: list[str],
    threat_types: list[str],
    timeout: float,
    retries: int,
) -> list[dict[str, Any]]:
    body = {
        "client": {
            "clientId": "rradio",
            "clientVersion": "2",
        },
        "threatInfo": {
            "threatTypes": threat_types,
            "platformTypes": ["ANY_PLATFORM"],
            "threatEntryTypes": ["URL"],
            "threatEntries": [{"url": url} for url in urls],
        },
    }

    request_url = f"{API_ENDPOINT}?key={urllib.parse.quote(api_key)}"
    payload = json.dumps(body).encode("utf-8")

    for attempt in range(retries + 1):
        request = urllib.request.Request(
            request_url,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                data = json.loads(response.read().decode("utf-8"))
                return data.get("matches", [])
        except urllib.error.HTTPError as e:
            if e.code in {429, 500, 502, 503, 504} and attempt < retries:
                retry_after = e.headers.get("Retry-After")
                if retry_after and retry_after.isdigit():
                    sleep_for = float(retry_after)
                else:
                    sleep_for = min(60.0, 2.0 ** attempt)
                print(f"  WARNING: Safe Browsing HTTP {e.code}; retrying in {sleep_for:g}s", file=sys.stderr)
                time.sleep(sleep_for)
                continue

            detail = e.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"Safe Browsing HTTP {e.code}: {detail}") from e
        except urllib.error.URLError as e:
            if attempt < retries:
                sleep_for = min(30.0, 2.0 ** attempt)
                print(f"  WARNING: Safe Browsing request failed; retrying in {sleep_for:g}s: {e}", file=sys.stderr)
                time.sleep(sleep_for)
                continue
            raise RuntimeError(f"Safe Browsing request failed: {e}") from e

    return []


def match_key(match: dict[str, Any]) -> str:
    threat = match.get("threat", {})
    if isinstance(threat, dict):
        url = threat.get("url", "")
        if isinstance(url, str):
            return url

    return ""


def cmd_run(args: argparse.Namespace) -> int:
    source = args.source
    output = args.output
    batch_size = min(args.batch_size, MAX_BATCH_SIZE)
    country_filter = set(args.country) if args.country else None

    if batch_size < 1:
        print("ERROR: --batch-size must be at least 1", file=sys.stderr)
        return 1
    if args.limit is not None and args.limit < 1:
        print("ERROR: --limit must be at least 1", file=sys.stderr)
        return 1
    if args.timeout <= 0:
        print("ERROR: --timeout must be positive", file=sys.stderr)
        return 1
    if args.retries < 0:
        print("ERROR: --retries cannot be negative", file=sys.stderr)
        return 1
    if args.requests_per_minute < 0:
        print("ERROR: --requests-per-minute cannot be negative", file=sys.stderr)
        return 1
    if args.save_every < 1:
        print("ERROR: --save-every must be at least 1", file=sys.stderr)
        return 1
    if args.prune_only and args.dry_run:
        print("ERROR: --prune-only cannot be combined with --dry-run", file=sys.stderr)
        return 1

    if args.prune_only:
        return prune_matched_stations(source, output)

    url_stations, skipped_non_http = load_stations(source, country_filter)
    results = load_results(output)
    results["source"] = str(source.relative_to(REPO_ROOT)) if source.is_relative_to(REPO_ROOT) else str(source)
    results["updatedAt"] = utc_now()
    results["threatTypes"] = args.threat_type

    checked = results["checks"]
    pending_urls = sorted(url_stations)
    if not args.force:
        pending_urls = [url for url in pending_urls if url not in checked]
    if args.limit:
        pending_urls = pending_urls[:args.limit]

    total_unique_urls = len(url_stations)
    total_batches = (len(pending_urls) + batch_size - 1) // batch_size
    print(f"Loaded {total_unique_urls} unique HTTP(S) URLs")
    if skipped_non_http:
        print(f"Skipped {skipped_non_http} non-HTTP(S) station URLs")
    if not args.force:
        print(f"Skipping {total_unique_urls - len(pending_urls)} URLs already present in {output}")
    print(f"Checking {len(pending_urls)} URLs in {total_batches} batch(es)")

    if args.dry_run:
        return 0

    api_key = args.api_key or os.environ.get("GOOGLE_SAFE_BROWSING_API_KEY") or os.environ.get("SAFE_BROWSING_API_KEY")
    if not api_key:
        print(
            "ERROR: set GOOGLE_SAFE_BROWSING_API_KEY or pass --api-key. "
            "Create the key in Google Cloud with the Safe Browsing API enabled.",
            file=sys.stderr,
        )
        return 1

    if not pending_urls:
        write_summary(results, url_stations)
        save_results(output, results)
        print_summary(results)
        if args.prune_matches:
            return prune_matched_stations(source, output)
        return 0

    delay = 60.0 / args.requests_per_minute if args.requests_per_minute else 0.0
    checked_count = 0
    matched_count = 0

    for batch_number, batch_urls in enumerate(chunked(pending_urls, batch_size), 1):
        if batch_number > 1 and delay:
            time.sleep(delay)

        matches = request_matches(
            api_key=api_key,
            urls=batch_urls,
            threat_types=args.threat_type,
            timeout=args.timeout,
            retries=args.retries,
        )
        matches_by_url: dict[str, list[dict[str, Any]]] = {}
        for match in matches:
            url = match_key(match)
            if url:
                matches_by_url.setdefault(url, []).append(match)

        checked_at = utc_now()
        for url in batch_urls:
            url_matches = matches_by_url.get(url, [])
            checked[url] = {
                "status": "match" if url_matches else "safe",
                "checkedAt": checked_at,
                "stations": url_stations[url],
            }
            if url_matches:
                checked[url]["matches"] = url_matches

        checked_count += len(batch_urls)
        matched_count += sum(1 for url in batch_urls if matches_by_url.get(url))

        if batch_number % args.save_every == 0 or batch_number == total_batches:
            write_summary(results, url_stations)
            save_results(output, results)

        print(
            f"  Batch {batch_number}/{total_batches}: "
            f"{checked_count}/{len(pending_urls)} checked, {matched_count} matched"
        )

    print_summary(results)
    print(f"Results saved to {output}")
    if args.prune_matches:
        return prune_matched_stations(source, output)

    return 0


def prune_matched_stations(source: Path, output: Path) -> int:
    """Remove matched Safe Browsing URLs from canonical stations and regenerate artifacts."""
    if source.resolve() != DEFAULT_SOURCE.resolve():
        print("ERROR: pruning only supports the default canonical station source", file=sys.stderr)
        return 1

    results = load_results(output)
    checks = results.get("checks", {})
    matched_urls = {url for url, data in checks.items() if data.get("status") == "match"}
    if not matched_urls:
        print("No Safe Browsing matches to prune.")
        return 0

    stations = json.loads(source.read_text(encoding="utf-8"))
    kept = [station for station in stations if station.get("url") not in matched_urls]
    removed = len(stations) - len(kept)
    if removed == 0:
        print("Safe Browsing matches were present, but none matched current station rows.")
        return 0

    kept.sort(key=lambda station: (station["countryKey"], station["name"], station["id"]))

    import build_station_artifacts

    build_station_artifacts.validate(kept)
    source.write_text(json.dumps(kept, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    build_station_artifacts.main()

    print(f"Pruned {removed} station row(s) across {len(matched_urls)} matched URL(s).")
    return 0


def write_summary(results: dict[str, Any], url_stations: dict[str, list[dict[str, str]]]) -> None:
    checks = results.get("checks", {})
    matched_urls = [url for url, data in checks.items() if data.get("status") == "match"]
    results["summary"] = {
        "totalUniqueUrls": len(url_stations),
        "checkedUrls": len(checks),
        "safeUrls": sum(1 for data in checks.values() if data.get("status") == "safe"),
        "matchedUrls": len(matched_urls),
        "matchedStations": sum(len(checks[url].get("stations", [])) for url in matched_urls),
    }


def print_summary(results: dict[str, Any]) -> None:
    summary = results.get("summary", {})
    print(
        "Summary: "
        f"{summary.get('checkedUrls', 0)} checked, "
        f"{summary.get('safeUrls', 0)} safe, "
        f"{summary.get('matchedUrls', 0)} matched URLs "
        f"({summary.get('matchedStations', 0)} station rows)"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Check station URLs against Google Safe Browsing")
    parser.add_argument("--api-key", default=None, help="Google Safe Browsing API key")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE, help="Station JSON source path")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="JSON results path")
    parser.add_argument("--country", action="append", default=None, help="Country key to check, repeatable")
    parser.add_argument("--limit", type=int, default=None, help="Only check the first N pending URLs")
    parser.add_argument("--force", action="store_true", help="Recheck URLs already present in the output file")
    parser.add_argument("--dry-run", action="store_true", help="Count pending URLs and batches without calling Google")
    parser.add_argument(
        "--prune-matches",
        action="store_true",
        help="After checking, remove matched URLs from stations.json and regenerate station artifacts",
    )
    parser.add_argument(
        "--prune-only",
        action="store_true",
        help="Do not call Google; prune using the existing Safe Browsing results file",
    )
    parser.add_argument("--batch-size", type=int, default=DEFAULT_BATCH_SIZE, help="URLs per request, max 500")
    parser.add_argument("--timeout", type=float, default=30.0, help="HTTP request timeout in seconds")
    parser.add_argument("--retries", type=int, default=3, help="Retries for 429 and transient server/network errors")
    parser.add_argument(
        "--requests-per-minute",
        type=float,
        default=0.0,
        help="Optional client-side rate limit. Default 0 sends batches without extra delay.",
    )
    parser.add_argument(
        "--save-every",
        type=int,
        default=10,
        help="Save progress every N batches",
    )
    parser.add_argument(
        "--threat-type",
        action="append",
        default=None,
        choices=DEFAULT_THREAT_TYPES,
        help="Threat type to check, repeatable. Defaults to all common URL threat types.",
    )
    args = parser.parse_args()
    args.threat_type = args.threat_type or DEFAULT_THREAT_TYPES

    return cmd_run(args)


if __name__ == "__main__":
    raise SystemExit(main())
