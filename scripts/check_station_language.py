#!/usr/bin/env python3
"""Check rRadio station names and URLs for offensive terms.

Usage:
    python3 scripts/check_station_language.py
    python3 scripts/check_station_language.py --country united_states
    python3 scripts/check_station_language.py --category slur --remove-matches
    python3 scripts/check_station_language.py --field name --min-severity low
    python3 scripts/check_station_language.py --remove-matches
    python3 scripts/check_station_language.py --word-file extra_terms.csv --json

Custom word files are CSV rows in the form:
    term[,category[,severity]]

Severity must be one of: low, medium, high.
"""

from __future__ import annotations

import argparse
import contextlib
import csv
import html
import io
import json
import re
import sys
import urllib.parse
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SOURCE = REPO_ROOT / "data" / "stations.json"
DEFAULT_FIELDS = ("name", "url")
SEVERITY_RANK = {
    "low": 1,
    "medium": 2,
    "high": 3,
}

# Conservative English-focused defaults. Use --word-file for project-specific
# additions, other languages, or terms that should only be checked locally.
BUILTIN_TERMS: tuple[tuple[str, str, str], ...] = (
    # Slurs and identity-based abuse.
    ("beaner", "slur", "high"),
    ("chink", "slur", "high"),
    ("coon", "slur", "high"),
    ("dyke", "slur", "high"),
    ("fag", "slur", "high"),
    ("faggot", "slur", "high"),
    ("gook", "slur", "high"),
    ("kike", "slur", "high"),
    ("mongoloid", "slur", "high"),
    ("nigga", "slur", "high"),
    ("nigger", "slur", "high"),
    ("paki", "slur", "high"),
    ("raghead", "slur", "high"),
    ("retard", "slur", "high"),
    ("retarded", "slur", "high"),
    ("shemale", "slur", "high"),
    ("spic", "slur", "high"),
    ("towel head", "slur", "high"),
    ("towelhead", "slur", "high"),
    ("tranny", "slur", "high"),
    ("wetback", "slur", "high"),
    ("zipperhead", "slur", "high"),
    # Extremist terms that are generally unsuitable in station listings.
    ("hitler", "extremism", "high"),
    ("kkk", "extremism", "high"),
    ("nazi", "extremism", "high"),
    ("neo nazi", "extremism", "high"),
    ("neo-nazi", "extremism", "high"),
    # Strong profanity and abuse.
    ("arsehole", "profanity", "medium"),
    ("ass hole", "profanity", "medium"),
    ("asshole", "profanity", "medium"),
    ("bastard", "profanity", "medium"),
    ("bitch", "profanity", "medium"),
    ("bitches", "profanity", "medium"),
    ("bull shit", "profanity", "medium"),
    ("bullshit", "profanity", "medium"),
    ("cunt", "profanity", "medium"),
    ("dick head", "profanity", "medium"),
    ("dickhead", "profanity", "medium"),
    ("douche bag", "profanity", "medium"),
    ("douchebag", "profanity", "medium"),
    ("fuck", "profanity", "medium"),
    ("fucked", "profanity", "medium"),
    ("fucker", "profanity", "medium"),
    ("fuckers", "profanity", "medium"),
    ("fucking", "profanity", "medium"),
    ("mother fucker", "profanity", "medium"),
    ("motherfucker", "profanity", "medium"),
    ("piss off", "profanity", "medium"),
    ("prick", "profanity", "medium"),
    ("shit", "profanity", "medium"),
    ("shitty", "profanity", "medium"),
    ("twat", "profanity", "medium"),
    ("wanker", "profanity", "medium"),
    # Explicit sexual terms and adult-site markers.
    ("blow job", "adult", "medium"),
    ("blowjob", "adult", "medium"),
    ("cock", "adult", "medium"),
    ("cum", "adult", "medium"),
    ("cumming", "adult", "medium"),
    ("dick", "adult", "medium"),
    ("hand job", "adult", "medium"),
    ("handjob", "adult", "medium"),
    ("hentai", "adult", "medium"),
    ("incest", "adult", "medium"),
    ("milf", "adult", "medium"),
    ("penis", "adult", "medium"),
    ("porn", "adult", "medium"),
    ("pornhub", "adult", "high"),
    ("porno", "adult", "medium"),
    ("pornography", "adult", "medium"),
    ("pussy", "adult", "medium"),
    ("rape", "adult", "medium"),
    ("rapist", "adult", "medium"),
    ("sexcam", "adult", "medium"),
    ("sex cams", "adult", "medium"),
    ("skank", "adult", "medium"),
    ("slut", "adult", "medium"),
    ("sperm", "adult", "medium"),
    ("tits", "adult", "medium"),
    ("vagina", "adult", "medium"),
    ("whore", "adult", "medium"),
    ("xnxx", "adult", "high"),
    ("xvideos", "adult", "high"),
    ("xxx", "adult", "medium"),
    # Mild profanity. Hidden by the default --min-severity medium threshold.
    ("ass", "profanity", "low"),
    ("crap", "profanity", "low"),
    ("damn", "profanity", "low"),
    ("hell", "profanity", "low"),
    ("sex", "adult", "low"),
    ("suck", "profanity", "low"),
    ("sucks", "profanity", "low"),
)


