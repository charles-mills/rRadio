#!/usr/bin/env python3
"""Validate rRadio station stream URLs using ffprobe, optionally via Mullvad VPN.

Probes every station URL to check if it's a live audio stream. Persists results
across runs so repeat failures can identify genuinely dead stations.

Usage:
    python scripts/validate_streams.py run                     # Fast validation pass from current IP
    python scripts/validate_streams.py run --country france     # Single country (repeatable)
    python scripts/validate_streams.py run --vpn                # Route batches through Mullvad VPN
    python scripts/validate_streams.py run --force              # Recheck URLs even if recently checked
    python scripts/validate_streams.py run --workers 96         # Higher parallelism
    python scripts/validate_streams.py report                   # Show all results
    python scripts/validate_streams.py report --failures-only   # Failed stations only
    python scripts/validate_streams.py report --min-fails 2     # Stations that failed 2+ times
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from collections import defaultdict
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, as_completed, wait
from datetime import datetime, timezone
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths & constants
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parent.parent
STATION_SOURCE = REPO_ROOT / "data" / "stations.json"
RESULTS_FILE = Path(__file__).resolve().parent / "stream_results.json"

FFPROBE_TIMEOUT = 5.0  # seconds for subprocess
FFPROBE_NETWORK_TIMEOUT = 3_000_000  # microseconds for ffprobe network IO flags
FFPROBE_ANALYZE_DURATION = 1_000_000  # microseconds of media data to inspect
FFPROBE_PROBE_SIZE = 32 * 1024
VPN_CONNECT_TIMEOUT = 30  # seconds to wait for VPN connection
DEFAULT_WORKERS = 64
DEFAULT_SKIP_RECENT_HOURS = 24.0
MULLVAD_RELAY_NAME_RE = re.compile(r"\b([a-z]{2})-[a-z0-9]+-(?:wg|ovpn)-\d+\b", re.IGNORECASE)
CONNECTIVITY_CHECK_URLS = (
    "https://am.i.mullvad.net/connected",
    "https://www.google.com/generate_204",
    "https://one.one.one.one/cdn-cgi/trace",
)

# ---------------------------------------------------------------------------
# Country key -> ISO 3166-1 alpha-2 mapping
# ---------------------------------------------------------------------------

COUNTRY_TO_ISO: dict[str, str] = {
    "afghanistan": "AF",
    "albania": "AL",
    "algeria": "DZ",
    "american_samoa": "AS",
    "andorra": "AD",
    "angola": "AO",
    "anguilla": "AI",
    "antarctica": "AQ",
    "antigua_and_barbuda": "AG",
    "argentina": "AR",
    "armenia": "AM",
    "aruba": "AW",
    "australia": "AU",
    "austria": "AT",
    "azerbaijan": "AZ",
    "bahrain": "BH",
    "bangladesh": "BD",
    "barbados": "BB",
    "belarus": "BY",
    "belgium": "BE",
    "belize": "BZ",
    "benin": "BJ",
    "bermuda": "BM",
    "bolivarian_republic_of_venezuela": "VE",
    "bolivia": "BO",
    "bonaire": "BQ",
    "bosnia_and_herzegovina": "BA",
    "botswana": "BW",
    "brazil": "BR",
    "british_indian_ocean_territory": "IO",
    "bulgaria": "BG",
    "burkina_faso": "BF",
    "burundi": "BI",
    "cabo_verde": "CV",
    "cambodia": "KH",
    "cameroon": "CM",
    "canada": "CA",
    "chile": "CL",
    "china": "CN",
    "colombia": "CO",
    "costa_rica": "CR",
    "coted_ivoire": "CI",
    "croatia": "HR",
    "cuba": "CU",
    "curacao": "CW",
    "cyprus": "CY",
    "czechia": "CZ",
    "denmark": "DK",
    "dominica": "DM",
    "ecuador": "EC",
    "egypt": "EG",
    "el_salvador": "SV",
    "equatorial_guinea": "GQ",
    "eritrea": "ER",
    "estonia": "EE",
    "ethiopia": "ET",
    "fiji": "FJ",
    "finland": "FI",
    "france": "FR",
    "french_guiana": "GF",
    "french_polynesia": "PF",
    "georgia": "GE",
    "germany": "DE",
    "ghana": "GH",
    "gibraltar": "GI",
    "greece": "GR",
    "greenland": "GL",
    "grenada": "GD",
    "guadeloupe": "GP",
    "guam": "GU",
    "guatemala": "GT",
    "guinea": "GN",
    "guyana": "GY",
    "haiti": "HT",
    "honduras": "HN",
    "hong_kong": "HK",
    "hungary": "HU",
    "iceland": "IS",
    "india": "IN",
    "indonesia": "ID",
    "iraq": "IQ",
    "ireland": "IE",
    "islamic_republic_of_iran": "IR",
    "isle_of_man": "IM",
    "israel": "IL",
    "italy": "IT",
    "jamaica": "JM",
    "japan": "JP",
    "jordan": "JO",
    "kazakhstan": "KZ",
    "kenya": "KE",
    "kosovo": "XK",
    "kuwait": "KW",
    "kyrgyzstan": "KG",
    "latvia": "LV",
    "lebanon": "LB",
    "lesotho": "LS",
    "libya": "LY",
    "lithuania": "LT",
    "luxembourg": "LU",
    "macao": "MO",
    "madagascar": "MG",
    "malawi": "MW",
    "malaysia": "MY",
    "mali": "ML",
    "malta": "MT",
    "martinique": "MQ",
    "mauritius": "MU",
    "mayotte": "YT",
    "mexico": "MX",
    "monaco": "MC",
    "mongolia": "MN",
    "montenegro": "ME",
    "morocco": "MA",
    "mozambique": "MZ",
    "myanmar": "MM",
    "namibia": "NA",
    "nepal": "NP",
    "new_caledonia": "NC",
    "new_zealand": "NZ",
    "nicaragua": "NI",
    "nigeria": "NG",
    "norway": "NO",
    "oman": "OM",
    "pakistan": "PK",
    "panama": "PA",
    "paraguay": "PY",
    "peru": "PE",
    "poland": "PL",
    "portugal": "PT",
    "puerto_rico": "PR",
    "qatar": "QA",
    "republic_of_north_macedonia": "MK",
    "reunion": "RE",
    "romania": "RO",
    "rwanda": "RW",
    "saint_kitts_and_nevis": "KN",
    "saint_lucia": "LC",
    "saint_pierre_and_miquelon": "PM",
    "saint_vincent_and_the_grenadines": "VC",
    "san_marino": "SM",
    "saudi_arabia": "SA",
    "senegal": "SN",
    "serbia": "RS",
    "sierra_leone": "SL",
    "singapore": "SG",
    "slovakia": "SK",
    "slovenia": "SI",
    "somalia": "SO",
    "south_africa": "ZA",
    "spain": "ES",
    "sri_lanka": "LK",
    "state_of_palestine": "PS",
    "suriname": "SR",
    "sweden": "SE",
    "switzerland": "CH",
    "syrian_arab_republic": "SY",
    "taiwan_province_of_china": "TW",
    "tajikistan": "TJ",
    "thailand": "TH",
    "the_bahamas": "BS",
    "the_cayman_islands": "KY",
    "the_central_african_republic": "CF",
    "the_congo": "CG",
    "the_democratic_republic_of_the_congo": "CD",
    "the_dominican_republic": "DO",
    "the_falkland_islands": "FK",
    "the_faroe_islands": "FO",
    "the_french_southern_territories": "TF",
    "the_lao_peoples_democratic_republic": "LA",
    "the_netherlands": "NL",
    "the_niger": "NE",
    "the_philippines": "PH",
    "the_republic_of_korea": "KR",
    "the_republic_of_moldova": "MD",
    "the_russian_federation": "RU",
    "the_sudan": "SD",
    "the_united_arab_emirates": "AE",
    "the_united_kingdom": "GB",
    "the_united_states_minor_outlying_islands": "UM",
    "the_united_states_of_america": "US",
    "togo": "TG",
    "trinidad_and_tobago": "TT",
    "tunisia": "TN",
    "turkey": "TR",
    "turkmenistan": "TM",
    "uganda": "UG",
    "ukraine": "UA",
    "united_republic_of_tanzania": "TZ",
    "uruguay": "UY",
    "us_virgin_islands": "VI",
    "uzbekistan": "UZ",
    "vietnam": "VN",
    "yemen": "YE",
    "zambia": "ZM",
    "zimbabwe": "ZW",
}

# ---------------------------------------------------------------------------
# Mullvad VPN relay mapping
# ---------------------------------------------------------------------------

# ISO codes (lowercase) that Mullvad has relays in
MULLVAD_RELAYS: set[str] = {
    "al", "ar", "at", "au", "be", "bg", "br", "ca", "ch", "cl",
    "co", "cy", "de", "dk", "ee", "es", "fi", "fr", "gb", "gr",
    "hr", "hu", "id", "ie", "il", "it", "jp", "mx", "my", "ng",
    "nl", "no", "pe", "ph", "pl", "pt", "ro", "rs", "se", "sg",
    "si", "sk", "th", "tr", "ua", "us",
}

# For countries without a Mullvad relay, map to the geographically nearest one.
# Key: ISO alpha-2 (uppercase), Value: Mullvad relay code (lowercase).
ISO_TO_VPN_FALLBACK: dict[str, str] = {
    # Central/South Asia
    "AF": "tr",   # Afghanistan -> Turkey
    "BD": "sg",   # Bangladesh -> Singapore
    "BT": "sg",   # Bhutan -> Singapore
    "IN": "sg",   # India -> Singapore
    "IR": "tr",   # Iran -> Turkey
    "KG": "tr",   # Kyrgyzstan -> Turkey
    "KZ": "tr",   # Kazakhstan -> Turkey
    "LK": "sg",   # Sri Lanka -> Singapore
    "MN": "jp",   # Mongolia -> Japan
    "MM": "sg",   # Myanmar -> Singapore
    "NP": "sg",   # Nepal -> Singapore
    "PK": "tr",   # Pakistan -> Turkey
    "TJ": "tr",   # Tajikistan -> Turkey
    "TM": "tr",   # Turkmenistan -> Turkey
    "UZ": "tr",   # Uzbekistan -> Turkey

    # East/Southeast Asia
    "CN": "jp",   # China -> Japan
    "HK": "sg",   # Hong Kong -> Singapore
    "KH": "sg",   # Cambodia -> Singapore
    "KR": "jp",   # South Korea -> Japan
    "LA": "sg",   # Laos -> Singapore
    "MO": "sg",   # Macao -> Singapore
    "TW": "jp",   # Taiwan -> Japan
    "VN": "sg",   # Vietnam -> Singapore

    # Middle East
    "AE": "il",   # UAE -> Israel
    "BH": "il",   # Bahrain -> Israel
    "IQ": "tr",   # Iraq -> Turkey
    "JO": "il",   # Jordan -> Israel
    "KW": "il",   # Kuwait -> Israel
    "LB": "tr",   # Lebanon -> Turkey
    "OM": "il",   # Oman -> Israel
    "PS": "il",   # Palestine -> Israel
    "QA": "il",   # Qatar -> Israel
    "SA": "il",   # Saudi Arabia -> Israel
    "SY": "tr",   # Syria -> Turkey
    "YE": "il",   # Yemen -> Israel

    # North Africa
    "DZ": "es",   # Algeria -> Spain
    "EG": "gr",   # Egypt -> Greece
    "LY": "it",   # Libya -> Italy
    "MA": "es",   # Morocco -> Spain
    "SD": "gr",   # Sudan -> Greece
    "TN": "it",   # Tunisia -> Italy

    # West Africa
    "BF": "ng",   # Burkina Faso -> Nigeria
    "BJ": "ng",   # Benin -> Nigeria
    "CI": "ng",   # Cote d'Ivoire -> Nigeria
    "CM": "ng",   # Cameroon -> Nigeria
    "CV": "pt",   # Cabo Verde -> Portugal
    "GH": "ng",   # Ghana -> Nigeria
    "GN": "ng",   # Guinea -> Nigeria
    "GQ": "ng",   # Equatorial Guinea -> Nigeria
    "ML": "ng",   # Mali -> Nigeria
    "NE": "ng",   # Niger -> Nigeria
    "SL": "ng",   # Sierra Leone -> Nigeria
    "SN": "ng",   # Senegal -> Nigeria
    "TG": "ng",   # Togo -> Nigeria

    # East Africa
    "BI": "ng",   # Burundi -> Nigeria
    "CF": "ng",   # Central African Republic -> Nigeria
    "CD": "ng",   # DR Congo -> Nigeria
    "CG": "ng",   # Congo -> Nigeria
    "ER": "il",   # Eritrea -> Israel
    "ET": "il",   # Ethiopia -> Israel
    "KE": "ng",   # Kenya -> Nigeria
    "MG": "ng",   # Madagascar -> Nigeria
    "MW": "ng",   # Malawi -> Nigeria
    "MU": "ng",   # Mauritius -> Nigeria
    "MZ": "ng",   # Mozambique -> Nigeria
    "RW": "ng",   # Rwanda -> Nigeria
    "SO": "il",   # Somalia -> Israel
    "TZ": "ng",   # Tanzania -> Nigeria
    "UG": "ng",   # Uganda -> Nigeria

    # Southern Africa
    "BW": "ng",   # Botswana -> Nigeria (no ZA relay)
    "LS": "ng",   # Lesotho -> Nigeria
    "NA": "ng",   # Namibia -> Nigeria
    "ZA": "ng",   # South Africa -> Nigeria
    "ZM": "ng",   # Zambia -> Nigeria
    "ZW": "ng",   # Zimbabwe -> Nigeria

    # Europe (non-relay countries)
    "AD": "es",   # Andorra -> Spain
    "BA": "hr",   # Bosnia -> Croatia
    "BY": "ua",   # Belarus -> Ukraine
    "CZ": "sk",   # Czechia -> Slovakia
    "FO": "dk",   # Faroe Islands -> Denmark
    "GE": "tr",   # Georgia -> Turkey
    "GI": "es",   # Gibraltar -> Spain
    "GL": "dk",   # Greenland -> Denmark
    "IM": "gb",   # Isle of Man -> UK
    "IS": "no",   # Iceland -> Norway
    "LT": "pl",   # Lithuania -> Poland
    "LU": "be",   # Luxembourg -> Belgium
    "LV": "ee",   # Latvia -> Estonia
    "MC": "fr",   # Monaco -> France
    "MD": "ro",   # Moldova -> Romania
    "ME": "rs",   # Montenegro -> Serbia
    "MK": "gr",   # North Macedonia -> Greece
    "MT": "it",   # Malta -> Italy
    "RU": "fi",   # Russia -> Finland
    "SM": "it",   # San Marino -> Italy
    "XK": "al",   # Kosovo -> Albania

    # Caribbean
    "AG": "us",   # Antigua and Barbuda -> USA
    "AI": "us",   # Anguilla -> USA
    "AW": "co",   # Aruba -> Colombia
    "BB": "us",   # Barbados -> USA
    "BS": "us",   # Bahamas -> USA
    "BQ": "co",   # Bonaire -> Colombia
    "CU": "mx",   # Cuba -> Mexico
    "CW": "co",   # Curacao -> Colombia
    "DM": "us",   # Dominica -> USA
    "DO": "us",   # Dominican Republic -> USA
    "GD": "us",   # Grenada -> USA
    "GP": "us",   # Guadeloupe -> USA
    "HT": "us",   # Haiti -> USA
    "JM": "us",   # Jamaica -> USA
    "KN": "us",   # Saint Kitts and Nevis -> USA
    "KY": "us",   # Cayman Islands -> USA
    "LC": "us",   # Saint Lucia -> USA
    "MQ": "us",   # Martinique -> USA
    "PR": "us",   # Puerto Rico -> USA
    "TT": "us",   # Trinidad and Tobago -> USA
    "VC": "us",   # Saint Vincent -> USA
    "VI": "us",   # US Virgin Islands -> USA

    # Central America
    "BZ": "mx",   # Belize -> Mexico
    "CR": "co",   # Costa Rica -> Colombia
    "GT": "mx",   # Guatemala -> Mexico
    "HN": "mx",   # Honduras -> Mexico
    "NI": "mx",   # Nicaragua -> Mexico
    "PA": "co",   # Panama -> Colombia
    "SV": "mx",   # El Salvador -> Mexico

    # South America
    "BO": "br",   # Bolivia -> Brazil
    "EC": "co",   # Ecuador -> Colombia
    "FK": "ar",   # Falkland Islands -> Argentina
    "GF": "br",   # French Guiana -> Brazil
    "GY": "br",   # Guyana -> Brazil
    "PY": "ar",   # Paraguay -> Argentina
    "SR": "br",   # Suriname -> Brazil
    "UY": "ar",   # Uruguay -> Argentina
    "VE": "co",   # Venezuela -> Colombia

    # Oceania
    "AS": "au",   # American Samoa -> Australia
    "FJ": "au",   # Fiji -> Australia
    "GU": "au",   # Guam -> Australia
    "NC": "au",   # New Caledonia -> Australia
    "NZ": "au",   # New Zealand -> Australia
    "PF": "au",   # French Polynesia -> Australia
    "UM": "us",   # US Minor Outlying Islands -> USA

    # Other
    "AQ": "au",   # Antarctica -> Australia
    "AZ": "tr",   # Azerbaijan -> Turkey
    "IO": "sg",   # British Indian Ocean Territory -> Singapore
    "RE": "ng",   # Reunion -> Nigeria
    "TF": "au",   # French Southern Territories -> Australia
    "YT": "ng",   # Mayotte -> Nigeria
    "AM": "tr",   # Armenia -> Turkey
    "PM": "ca",   # Saint Pierre and Miquelon -> Canada
}

# ---------------------------------------------------------------------------
# ffprobe stream testing
# ---------------------------------------------------------------------------


def find_ffprobe() -> str:
    """Find ffprobe binary, checking PATH and common nix store locations."""
    path = shutil.which("ffprobe")
    if path:
        return path
    # Search nix store for latest ffprobe
    nix_store = Path("/nix/store")
    if nix_store.exists():
        candidates = sorted(nix_store.glob("*-ffmpeg-*-bin/bin/ffprobe"), reverse=True)
        for c in candidates:
            if c.is_file() and os.access(c, os.X_OK):
                return str(c)
    print("ERROR: ffprobe not found. Install ffmpeg.", file=sys.stderr)
    sys.exit(1)


def test_stream(
    url: str,
    ffprobe_bin: str,
    probe_timeout: float,
    network_timeout_us: int,
    analyze_duration_us: int,
) -> dict:
    """Test a single stream URL with ffprobe. Returns result dict."""
    start = time.monotonic()
    try:
        result = subprocess.run(
            [
                ffprobe_bin,
                "-v", "error",
                "-rw_timeout", str(network_timeout_us),
                "-timeout", str(network_timeout_us),
                "-probesize", str(FFPROBE_PROBE_SIZE),
                "-analyzeduration", str(analyze_duration_us),
                "-i", url,
                "-select_streams", "a:0",
                "-show_entries", "stream=codec_type",
                "-of", "csv=p=0",
            ],
            capture_output=True,
            text=True,
            timeout=probe_timeout,
        )
        elapsed_ms = int((time.monotonic() - start) * 1000)

        stream_types = {line.strip().lower() for line in result.stdout.splitlines()}
        if result.returncode == 0 and "audio" in stream_types:
            return {"status": "ok", "latency_ms": elapsed_ms}

        error = result.stderr.strip()
        if not error:
            error = "No audio stream found"
        # Truncate long errors
        if len(error) > 200:
            error = error[:200] + "..."
        return {"status": "fail", "latency_ms": elapsed_ms, "error": error}

    except subprocess.TimeoutExpired:
        elapsed_ms = int((time.monotonic() - start) * 1000)
        return {"status": "fail", "latency_ms": elapsed_ms, "error": "Timeout"}
    except Exception as e:
        elapsed_ms = int((time.monotonic() - start) * 1000)
        return {"status": "fail", "latency_ms": elapsed_ms, "error": str(e)}


# ---------------------------------------------------------------------------
# VPN management
# ---------------------------------------------------------------------------

def find_mullvad() -> str:
    """Find the Mullvad CLI across Linux/Nix and macOS installs."""
    env_path = os.environ.get("RRADIO_MULLVAD_BIN") or os.environ.get("MULLVAD_BIN")
    if env_path:
        return env_path

    path = shutil.which("mullvad")
    if path:
        return path

    candidates = [
        Path("/Applications/Mullvad VPN.app/Contents/Resources/mullvad"),
        Path("/opt/homebrew/bin/mullvad"),
        Path("/usr/local/bin/mullvad"),
        Path("/run/current-system/sw/bin/mullvad"),
    ]
    for candidate in candidates:
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)

    return "mullvad"


MULLVAD_BIN = find_mullvad()


def vpn_available() -> bool:
    """Check if Mullvad CLI is available and the daemon is running."""
    try:
        result = subprocess.run(
            [MULLVAD_BIN, "status"],
            capture_output=True, text=True, timeout=5,
        )
        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def check_internet(max_attempts: int = 3) -> bool:
    """Verify internet connectivity with small HTTPS requests."""
    for i in range(max_attempts):
        for url in CONNECTIVITY_CHECK_URLS:
            try:
                req = urllib.request.Request(
                    url,
                    headers={"User-Agent": "rRadio stream validator"},
                    method="GET",
                )
                with urllib.request.urlopen(req, timeout=5) as resp:
                    if 200 <= resp.status < 500:
                        return True
            except urllib.error.HTTPError as e:
                if 200 <= e.code < 500:
                    return True
            except (TimeoutError, OSError, urllib.error.URLError):
                pass
        if i < max_attempts - 1:
            time.sleep(1)
    return False


def _parse_mullvad_relay_country(status_line: str) -> str:
    """Extract the country code from a Mullvad relay status line."""
    line = status_line.strip()
    if line.startswith("Relay:"):
        line = line.split(":", 1)[1].strip()

    relay_match = MULLVAD_RELAY_NAME_RE.search(line)
    if relay_match:
        return relay_match.group(1).lower()

    prefix = line.split("-", 1)[0].strip().lower()
    if len(prefix) == 2 and prefix.isalpha():
        return prefix

    return ""


def vpn_get_status() -> tuple[bool, str]:
    """Get VPN connection status. Returns (is_connected, relay_country_code)."""
    try:
        result = subprocess.run(
            [MULLVAD_BIN, "status"],
            capture_output=True, text=True, timeout=5,
        )
        output = result.stdout.strip()
        if not any(line.strip().startswith("Connected") for line in output.splitlines()):
            return False, ""
        # Newer Mullvad CLI versions include a human-readable location before
        # the relay name, e.g. "United Kingdom, London, gb-lon-wg-001".
        for line in output.splitlines():
            line = line.strip()
            if line.startswith("Relay:"):
                return True, _parse_mullvad_relay_country(line)
        return True, ""
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False, ""


def vpn_connect(relay_code: str, max_retries: int = 2) -> bool:
    """Connect to a Mullvad relay and verify the correct country. Returns True on success."""
    for attempt in range(1, max_retries + 1):
        try:
            # Set the relay location
            subprocess.run(
                [MULLVAD_BIN, "relay", "set", "location", relay_code],
                capture_output=True, text=True, timeout=10,
            )
            # Connect and wait
            result = subprocess.run(
                [MULLVAD_BIN, "connect", "--wait"],
                capture_output=True, text=True, timeout=VPN_CONNECT_TIMEOUT,
            )
            if result.returncode != 0:
                print(f"  WARNING: VPN connect to {relay_code} failed (attempt {attempt}): {result.stderr.strip()}")
                if attempt < max_retries:
                    vpn_disconnect()
                    time.sleep(2)
                continue

            # Wait for connection to stabilise then verify country
            time.sleep(2)
            connected, actual_country = vpn_get_status()
            if not connected:
                print(f"  WARNING: VPN not connected after connect (attempt {attempt})")
                if attempt < max_retries:
                    vpn_disconnect()
                    time.sleep(2)
                continue

            if actual_country != relay_code:
                print(
                    f"  WARNING: VPN connected to '{actual_country}' but expected '{relay_code}' "
                    f"(attempt {attempt})"
                )
                if attempt < max_retries:
                    vpn_disconnect()
                    time.sleep(2)
                continue

            # Verify internet connectivity through the tunnel
            if not check_internet():
                print(f"  WARNING: No internet through VPN tunnel (attempt {attempt})")
                if attempt < max_retries:
                    vpn_disconnect()
                    time.sleep(2)
                continue

            print(f"  VPN connected to {relay_code}")
            return True

        except (subprocess.TimeoutExpired, FileNotFoundError) as e:
            print(f"  WARNING: VPN connect to {relay_code} failed (attempt {attempt}): {e}")
            if attempt < max_retries:
                vpn_disconnect()
                time.sleep(2)

    return False


def vpn_disconnect() -> None:
    """Disconnect from Mullvad VPN."""
    try:
        subprocess.run(
            [MULLVAD_BIN, "disconnect", "--wait"],
            capture_output=True, text=True, timeout=15,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass


# ---------------------------------------------------------------------------
# Station loading
# ---------------------------------------------------------------------------


def load_all_stations() -> dict[str, list[dict[str, str]]]:
    """Load all stations from the canonical station JSON source.

    Returns {country_key: [{n: name, u: url}, ...], ...}
    """
    stations: dict[str, list[dict[str, str]]] = {}
    if not STATION_SOURCE.exists():
        print(f"ERROR: Station source not found: {STATION_SOURCE}", file=sys.stderr)
        sys.exit(1)

    rows = json.loads(STATION_SOURCE.read_text(encoding="utf-8"))
    for station in rows:
        country = station["countryKey"]
        stations.setdefault(country, []).append({
            "n": station["name"],
            "u": station["url"],
        })

    return stations


# ---------------------------------------------------------------------------
# Results storage
# ---------------------------------------------------------------------------


_results_lock = threading.Lock()


def load_results() -> dict:
    """Load existing results from disk, or return empty structure."""
    if not RESULTS_FILE.exists():
        return {"stations": {}}
    try:
        text = RESULTS_FILE.read_text(encoding="utf-8")
        data = json.loads(text)
        if "stations" not in data:
            data["stations"] = {}
        return data
    except json.JSONDecodeError:
        print(f"WARNING: Corrupt results file {RESULTS_FILE}, starting fresh", file=sys.stderr)
        return {"stations": {}}


def save_results(data: dict) -> None:
    """Atomically save results to disk."""
    tmp = RESULTS_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    tmp.replace(RESULTS_FILE)


def record_check(
    results: dict,
    url: str,
    country: str,
    name: str,
    vpn_location: str | None,
    check_result: dict,
) -> None:
    """Thread-safe: append a check result for a URL."""
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "status": check_result["status"],
        "latency_ms": check_result["latency_ms"],
    }
    if vpn_location:
        entry["vpn_location"] = vpn_location
    if "error" in check_result:
        entry["error"] = check_result["error"]

    with _results_lock:
        if url not in results["stations"]:
            results["stations"][url] = {
                "country": country,
                "name": name,
                "checks": [],
            }
        results["stations"][url]["checks"].append(entry)


# ---------------------------------------------------------------------------
# Run workflow
# ---------------------------------------------------------------------------


def get_vpn_relay_for_country(country_key: str) -> str:
    """Get the Mullvad relay code for a country key."""
    iso = COUNTRY_TO_ISO.get(country_key)
    if not iso:
        return "us"  # fallback
    iso_lower = iso.lower()
    if iso_lower in MULLVAD_RELAYS:
        return iso_lower
    return ISO_TO_VPN_FALLBACK.get(iso, "us").lower()


def group_countries_by_relay(
    country_keys: list[str],
) -> dict[str, list[str]]:
    """Group country keys by their VPN relay code."""
    groups: dict[str, list[str]] = defaultdict(list)
    for key in country_keys:
        relay = get_vpn_relay_for_country(key)
        groups[relay].append(key)
    return dict(groups)


def collect_unique_urls(
    stations: dict[str, list[dict[str, str]]],
    country_keys: list[str],
) -> list[tuple[str, str, str]]:
    """Collect unique (url, country, name) tuples from the given countries.

    If a URL appears in multiple countries, the first country encountered wins.
    """
    seen: set[str] = set()
    result: list[tuple[str, str, str]] = []
    for country in country_keys:
        for s in stations.get(country, []):
            url = s["u"]
            if url not in seen:
                seen.add(url)
                result.append((url, country, s["n"]))
    return result


def _latest_check_timestamp(results: dict, url: str) -> datetime | None:
    """Return the newest stored check timestamp for a URL."""
    checks = results.get("stations", {}).get(url, {}).get("checks", [])
    if not checks:
        return None

    timestamp = checks[-1].get("timestamp", "")
    if not isinstance(timestamp, str) or not timestamp:
        return None

    try:
        parsed = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    except ValueError:
        return None

    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)

    return parsed.astimezone(timezone.utc)


def skip_recent_urls(
    urls: list[tuple[str, str, str]],
    results: dict,
    max_age_hours: float,
) -> tuple[list[tuple[str, str, str]], int]:
    """Remove URLs with a stored check newer than max_age_hours."""
    if max_age_hours <= 0:
        return urls, 0

    cutoff = datetime.now(timezone.utc).timestamp() - (max_age_hours * 60 * 60)
    pending: list[tuple[str, str, str]] = []
    skipped = 0
    for url, country, name in urls:
        latest = _latest_check_timestamp(results, url)
        if latest and latest.timestamp() >= cutoff:
            skipped += 1
        else:
            pending.append((url, country, name))

    return pending, skipped


def cmd_run(args: argparse.Namespace) -> int:
    """Run stream validation."""
    ffprobe_bin = find_ffprobe()
    use_vpn = args.vpn and not args.no_vpn
    workers = args.workers
    probe_timeout = args.timeout
    network_timeout_us = int(args.network_timeout * 1_000_000)
    analyze_duration_us = int(args.analyze_duration * 1_000_000)
    skip_recent_hours = 0.0 if args.force else args.skip_recent_hours
    limit_remaining = args.limit

    if workers < 1:
        print("ERROR: --workers must be at least 1", file=sys.stderr)
        return 1
    if probe_timeout <= 0 or network_timeout_us <= 0 or analyze_duration_us <= 0:
        print("ERROR: probe timeouts must be positive", file=sys.stderr)
        return 1
    if skip_recent_hours < 0:
        print("ERROR: --skip-recent-hours cannot be negative", file=sys.stderr)
        return 1
    if limit_remaining is not None and limit_remaining < 1:
        print("ERROR: --limit must be at least 1", file=sys.stderr)
        return 1

    # Check VPN availability
    if use_vpn and not vpn_available():
        print(
            f"ERROR: Mullvad VPN not available via {MULLVAD_BIN!r} "
            "(daemon not running or CLI not permitted?). Use --no-vpn to skip.",
            file=sys.stderr,
        )
        return 1

    # Load stations
    all_stations = load_all_stations()
    print(f"Loaded {sum(len(v) for v in all_stations.values())} stations across {len(all_stations)} countries")

    # Filter countries if requested
    if args.country:
        missing = [c for c in args.country if c not in all_stations]
        if missing:
            print(f"ERROR: Unknown countries: {', '.join(missing)}", file=sys.stderr)
            print(f"  Available: {', '.join(sorted(all_stations.keys()))}", file=sys.stderr)
            return 1
        country_keys = args.country
    else:
        country_keys = sorted(all_stations.keys())

    # Verify all country keys are in COUNTRY_TO_ISO
    unmapped = [c for c in country_keys if c not in COUNTRY_TO_ISO]
    if unmapped:
        print(f"WARNING: Countries not in ISO mapping (will use 'us' relay): {', '.join(unmapped)}")

    # Load existing results
    results = load_results()

    # Set up graceful shutdown
    shutdown_event = threading.Event()
    original_sigint = signal.getsignal(signal.SIGINT)

    def sigint_handler(_sig, _frame):
        print("\nInterrupted! Saving results and cleaning up...")
        shutdown_event.set()
        signal.signal(signal.SIGINT, original_sigint)  # Allow force-quit on second Ctrl+C

    signal.signal(signal.SIGINT, sigint_handler)

    total_tested = 0
    total_ok = 0
    total_fail = 0

    if use_vpn:
        # Group by VPN relay to minimize reconnections
        relay_groups = group_countries_by_relay(country_keys)
        print(f"Grouped into {len(relay_groups)} VPN relay batches")
        print()

        for relay_code, batch_countries in sorted(relay_groups.items()):
            if shutdown_event.is_set():
                break

            urls = collect_unique_urls(all_stations, batch_countries)
            urls, skipped = skip_recent_urls(urls, results, skip_recent_hours)
            if limit_remaining is not None:
                if limit_remaining <= 0:
                    break
                urls = urls[:limit_remaining]
            if not urls:
                if skipped:
                    print(f"[VPN: {relay_code}] skipped {skipped} recently checked URLs")
                continue

            print(f"[VPN: {relay_code}] {len(batch_countries)} countries, {len(urls)} unique URLs")
            if skipped:
                print(f"  Skipped {skipped} URLs checked in the last {skip_recent_hours:g}h")
            print(f"  Countries: {', '.join(sorted(batch_countries))}")

            # Connect VPN and verify correct country
            if not vpn_connect(relay_code):
                print(f"  SKIPPING batch (VPN connection failed)")
                print()
                continue

            # Test URLs in parallel
            batch_ok, batch_fail = _test_batch(
                urls,
                results,
                ffprobe_bin,
                workers,
                relay_code,
                shutdown_event,
                probe_timeout,
                network_timeout_us,
                analyze_duration_us,
            )
            total_tested += batch_ok + batch_fail
            total_ok += batch_ok
            total_fail += batch_fail
            if limit_remaining is not None:
                limit_remaining -= batch_ok + batch_fail

            # Save after each batch
            save_results(results)
            print(f"  Batch done: {batch_ok} ok, {batch_fail} fail")
            print()

        # Disconnect VPN
        vpn_disconnect()
        print("VPN disconnected")
    else:
        # No VPN - test all at once
        urls = collect_unique_urls(all_stations, country_keys)
        urls, skipped = skip_recent_urls(urls, results, skip_recent_hours)
        if limit_remaining is not None:
            urls = urls[:limit_remaining]

        print(f"Testing {len(urls)} unique URLs (no VPN)")
        if skipped:
            print(f"Skipped {skipped} URLs checked in the last {skip_recent_hours:g}h")
        print()

        if urls:
            batch_ok, batch_fail = _test_batch(
                urls,
                results,
                ffprobe_bin,
                workers,
                None,
                shutdown_event,
                probe_timeout,
                network_timeout_us,
                analyze_duration_us,
            )
            total_tested += batch_ok + batch_fail
            total_ok += batch_ok
            total_fail += batch_fail

        save_results(results)

    # Final summary
    print()
    print(f"Done: {total_tested} tested, {total_ok} ok, {total_fail} fail")
    print(f"Results saved to {RESULTS_FILE}")

    signal.signal(signal.SIGINT, original_sigint)
    return 0


def _test_batch(
    urls: list[tuple[str, str, str]],
    results: dict,
    ffprobe_bin: str,
    workers: int,
    vpn_location: str | None,
    shutdown_event: threading.Event,
    probe_timeout: float,
    network_timeout_us: int,
    analyze_duration_us: int,
) -> tuple[int, int]:
    """Test a batch of URLs in parallel. Returns (ok_count, fail_count)."""
    ok_count = 0
    fail_count = 0
    completed = 0
    total = len(urls)
    max_pending = max(workers * 2, workers)
    url_iter = iter(urls)

    with ThreadPoolExecutor(max_workers=workers) as executor:
        future_to_url: dict = {}

        def submit_more() -> None:
            while len(future_to_url) < max_pending and not shutdown_event.is_set():
                try:
                    url, country, name = next(url_iter)
                except StopIteration:
                    break

                future = executor.submit(
                    test_stream,
                    url,
                    ffprobe_bin,
                    probe_timeout,
                    network_timeout_us,
                    analyze_duration_us,
                )
                future_to_url[future] = (url, country, name)

        submit_more()

        while future_to_url:
            if shutdown_event.is_set():
                for future in future_to_url:
                    future.cancel()
                break

            done, _ = wait(future_to_url, return_when=FIRST_COMPLETED)
            for future in done:
                url, country, name = future_to_url.pop(future)
                try:
                    check_result = future.result()
                except Exception as e:
                    check_result = {"status": "fail", "latency_ms": 0, "error": str(e)}

                record_check(results, url, country, name, vpn_location, check_result)

                completed += 1
                if check_result["status"] == "ok":
                    ok_count += 1
                else:
                    fail_count += 1
                    print(f"  FAIL [{completed}/{total}] {name} ({country}): {check_result.get('error', 'unknown')}")

                # Progress every 50 URLs
                if completed % 50 == 0:
                    print(f"  Progress: {completed}/{total} ({ok_count} ok, {fail_count} fail)")

            submit_more()

    return ok_count, fail_count


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------


def cmd_report(args: argparse.Namespace) -> int:
    """Generate a report from stored results."""
    import csv as csv_mod
    import io

    results = load_results()
    stations = results.get("stations", {})

    if not stations:
        print("No results found. Run a validation pass first.")
        return 0

    # Compute stats for each URL
    rows: list[dict] = []
    for url, data in stations.items():
        checks = data.get("checks", [])
        if not checks:
            continue
        total = len(checks)
        fails = sum(1 for c in checks if c["status"] == "fail")
        last_check = checks[-1]

        rows.append({
            "country": data.get("country", ""),
            "name": data.get("name", ""),
            "url": url,
            "fails": fails,
            "total_checks": total,
            "fail_rate": round(fails / total, 2) if total > 0 else 0,
            "last_status": last_check["status"],
            "last_error": last_check.get("error", ""),
        })

    # Apply filters
    if args.failures_only:
        rows = [r for r in rows if r["fails"] > 0]

    if args.min_fails > 0:
        rows = [r for r in rows if r["fails"] >= args.min_fails]

    if not rows:
        print("No matching stations found.")
        return 0

    # Sort: most fails first, then by country, then by name
    rows.sort(key=lambda r: (-r["fails"], r["country"], r["name"].lower()))

    # Summary to stderr so it doesn't pollute piped output
    total_urls = len(stations)
    all_checks = sum(len(d.get("checks", [])) for d in stations.values())
    print(f"Results: {total_urls} URLs tracked, {all_checks} total checks", file=sys.stderr)
    if args.failures_only or args.min_fails > 0:
        print(f"Showing: {len(rows)} stations matching filters", file=sys.stderr)

    # CSV output
    delimiter = "," if args.csv else "\t"
    fields = ["country", "name", "url", "fails", "total_checks", "fail_rate", "last_status", "last_error"]
    out = io.StringIO()
    writer = csv_mod.writer(out, delimiter=delimiter, lineterminator="\n")
    writer.writerow(fields)
    for r in rows:
        writer.writerow([r[f] for f in fields])

    sys.stdout.write(out.getvalue())
    return 0


# ---------------------------------------------------------------------------
# Pruning from stored stream validation results
# ---------------------------------------------------------------------------


def _count_failures(checks: list[dict]) -> int:
    return sum(1 for check in checks if check.get("status") == "fail")


def _count_failure_streak(checks: list[dict]) -> int:
    streak = 0
    for check in reversed(checks):
        if check.get("status") != "fail":
            break
        streak += 1

    return streak


def cmd_prune(args: argparse.Namespace) -> int:
    """Remove repeatedly failing station URLs from canonical station data."""
    if args.min_fails < 1:
        print("ERROR: --min-fails must be at least 1", file=sys.stderr)
        return 1
    if args.max_preview < 0:
        print("ERROR: --max-preview cannot be negative", file=sys.stderr)
        return 1

    results = load_results()
    result_stations = results.get("stations", {})
    if not result_stations:
        print("No stream validation results found. Run validation first.")
        return 0

    candidate_urls: dict[str, dict] = {}
    for url, data in result_stations.items():
        checks = data.get("checks", [])
        if not checks:
            continue

        last_status = checks[-1].get("status")
        failure_metric = _count_failure_streak(checks) if args.consecutive else _count_failures(checks)
        if failure_metric < args.min_fails:
            continue
        if not args.include_recovered and last_status != "fail":
            continue

        candidate_urls[url] = {
            "country": data.get("country", ""),
            "name": data.get("name", ""),
            "failures": _count_failures(checks),
            "failure_streak": _count_failure_streak(checks),
            "total_checks": len(checks),
            "last_error": checks[-1].get("error", ""),
        }

    if not candidate_urls:
        mode = "consecutive failure streak" if args.consecutive else "historical failures"
        print(f"No URLs matched --min-fails {args.min_fails} using {mode}.")
        return 0

    if not STATION_SOURCE.exists():
        print(f"ERROR: Station source not found: {STATION_SOURCE}", file=sys.stderr)
        return 1

    stations_json = json.loads(STATION_SOURCE.read_text(encoding="utf-8"))
    if not isinstance(stations_json, list):
        print("ERROR: canonical station source must contain a JSON list", file=sys.stderr)
        return 1

    rows_to_remove = [station for station in stations_json if station.get("url") in candidate_urls]
    if not rows_to_remove:
        print(f"{len(candidate_urls)} failing URL(s) found, but none exist in the current station source.")
        return 0

    removed_urls = {station["url"] for station in rows_to_remove}
    print(
        f"Matched {len(removed_urls)} URL(s), removing {len(rows_to_remove)} station row(s) "
        f"from {STATION_SOURCE.relative_to(REPO_ROOT)}"
    )

    preview_rows = rows_to_remove[:args.max_preview]
    for station in preview_rows:
        url = station["url"]
        candidate = candidate_urls[url]
        print(
            f"  {station.get('name', '')} ({station.get('countryKey', '')}): "
            f"{candidate['failures']} fail(s), streak {candidate['failure_streak']}, {url}"
        )
    if len(rows_to_remove) > len(preview_rows):
        print(f"  ... {len(rows_to_remove) - len(preview_rows)} more row(s)")

    if not args.apply:
        print("Dry run only. Re-run with --apply to edit stations.json and regenerate station artifacts.")
        return 0

    kept = [station for station in stations_json if station.get("url") not in candidate_urls]
    kept.sort(key=lambda station: (station["countryKey"], station["name"], station["id"]))

    import build_station_artifacts

    build_station_artifacts.validate(kept)
    STATION_SOURCE.write_text(json.dumps(kept, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    build_station_artifacts.main()

    print(f"Pruned {len(rows_to_remove)} station row(s) and regenerated station artifacts.")
    return 0


# ---------------------------------------------------------------------------
# Misplaced station detection (DNS + IP geolocation)
# ---------------------------------------------------------------------------

# Patterns in ASN org names that indicate CDN/anycast (geolocation unreliable)
_CDN_ORG_PATTERNS = [
    "cloudflare", "cloudfront", "akamai", "fastly", "amazon", "aws",
    "google cloud", "microsoft", "azure", "stackpath", "keycdn",
    "limelight", "edgecast", "incapsula", "sucuri", "cdn77", "bunny",
    "imperva", "verizon digital", "level3", "lumen",
]


def _resolve_hostname(hostname: str) -> str | None:
    """Resolve a hostname to an IPv4 address. Returns None on failure."""
    import socket
    try:
        results = socket.getaddrinfo(hostname, None, socket.AF_INET, socket.SOCK_STREAM)
        if results:
            return results[0][4][0]
    except (socket.gaierror, socket.timeout, OSError):
        pass
    return None


def _geolocate_ips_batch(
    ips: list[str],
    on_progress: callable = None,
) -> dict[str, dict]:
    """Batch geolocate IPs via ip-api.com. Returns {ip: {countryCode, org, as, ...}}."""
    import urllib.request

    results: dict[str, dict] = {}
    batch_size = 100
    total_batches = (len(ips) + batch_size - 1) // batch_size

    for batch_num, i in enumerate(range(0, len(ips), batch_size), 1):
        batch = ips[i:i + batch_size]
        payload = json.dumps([
            {"query": ip, "fields": "query,countryCode,org,as,status"}
            for ip in batch
        ]).encode()
        req = urllib.request.Request(
            "http://ip-api.com/batch",
            data=payload,
            headers={"Content-Type": "application/json"},
        )
        for attempt in range(3):
            try:
                with urllib.request.urlopen(req, timeout=15) as resp:
                    data = json.loads(resp.read())
                    for entry in data:
                        if entry.get("status") == "success":
                            results[entry["query"]] = entry
                break
            except urllib.error.HTTPError as e:
                if e.code == 429 and attempt < 2:
                    # Rate limited — back off and retry
                    wait = 15 * (attempt + 1)
                    print(f"  Rate limited, waiting {wait}s (attempt {attempt + 1}/3)...", file=sys.stderr)
                    time.sleep(wait)
                else:
                    print(f"  WARNING: Geolocation batch {batch_num} failed: {e}", file=sys.stderr)
            except Exception as e:
                print(f"  WARNING: Geolocation batch {batch_num} failed: {e}", file=sys.stderr)
                break

        if on_progress:
            on_progress(batch_num, total_batches)

        # Rate limit: ~20 requests/min, conservative to avoid 429s
        if i + batch_size < len(ips):
            time.sleep(3)

    return results


def _is_cdn(org: str) -> bool:
    """Check if an org/AS name looks like a CDN provider."""
    org_lower = org.lower()
    return any(pattern in org_lower for pattern in _CDN_ORG_PATTERNS)


def cmd_misplaced(args: argparse.Namespace) -> int:
    """Detect stations that may be listed under the wrong country."""
    import csv as csv_mod
    import io
    import urllib.parse

    # Load all stations and build url -> set of (country_key, name) + hostname mapping
    all_stations = load_all_stations()
    print(f"Loaded {sum(len(v) for v in all_stations.values())} entries across {len(all_stations)} countries", file=sys.stderr)

    url_countries: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for country, st_list in all_stations.items():
        for s in st_list:
            url_countries[s["u"]].append((country, s["n"]))

    # Extract unique hostnames
    hostname_to_urls: dict[str, set[str]] = defaultdict(set)
    for url in url_countries:
        try:
            parsed = urllib.parse.urlparse(url)
            hostname = parsed.hostname
            if hostname:
                hostname_to_urls[hostname].add(url)
        except Exception:
            pass

    unique_hostnames = sorted(hostname_to_urls.keys())
    print(f"Resolving {len(unique_hostnames)} unique hostnames...", file=sys.stderr)

    # Resolve hostnames to IPs (parallel)
    hostname_to_ip: dict[str, str] = {}
    with ThreadPoolExecutor(max_workers=30) as executor:
        futures = {executor.submit(_resolve_hostname, h): h for h in unique_hostnames}
        resolved = 0
        for future in as_completed(futures):
            hostname = futures[future]
            ip = future.result()
            if ip:
                hostname_to_ip[hostname] = ip
            resolved += 1
            if resolved % 200 == 0:
                print(f"  DNS: {resolved}/{len(unique_hostnames)}", file=sys.stderr)

    failed_dns = len(unique_hostnames) - len(hostname_to_ip)
    print(f"  Resolved {len(hostname_to_ip)} hostnames ({failed_dns} failed)", file=sys.stderr)

    # Deduplicate IPs for geolocation
    unique_ips = sorted(set(hostname_to_ip.values()))
    print(f"Geolocating {len(unique_ips)} unique IPs...", file=sys.stderr)

    def geo_progress(batch_num, total_batches):
        if batch_num % 5 == 0 or batch_num == total_batches:
            print(f"  Geo: batch {batch_num}/{total_batches}", file=sys.stderr)

    ip_geo = _geolocate_ips_batch(unique_ips, on_progress=geo_progress)
    print(f"  Geolocated {len(ip_geo)} IPs", file=sys.stderr)

    # Build results: for each (url, listed_country), check if server country matches
    rows: list[dict] = []
    for url, entries in url_countries.items():
        try:
            hostname = urllib.parse.urlparse(url).hostname
        except Exception:
            continue
        if not hostname or hostname not in hostname_to_ip:
            continue
        ip = hostname_to_ip[hostname]
        geo = ip_geo.get(ip)
        if not geo:
            continue

        server_country_code = geo.get("countryCode", "").upper()
        org = geo.get("org", "") or geo.get("as", "") or ""
        cdn = _is_cdn(org)

        for country_key, name in entries:
            listed_iso = COUNTRY_TO_ISO.get(country_key, "").upper()
            if not listed_iso:
                continue
            # Skip matches
            if server_country_code == listed_iso:
                continue

            rows.append({
                "listed_country": country_key,
                "listed_iso": listed_iso,
                "name": name,
                "url": url,
                "server_ip": ip,
                "server_country": server_country_code,
                "server_org": org,
                "cdn": "yes" if cdn else "no",
            })

    if not rows:
        print("No misplaced stations found.", file=sys.stderr)
        return 0

    # Sort by listed country, then name
    rows.sort(key=lambda r: (r["cdn"], r["listed_country"], r["name"].lower()))

    cdn_count = sum(1 for r in rows if r["cdn"] == "yes")
    non_cdn = len(rows) - cdn_count
    print(f"Found {len(rows)} mismatches ({non_cdn} non-CDN, {cdn_count} CDN)", file=sys.stderr)

    # Output
    delimiter = "," if args.csv else "\t"
    fields = ["listed_country", "listed_iso", "server_country", "cdn", "name", "server_org", "url"]
    out = io.StringIO()
    writer = csv_mod.writer(out, delimiter=delimiter, lineterminator="\n")
    writer.writerow(fields)
    for r in rows:
        writer.writerow([r[f] for f in fields])

    sys.stdout.write(out.getvalue())
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate rRadio station stream URLs",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # run subcommand
    run_parser = sub.add_parser("run", help="Run stream validation")
    run_parser.add_argument(
        "--country", action="append", default=None,
        help="Country key to test (repeatable). Default: all countries.",
    )
    run_parser.add_argument(
        "--no-vpn", action="store_true",
        help="Use current-IP testing. This is the default and overrides --vpn.",
    )
    run_parser.add_argument(
        "--vpn", action="store_true",
        help="Route country batches through Mullvad VPN. Slower, but closer to regional playback.",
    )
    run_parser.add_argument(
        "--workers", type=int, default=DEFAULT_WORKERS,
        help=f"Number of parallel workers (default: {DEFAULT_WORKERS}).",
    )
    run_parser.add_argument(
        "--skip-recent-hours", type=float, default=DEFAULT_SKIP_RECENT_HOURS,
        help=(
            f"Skip URLs checked within this many hours (default: {DEFAULT_SKIP_RECENT_HOURS:g}; "
            "use 0 to disable)."
        ),
    )
    run_parser.add_argument(
        "--force", action="store_true",
        help="Recheck every URL, ignoring --skip-recent-hours.",
    )
    run_parser.add_argument(
        "--limit", type=int, default=None,
        help="Only test the first N due URLs after filtering.",
    )
    run_parser.add_argument(
        "--timeout", type=float, default=FFPROBE_TIMEOUT,
        help=f"ffprobe subprocess timeout in seconds (default: {FFPROBE_TIMEOUT:g}).",
    )
    run_parser.add_argument(
        "--network-timeout", type=float, default=FFPROBE_NETWORK_TIMEOUT / 1_000_000,
        help="ffprobe network IO timeout in seconds (default: 3).",
    )
    run_parser.add_argument(
        "--analyze-duration", type=float, default=FFPROBE_ANALYZE_DURATION / 1_000_000,
        help="Seconds of media data ffprobe may analyze (default: 1).",
    )

    # report subcommand
    report_parser = sub.add_parser("report", help="Show validation results")
    report_parser.add_argument(
        "--failures-only", action="store_true",
        help="Only show stations with failures.",
    )
    report_parser.add_argument(
        "--min-fails", type=int, default=0,
        help="Only show stations with at least N failures.",
    )
    report_parser.add_argument(
        "--csv", action="store_true",
        help="Output comma-separated CSV (default is tab-separated TSV).",
    )

    # prune subcommand
    prune_parser = sub.add_parser(
        "prune",
        help="Dry-run or apply removal of URLs with repeated stream validation failures",
    )
    prune_parser.add_argument(
        "--min-fails", type=int, default=5,
        help="Minimum failures required before pruning (default: 5).",
    )
    prune_parser.add_argument(
        "--consecutive", action="store_true",
        help="Use latest consecutive failure streak instead of total historical failures.",
    )
    prune_parser.add_argument(
        "--include-recovered", action="store_true",
        help="Also prune URLs whose most recent check is OK.",
    )
    prune_parser.add_argument(
        "--apply", action="store_true",
        help="Actually edit stations.json and regenerate station artifacts. Default is dry-run.",
    )
    prune_parser.add_argument(
        "--max-preview", type=int, default=25,
        help="Maximum rows to print in the preview (default: 25).",
    )

    # misplaced subcommand
    misplaced_parser = sub.add_parser(
        "misplaced",
        help="Detect stations possibly listed under the wrong country (uses DNS + IP geolocation)",
    )
    misplaced_parser.add_argument(
        "--csv", action="store_true",
        help="Output comma-separated CSV (default is tab-separated TSV).",
    )

    args = parser.parse_args()

    commands = {
        "run": cmd_run,
        "report": cmd_report,
        "prune": cmd_prune,
        "misplaced": cmd_misplaced,
    }
    return commands[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
