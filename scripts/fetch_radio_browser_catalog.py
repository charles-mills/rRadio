#!/usr/bin/env python3
"""Fetch Radio Browser stations and merge them into rRadio's canonical catalog.

Usage:
    python3 scripts/fetch_radio_browser_catalog.py
    python3 scripts/fetch_radio_browser_catalog.py --dry-run
    python3 scripts/fetch_radio_browser_catalog.py --hide-broken

The script discovers Radio Browser mirrors, fetches the station list in pages,
backs off automatically on transient API failures, and preserves existing rRadio
station IDs whenever a fetched station can be matched to an existing URL.
"""

from __future__ import annotations

import argparse
import email.utils
import hashlib
import json
import random
import re
import socket
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import build_station_artifacts
from country_codes import COUNTRY_TO_ISO

REPO_ROOT = SCRIPT_DIR.parent
DEFAULT_SOURCE_PATH = REPO_ROOT / "data" / "stations.json"

DISCOVERY_HOST = "all.api.radio-browser.info"
FALLBACK_HOSTS = ("de1.api.radio-browser.info", "nl1.api.radio-browser.info")
USER_AGENT = "rRadio/2 station-catalog-fetcher"

ID_RE = re.compile(r"^[A-Za-z0-9_\-:.]+$")
URL_RE = re.compile(r"^(https?|mms)://", re.IGNORECASE)
UUID_RE = re.compile(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
)

STATION_ID_LIMIT = 128
URL_BYTE_LIMIT = 512
STATION_ID_HASH_LENGTH = 10
COUNTRY_KEY_LIMIT = 80
PAGE_SIZE_DEFAULT = 10_000
REQUEST_PAUSE_DEFAULT = 0.25
MIN_FETCHED_DEFAULT = 1_000

COUNTRY_CODE_TO_KEY = {iso: country_key for country_key, iso in COUNTRY_TO_ISO.items()}


@dataclass(frozen=True)
class FetchConfig:
    timeout: float
    max_attempts: int
    backoff_base: float
    backoff_max: float
    request_pause: float


@dataclass(frozen=True)
class MergeResult:
    stations: list[dict[str, str]]
    fetched: int
    imported: int
    skipped: int
    dropped_existing: int
    matched_existing: int
    duplicate_fetched_urls: int
    added: int


class RadioBrowserClient:
    def __init__(self, hosts: list[str], config: FetchConfig) -> None:
        if not hosts:
            raise ValueError("at least one Radio Browser API host is required")

        self.hosts = hosts
        self.config = config
        self._host_offset = 0

    def get_json(self, path: str, params: dict[str, str | int]) -> Any:
        last_error: Exception | None = None
        host_count = len(self.hosts)

        for attempt in range(self.config.max_attempts):
            host = self.hosts[(self._host_offset + attempt) % host_count]
            url = build_url(host, path, params)

            try:
                request = urllib.request.Request(
                    url,
                    headers={
                        "Accept": "application/json",
                        "Content-Type": "application/json; charset=utf-8",
                        "User-Agent": USER_AGENT,
                    },
                )
                with urllib.request.urlopen(request, timeout=self.config.timeout) as response:
                    self._host_offset = (self.hosts.index(host) + 1) % host_count
                    return json.loads(response.read().decode("utf-8"))
            except urllib.error.HTTPError as error:
                last_error = error
                if error.code not in {408, 425, 429, 500, 502, 503, 504}:
                    raise RuntimeError(f"Radio Browser returned HTTP {error.code} for {url}") from error

                if attempt + 1 >= self.config.max_attempts:
                    break

                retry_after = parse_retry_after(error.headers.get("Retry-After"))
                delay = retry_after if retry_after is not None else calculate_backoff(attempt, self.config)
                print_retry(attempt, self.config.max_attempts, host, f"HTTP {error.code}", delay)
                time.sleep(delay)
            except (TimeoutError, urllib.error.URLError, OSError, json.JSONDecodeError) as error:
                last_error = error
                if attempt + 1 >= self.config.max_attempts:
                    break

                delay = calculate_backoff(attempt, self.config)
                print_retry(attempt, self.config.max_attempts, host, str(error), delay)
                time.sleep(delay)

        raise RuntimeError(f"Radio Browser request failed after {self.config.max_attempts} attempts") from last_error