@dataclass(frozen=True)
class Term:
    phrase: str
    category: str
    severity: str
    normalized: str
    obfuscated_pattern: re.Pattern[str] | None


@dataclass(frozen=True)
class Match:
    field: str
    term: str
    category: str
    severity: str
    match_type: str


@dataclass(frozen=True)
class Finding:
    station_id: str
    country_key: str
    name: str
    url: str
    matches: tuple[Match, ...]


@dataclass(frozen=True)
class RemovalResult:
    removed_count: int
    regenerated_artifacts: bool


def decode_repeatedly(value: str) -> str:
    decoded = value
    for _ in range(3):
        next_value = urllib.parse.unquote(decoded)
        if next_value == decoded:
            break
        decoded = next_value

    return decoded


def fold_text(value: str) -> str:
    value = html.unescape(decode_repeatedly(value)).replace("+", " ")
    value = unicodedata.normalize("NFKC", value).casefold()
    decomposed = unicodedata.normalize("NFKD", value)
    return "".join(char for char in decomposed if unicodedata.category(char) != "Mn")


def normalize_words(value: str) -> str:
    folded = fold_text(value)
    return re.sub(r"[^a-z0-9]+", " ", folded).strip()


def build_obfuscated_pattern(normalized: str) -> re.Pattern[str] | None:
    compact = normalized.replace(" ", "")
    if len(compact) < 4 or not compact.isalnum():
        return None

    letters = [re.escape(char) for char in compact]
    return re.compile(r"(?<![a-z0-9])" + r"[\W_]+".join(letters) + r"(?![a-z0-9])")


def make_term(phrase: str, category: str, severity: str) -> Term:
    phrase = phrase.strip()
    category = category.strip() or "custom"
    severity = severity.strip().lower() or "medium"
    if not phrase:
        raise ValueError("empty term")
    if severity not in SEVERITY_RANK:
        raise ValueError(f"invalid severity {severity!r} for term {phrase!r}")

    normalized = normalize_words(phrase)
    if not normalized:
        raise ValueError(f"term {phrase!r} has no searchable characters")

    return Term(
        phrase=phrase,
        category=category,
        severity=severity,
        normalized=normalized,
        obfuscated_pattern=build_obfuscated_pattern(normalized),
    )