def build_url(host: str, path: str, params: dict[str, str | int]) -> str:
    query = urllib.parse.urlencode(params)
    return urllib.parse.urlunparse(("https", host, path, "", query, ""))


def parse_retry_after(value: str | None) -> float | None:
    if not value:
        return None

    try:
        delay = float(value)
    except ValueError:
        try:
            retry_time = email.utils.parsedate_to_datetime(value)
        except (TypeError, ValueError):
            return None

        return max(0.0, retry_time.timestamp() - time.time())

    return max(0.0, delay)


def calculate_backoff(attempt: int, config: FetchConfig) -> float:
    base_delay = min(config.backoff_max, config.backoff_base * (2**attempt))
    jitter = random.uniform(0, min(config.backoff_base, base_delay * 0.25))

    return min(config.backoff_max, base_delay + jitter)


def print_retry(attempt: int, max_attempts: int, host: str, reason: str, delay: float) -> None:
    remaining = max_attempts - attempt - 1
    print(
        f"Radio Browser request via {host} failed ({reason}); "
        f"retrying in {delay:.1f}s ({remaining} attempts left)",
        file=sys.stderr,
    )


def discover_hosts(explicit_hosts: list[str], timeout: float) -> list[str]:
    if explicit_hosts:
        return normalize_hosts(explicit_hosts)

    hosts: list[str] = []
    try:
        addresses = socket.getaddrinfo(DISCOVERY_HOST, 443, type=socket.SOCK_STREAM)
    except OSError as error:
        print(f"DNS discovery failed for {DISCOVERY_HOST}: {error}", file=sys.stderr)
        addresses = []

    for address in addresses:
        ip_address = address[4][0]
        try:
            host, _, _ = socket.gethostbyaddr(ip_address)
        except OSError:
            continue

        host = host.rstrip(".").lower()
        if host.endswith(".api.radio-browser.info") and host not in hosts:
            hosts.append(host)

    if hosts:
        random.shuffle(hosts)
        return hosts

    directory_hosts = fetch_directory_hosts(timeout)
    if directory_hosts:
        random.shuffle(directory_hosts)
        return directory_hosts

    print("Using static Radio Browser fallback hosts", file=sys.stderr)
    return list(FALLBACK_HOSTS)


def fetch_directory_hosts(timeout: float) -> list[str]:
    for host in FALLBACK_HOSTS:
        url = build_url(host, "/json/servers", {})
        try:
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
            with urllib.request.urlopen(request, timeout=timeout) as response:
                data = json.loads(response.read().decode("utf-8"))
        except (TimeoutError, urllib.error.URLError, urllib.error.HTTPError, OSError, json.JSONDecodeError):
            continue

        if not isinstance(data, list):
            continue

        hosts = normalize_hosts([str(server.get("name", "")) for server in data if isinstance(server, dict)])
        if hosts:
            return hosts

    return []


def normalize_hosts(hosts: list[str]) -> list[str]:
    normalized_hosts: list[str] = []
    for host in hosts:
        parsed = urllib.parse.urlsplit(host if "://" in host else f"https://{host}")
        normalized = (parsed.hostname or "").rstrip(".").lower()
        if not normalized or normalized in normalized_hosts:
            continue

        normalized_hosts.append(normalized)

    return normalized_hosts


def fetch_catalog(client: RadioBrowserClient, page_size: int, hide_broken: bool) -> list[dict[str, Any]]:
    stations: list[dict[str, Any]] = []
    offset = 0

    while True:
        params: dict[str, str | int] = {
            "limit": page_size,
            "offset": offset,
            "order": "name",
            "reverse": "false",
        }
        if hide_broken:
            params["hidebroken"] = "true"

        page = client.get_json("/json/stations", params)
        if not isinstance(page, list):
            raise RuntimeError(f"Radio Browser returned {type(page).__name__}, expected a list")

        fetched_page = [station for station in page if isinstance(station, dict)]
        stations.extend(fetched_page)
        print(f"Fetched {len(fetched_page)} Radio Browser stations at offset {offset}")

        if len(page) < page_size:
            break

        offset += len(page)
        if client.config.request_pause > 0:
            time.sleep(client.config.request_pause)

    return stations