def read_word_file(path: Path) -> list[tuple[str, str, str]]:
    rows: list[tuple[str, str, str]] = []
    with path.open(newline="", encoding="utf-8") as handle:
        for line_number, row in enumerate(csv.reader(handle), 1):
            if not row or not row[0].strip() or row[0].lstrip().startswith("#"):
                continue
            if len(row) > 3:
                raise ValueError(f"{path}:{line_number}: expected at most 3 CSV columns")

            phrase = row[0].strip()
            category = row[1].strip() if len(row) > 1 and row[1].strip() else "custom"
            severity = row[2].strip() if len(row) > 2 and row[2].strip() else "medium"
            rows.append((phrase, category, severity))

    return rows


def compile_terms(word_files: Iterable[Path]) -> list[Term]:
    raw_terms = list(BUILTIN_TERMS)
    for path in word_files:
        raw_terms.extend(read_word_file(path))

    terms_by_phrase: dict[str, Term] = {}
    for phrase, category, severity in raw_terms:
        term = make_term(phrase, category, severity)
        existing = terms_by_phrase.get(term.normalized)
        if existing is None or SEVERITY_RANK[term.severity] > SEVERITY_RANK[existing.severity]:
            terms_by_phrase[term.normalized] = term

    return sorted(
        terms_by_phrase.values(),
        key=lambda term: (
            -SEVERITY_RANK[term.severity],
            -len(term.normalized),
            term.normalized,
        ),
    )


def filter_terms_by_category(terms: list[Term], category_filter: set[str] | None) -> list[Term]:
    if not category_filter:
        return terms

    return [term for term in terms if term.category.casefold() in category_filter]


def load_stations(path: Path) -> list[dict[str, Any]]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise ValueError(f"failed to parse {path}: {e}") from e

    if not isinstance(data, list):
        raise ValueError(f"{path} must contain a JSON array")

    return data


def station_field_text(station: dict[str, Any], field: str) -> str:
    value = station.get(field, "")
    if value is None:
        return ""
    if not isinstance(value, str):
        return str(value)
    return value


def find_term_matches(value: str, field: str, terms: list[Term], min_severity: str) -> list[Match]:
    minimum_rank = SEVERITY_RANK[min_severity]
    normalized_haystack = f" {normalize_words(value)} "
    folded_value = fold_text(value)
    matches: list[Match] = []
    seen: set[tuple[str, str]] = set()

    for term in terms:
        if SEVERITY_RANK[term.severity] < minimum_rank:
            continue

        match_type: str | None = None
        if f" {term.normalized} " in normalized_haystack:
            match_type = "exact"
        elif term.obfuscated_pattern and term.obfuscated_pattern.search(folded_value):
            match_type = "obfuscated"

        if match_type is None:
            continue

        key = (field, term.normalized)
        if key in seen:
            continue
        seen.add(key)
        matches.append(
            Match(
                field=field,
                term=term.phrase,
                category=term.category,
                severity=term.severity,
                match_type=match_type,
            )
        )

    return matches


def check_stations(
    stations: list[dict[str, Any]],
    terms: list[Term],
    fields: tuple[str, ...],
    min_severity: str,
    country_filter: set[str] | None,
) -> list[Finding]:
    findings: list[Finding] = []

    for station in stations:
        country_key = station_field_text(station, "countryKey")
        if country_filter and country_key not in country_filter:
            continue

        station_matches: list[Match] = []
        for field in fields:
            value = station_field_text(station, field)
            if value:
                station_matches.extend(find_term_matches(value, field, terms, min_severity))

        if station_matches:
            station_matches.sort(
                key=lambda match: (
                    -SEVERITY_RANK[match.severity],
                    match.field,
                    match.category,
                    match.term,
                )
            )
            findings.append(
                Finding(
                    station_id=station_field_text(station, "id"),
                    country_key=country_key,
                    name=station_field_text(station, "name"),
                    url=station_field_text(station, "url"),
                    matches=tuple(station_matches),
                )
            )

    findings.sort(key=finding_sort_key)
    return findings


def finding_sort_key(finding: Finding) -> tuple[int, str, str, str]:
    highest_rank = max(SEVERITY_RANK[match.severity] for match in finding.matches)
    return (-highest_rank, finding.country_key, finding.name.casefold(), finding.station_id)


def short(value: str, limit: int = 180) -> str:
    cleaned = " ".join(value.split())
    if len(cleaned) <= limit:
        return cleaned
    return cleaned[: limit - 1] + "..."


def finding_to_json(finding: Finding) -> dict[str, Any]:
    return {
        "id": finding.station_id,
        "countryKey": finding.country_key,
        "name": finding.name,
        "url": finding.url,
        "matches": [
            {
                "field": match.field,
                "term": match.term,
                "category": match.category,
                "severity": match.severity,
                "matchType": match.match_type,
            }
            for match in finding.matches
        ],
    }


def removal_to_json(removal: RemovalResult | None) -> dict[str, Any] | None:
    if removal is None:
        return None

    return {
        "removedStations": removal.removed_count,
        "regeneratedArtifacts": removal.regenerated_artifacts,
    }


def source_label(source: Path) -> str:
    try:
        return str(source.resolve().relative_to(REPO_ROOT))
    except ValueError:
        return str(source)


def print_json_report(
    source: Path,
    checked_count: int,
    findings: list[Finding],
    removal: RemovalResult | None,
) -> None:
    payload = {
        "source": source_label(source),
        "checkedStations": checked_count,
        "matchedStations": len(findings),
        "matchCount": sum(len(finding.matches) for finding in findings),
        "findings": [finding_to_json(finding) for finding in findings],
    }
    if removal is not None:
        payload["removal"] = removal_to_json(removal)

    print(json.dumps(payload, indent=2, ensure_ascii=False))


def print_text_report(
    source: Path,
    checked_count: int,
    findings: list[Finding],
    max_results: int,
    removal: RemovalResult | None,
) -> None:
    match_count = sum(len(finding.matches) for finding in findings)
    if not findings:
        print(f"No matching station names or URLs found in {source_label(source)} ({checked_count} station rows checked).")
        return

    print(
        f"Found {len(findings)} station row(s) with {match_count} match(es) "
        f"in {source_label(source)} ({checked_count} station rows checked)."
    )

    visible_findings = findings if max_results == 0 else findings[:max_results]
    for finding in visible_findings:
        for match in finding.matches:
            value = finding.name if match.field == "name" else finding.url
            print(
                f"- {match.severity}/{match.category} {match.field} "
                f"term={match.term!r} type={match.match_type} "
                f"id={finding.station_id!r} country={finding.country_key!r} "
                f"value={short(value)!r}"
            )

    hidden_count = len(findings) - len(visible_findings)
    if hidden_count > 0:
        print(f"... {hidden_count} more matching station row(s) hidden; use --max-results 0 to show all.")

    if removal is not None:
        print(f"Removed {removal.removed_count} station row(s) from {source_label(source)}.")
        if removal.regenerated_artifacts:
            print("Regenerated station artifacts.")


def selected_station_count(stations: list[dict[str, Any]], country_filter: set[str] | None) -> int:
    if not country_filter:
        return len(stations)

    return sum(1 for station in stations if station_field_text(station, "countryKey") in country_filter)


def finding_station_keys(findings: list[Finding]) -> set[tuple[str, str, str, str]]:
    return {
        (
            finding.station_id,
            finding.country_key,
            finding.name,
            finding.url,
        )
        for finding in findings
    }


def station_key(station: dict[str, Any]) -> tuple[str, str, str, str]:
    return (
        station_field_text(station, "id"),
        station_field_text(station, "countryKey"),
        station_field_text(station, "name"),
        station_field_text(station, "url"),
    )