def load_existing(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []

    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError(f"{path} must contain a JSON list")

    stations: list[dict[str, str]] = []
    for index, station in enumerate(data):
        if not isinstance(station, dict):
            raise ValueError(f"{path} station[{index}] must be an object")

        stations.append(
            {
                "id": str(station.get("id", "")).strip(),
                "name": str(station.get("name", "")).strip(),
                "url": str(station.get("url", "")).strip(),
                "countryKey": str(station.get("countryKey", "")).strip(),
                "source": str(station.get("source", "")).strip(),
            }
        )

    return stations


def normalize_radio_browser_station(raw_station: dict[str, Any]) -> dict[str, str] | None:
    name = clean_text(raw_station.get("name"))
    url = choose_stream_url(raw_station)
    country_key = country_key_for_station(raw_station)

    if not name or not url or not country_key:
        return None
    if not URL_RE.match(url) or len(url.encode("utf-8")) > URL_BYTE_LIMIT:
        return None

    station_uuid = clean_text(raw_station.get("stationuuid")).lower()
    if UUID_RE.match(station_uuid):
        station_id = make_radio_browser_station_id(country_key, station_uuid)
    else:
        station_id = make_station_id(country_key, name, url)

    if not station_id or not ID_RE.match(station_id) or len(station_id.encode("utf-8")) > STATION_ID_LIMIT:
        return None
    if station_id_country_key(station_id) != country_key:
        return None

    return {
        "id": station_id,
        "name": name,
        "url": url,
        "countryKey": country_key,
        "source": "builtin",
    }


def choose_stream_url(raw_station: dict[str, Any]) -> str:
    resolved_url = clean_text(raw_station.get("url_resolved"))
    if resolved_url and URL_RE.match(resolved_url):
        return resolved_url

    return clean_text(raw_station.get("url"))


def country_key_for_station(raw_station: dict[str, Any]) -> str:
    country_code = clean_text(raw_station.get("countrycode")).upper()
    if country_code in COUNTRY_CODE_TO_KEY:
        return COUNTRY_CODE_TO_KEY[country_code]

    country_name = clean_text(raw_station.get("country"))
    if country_name:
        return truncate_slug(slugify(country_name), COUNTRY_KEY_LIMIT)

    return "unknown"


def clean_text(value: Any) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def station_id_country_key(station_id: str) -> str | None:
    parts = station_id.split(":", 2)
    if len(parts) < 3 or parts[0] != "builtin":
        return None

    return parts[1]


def merge_catalog(
    existing_stations: list[dict[str, str]],
    fetched_stations: list[dict[str, Any]],
) -> MergeResult:
    merged = [station for station in existing_stations if is_valid_existing_station(station)]
    dropped_existing = len(existing_stations) - len(merged)
    existing_ids = {station["id"] for station in merged}
    existing_url_keys = {normalize_url_key(station["url"]) for station in merged}
    best_fetched_by_url: dict[str, tuple[dict[str, str], tuple[int, ...], tuple[str, ...]]] = {}
    seen_fetched_ids: set[str] = set()
    skipped = 0
    matched_existing = 0
    duplicate_fetched_urls = 0

    for fetched_station in fetched_stations:
        station = normalize_radio_browser_station(fetched_station)
        if station is None:
            skipped += 1
            continue

        station_id = station["id"]
        if station_id in seen_fetched_ids:
            skipped += 1
            continue

        seen_fetched_ids.add(station_id)

        url_key = normalize_url_key(station["url"])
        if station_id in existing_ids or url_key in existing_url_keys:
            matched_existing += 1
            continue

        candidate_score = fetched_station_score(fetched_station, station)
        candidate_tiebreaker = fetched_station_tiebreaker(station)
        previous = best_fetched_by_url.get(url_key)
        if previous is None:
            best_fetched_by_url[url_key] = (station, candidate_score, candidate_tiebreaker)
            continue

        duplicate_fetched_urls += 1
        _, previous_score, previous_tiebreaker = previous
        if candidate_score > previous_score or (
            candidate_score == previous_score and candidate_tiebreaker < previous_tiebreaker
        ):
            best_fetched_by_url[url_key] = (station, candidate_score, candidate_tiebreaker)

    added_ids: set[str] = set()
    fetched_to_add = sorted(
        (candidate[0] for candidate in best_fetched_by_url.values()),
        key=lambda station: (station["countryKey"], station["name"], station["id"]),
    )

    added = 0
    for station in fetched_to_add:
        if station["id"] in existing_ids or station["id"] in added_ids:
            skipped += 1
            continue

        merged.append(station)
        added_ids.add(station["id"])
        added += 1

    merged.sort(key=lambda station: (station["countryKey"], station["name"], station["id"]))

    return MergeResult(
        stations=merged,
        fetched=len(fetched_stations),
        imported=matched_existing + duplicate_fetched_urls + len(fetched_to_add),
        skipped=skipped,
        dropped_existing=dropped_existing,
        matched_existing=matched_existing,
        duplicate_fetched_urls=duplicate_fetched_urls,
        added=added,
    )


def is_valid_existing_station(station: dict[str, str]) -> bool:
    station_id = station.get("id", "")
    if not ID_RE.match(station_id) or len(station_id.encode("utf-8")) > STATION_ID_LIMIT:
        return False

    for field in ("name", "url", "countryKey", "source"):
        if not station.get(field):
            return False

    if station["source"] != "builtin":
        return False

    return URL_RE.match(station["url"]) is not None


def normalize_url_key(url: str) -> str:
    parsed = urllib.parse.urlsplit(url.strip())
    if not parsed.scheme or not parsed.netloc:
        return url.strip()

    scheme = parsed.scheme.lower()
    host = (parsed.hostname or "").lower()
    try:
        port = parsed.port
    except ValueError:
        return url.strip()

    if port is None or (scheme == "http" and port == 80) or (scheme == "https" and port == 443):
        netloc = host
    else:
        netloc = f"{host}:{port}"

    path = parsed.path
    if path == "/":
        path = ""

    return urllib.parse.urlunsplit((scheme, netloc, path, parsed.query, ""))


def fetched_station_score(raw_station: dict[str, Any], station: dict[str, str]) -> tuple[int, ...]:
    return (
        1 if station["countryKey"] != "unknown" else 0,
        1 if int_value(raw_station.get("lastcheckok")) > 0 else 0,
        int_value(raw_station.get("votes")),
        int_value(raw_station.get("clickcount")),
        int_value(raw_station.get("clicktrend")),
        int_value(raw_station.get("bitrate")),
    )


def fetched_station_tiebreaker(station: dict[str, str]) -> tuple[str, ...]:
    return (
        station["countryKey"],
        station["name"].casefold(),
        station["id"],
        station["url"],
    )


def int_value(value: Any) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def slugify(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value.lower())
    ascii_value = normalized.encode("ascii", "ignore").decode("ascii")
    slug = re.sub(r"[^a-z0-9]+", "_", ascii_value)
    slug = re.sub(r"^_+|_+$", "", slug)

    return slug or "station"


def truncate_slug(value: str, max_length: int) -> str:
    if max_length <= 0:
        return ""
    if len(value) <= max_length:
        return value

    truncated = re.sub(r"_+$", "", value[:max_length])
    return truncated or value[:max_length]


def make_station_id(country_key: str, name: str, url: str) -> str | None:
    fingerprint_source = "\n".join((country_key, name, url))
    fingerprint = hashlib.sha1(fingerprint_source.encode("utf-8")).hexdigest()[:STATION_ID_HASH_LENGTH]
    country_slug = slugify(country_key)
    name_slug = slugify(name)
    max_name_length = STATION_ID_LIMIT - len("builtin:") - len(country_slug) - len(fingerprint) - 2

    if max_name_length < 1:
        return None

    return f"builtin:{country_slug}:{truncate_slug(name_slug, max_name_length)}:{fingerprint}"


def make_radio_browser_station_id(country_key: str, station_uuid: str) -> str | None:
    uuid_part = station_uuid.replace("-", "")
    candidate = f"builtin:{country_key}:rb:{uuid_part}"
    if len(candidate.encode("utf-8")) <= STATION_ID_LIMIT:
        return candidate

    return make_station_id(country_key, "radio_browser", uuid_part)


def write_catalog(path: Path, stations: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(stations, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fetch the latest Radio Browser catalog and merge it into data/stations.json."
    )
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE_PATH, help="canonical station JSON path")
    parser.add_argument("--server", action="append", default=[], help="specific Radio Browser API host to use")
    parser.add_argument("--page-size", type=int, default=PAGE_SIZE_DEFAULT, help="stations to request per API page")
    parser.add_argument("--hide-broken", action="store_true", help="exclude stations marked broken by Radio Browser")
    parser.add_argument("--dry-run", action="store_true", help="fetch and merge without writing files")
    parser.add_argument("--skip-artifacts", action="store_true", help="do not regenerate Lua station artifacts after write")
    parser.add_argument("--timeout", type=float, default=30.0, help="HTTP timeout per request, in seconds")
    parser.add_argument("--max-attempts", type=int, default=8, help="attempts per request before failing")
    parser.add_argument("--backoff-base", type=float, default=1.0, help="initial retry delay, in seconds")
    parser.add_argument("--backoff-max", type=float, default=60.0, help="maximum retry delay, in seconds")
    parser.add_argument("--request-pause", type=float, default=REQUEST_PAUSE_DEFAULT, help="pause between successful pages")
    parser.add_argument("--min-fetched", type=int, default=MIN_FETCHED_DEFAULT, help="abort if fewer API rows are fetched")

    return parser.parse_args()


def validate_args(args: argparse.Namespace) -> None:
    if args.page_size < 1:
        raise ValueError("--page-size must be at least 1")
    if args.timeout <= 0:
        raise ValueError("--timeout must be positive")
    if args.max_attempts < 1:
        raise ValueError("--max-attempts must be at least 1")
    if args.backoff_base <= 0:
        raise ValueError("--backoff-base must be positive")
    if args.backoff_max < args.backoff_base:
        raise ValueError("--backoff-max must be greater than or equal to --backoff-base")
    if args.request_pause < 0:
        raise ValueError("--request-pause cannot be negative")
    if args.min_fetched < 0:
        raise ValueError("--min-fetched cannot be negative")


def main() -> int:
    args = parse_args()
    try:
        validate_args(args)
    except ValueError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2

    source_path = args.source
    if not source_path.is_absolute():
        source_path = REPO_ROOT / source_path

    config = FetchConfig(
        timeout=args.timeout,
        max_attempts=args.max_attempts,
        backoff_base=args.backoff_base,
        backoff_max=args.backoff_max,
        request_pause=args.request_pause,
    )

    hosts = discover_hosts(args.server, args.timeout)
    print(f"Using Radio Browser API hosts: {', '.join(hosts)}")

    client = RadioBrowserClient(hosts, config)
    fetched_stations = fetch_catalog(client, args.page_size, args.hide_broken)
    if len(fetched_stations) < args.min_fetched:
        print(
            f"ERROR: fetched only {len(fetched_stations)} rows, below --min-fetched={args.min_fetched}",
            file=sys.stderr,
        )
        return 1

    existing_stations = load_existing(source_path)
    result = merge_catalog(existing_stations, fetched_stations)

    print(
        "Merge summary: "
        f"{result.imported} imported, {result.added} added, "
        f"{result.matched_existing} already present, {result.duplicate_fetched_urls} duplicate fetched URLs, "
        f"{result.skipped} skipped, "
        f"{result.dropped_existing} dropped existing, {len(result.stations)} total canonical stations"
    )

    if args.dry_run:
        print("Dry run; no files written")
        return 0

    write_catalog(source_path, result.stations)
    print(f"Wrote {source_path.relative_to(REPO_ROOT)}")

    if not args.skip_artifacts:
        build_station_artifacts.main()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