def save_stations(path: Path, stations: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(stations, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    tmp.replace(path)


def remove_matched_stations(
    source: Path,
    stations: list[dict[str, Any]],
    findings: list[Finding],
    skip_artifact_build: bool,
) -> RemovalResult | None:
    if not findings:
        return None

    matched_keys = finding_station_keys(findings)
    kept = [station for station in stations if station_key(station) not in matched_keys]
    removed_count = len(stations) - len(kept)
    if removed_count == 0:
        return RemovalResult(removed_count=0, regenerated_artifacts=False)

    is_default_source = source.resolve() == DEFAULT_SOURCE.resolve()
    regenerated_artifacts = False

    if is_default_source and not skip_artifact_build:
        import build_station_artifacts

        build_station_artifacts.validate(kept)
        save_stations(source, kept)
        with contextlib.redirect_stdout(io.StringIO()):
            build_result = build_station_artifacts.main()
        if build_result != 0:
            raise RuntimeError(f"station artifact generation failed with exit code {build_result}")
        regenerated_artifacts = True
    else:
        save_stations(source, kept)

    return RemovalResult(
        removed_count=removed_count,
        regenerated_artifacts=regenerated_artifacts,
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check station names and URLs for offensive terms")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE, help="Station JSON source path")
    parser.add_argument("--country", action="append", default=None, help="Country key to check, repeatable")
    parser.add_argument(
        "--field",
        action="append",
        choices=DEFAULT_FIELDS,
        default=None,
        help="Station field to scan. Defaults to name and url; repeatable.",
    )
    parser.add_argument(
        "--min-severity",
        choices=tuple(SEVERITY_RANK),
        default="medium",
        help="Minimum severity to report. Default: medium.",
    )
    parser.add_argument(
        "--word-file",
        action="append",
        type=Path,
        default=[],
        help="Optional CSV file of extra terms: term[,category[,severity]]. Repeatable.",
    )
    parser.add_argument(
        "--category",
        action="append",
        default=None,
        help="Only report terms in this category, e.g. slur. Repeatable. Also limits --remove-matches.",
    )
    parser.add_argument("--json", action="store_true", help="Write machine-readable JSON")
    parser.add_argument(
        "--max-results",
        type=int,
        default=100,
        help="Maximum matching station rows to print in text mode. Use 0 for all.",
    )
    parser.add_argument("--warn-only", action="store_true", help="Return exit code 0 even when matches are found")
    parser.add_argument(
        "--remove-matches",
        action="store_true",
        help="Remove matched station rows from the source JSON. Regenerates station artifacts for the default source.",
    )
    parser.add_argument(
        "--skip-artifact-build",
        action="store_true",
        help="With --remove-matches, do not rebuild generated Lua station artifacts.",
    )
    args = parser.parse_args()

    if args.max_results < 0:
        parser.error("--max-results cannot be negative")
    if args.skip_artifact_build and not args.remove_matches:
        parser.error("--skip-artifact-build requires --remove-matches")

    return args


def main() -> int:
    args = parse_args()
    fields = tuple(args.field or DEFAULT_FIELDS)
    country_filter = set(args.country) if args.country else None

    try:
        stations = load_stations(args.source)
        terms = compile_terms(args.word_file)
    except (OSError, ValueError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2

    category_filter = {category.casefold() for category in args.category} if args.category else None
    terms = filter_terms_by_category(terms, category_filter)
    findings = check_stations(
        stations=stations,
        terms=terms,
        fields=fields,
        min_severity=args.min_severity,
        country_filter=country_filter,
    )
    checked_count = selected_station_count(stations, country_filter)

    removal: RemovalResult | None = None
    if args.remove_matches:
        try:
            removal = remove_matched_stations(
                source=args.source,
                stations=stations,
                findings=findings,
                skip_artifact_build=args.skip_artifact_build,
            )
        except (OSError, ValueError) as e:
            print(f"ERROR: failed to remove matched stations: {e}", file=sys.stderr)
            return 2

    if args.json:
        print_json_report(args.source, checked_count, findings, removal)
    else:
        print_text_report(args.source, checked_count, findings, args.max_results, removal)

    if findings and not args.warn_only and not args.remove_matches:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
