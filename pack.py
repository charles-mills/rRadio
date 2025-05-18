#!/usr/bin/env python3
r"""
pack_chunks.py – repack patched Lua station files into ≤62 KiB chunks
--------------------------------------------------------------------
Example
    python pack_chunks.py patched
    python pack_chunks.py patched -k 60 -o packed60
"""

from __future__ import annotations
import argparse, glob, sys
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Tuple

MAX_KIB_DEFAULT = 63.5                           # 62 KiB per chunk
ENTRY_RE = r"{n='[^']*',u='[^']*'}"              # quick station matcher


# ── robust country-section extractor (brace counting) ───────────────────────
def extract_sections(text: str) -> List[Tuple[str, str]]:
    """
    Return (country, section_text) for every country in the Lua string.
    Each *section_text* begins just after '{{' and ends just before the
    corresponding '},}' delimiter.
    """
    i, n = 0, len(text)
    sections: List[Tuple[str, str]] = []

    while True:
        # find next ['country']
        start_key = text.find("['", i)
        if start_key == -1:
            break
        end_key = text.find("']", start_key + 2)
        if end_key == -1:
            break
        country = text[start_key + 2:end_key]

        # find the first '{{' after the key
        brace_open = text.find("{{", end_key)
        if brace_open == -1:
            break

        depth = 2        # we just saw '{{'
        pos = brace_open + 2
        while pos < n and depth:
            ch = text[pos]
            if ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
            pos += 1

        if depth != 0:
            # malformed – bail out
            break

        # pos is now just after the matching final '}', i.e. at the comma
        section = text[brace_open + 2 : pos - 1]     # without the outer braces
        sections.append((country, section))
        i = pos + 1

    return sections


# ── helpers ──────────────────────────────────────────────────────────────────
def parse_file(path: Path) -> List[Tuple[str, str]]:
    """
    Read *path* and return (country, station_entry_text) for every entry inside.
    """
    txt = path.read_text(encoding='utf-8')
    out: List[Tuple[str, str]] = []
    for country, body in extract_sections(txt):
        for m in __import__("re").finditer(ENTRY_RE, body):
            out.append((country, m.group(0)))
    return out


def lua_dump(country_map: Dict[str, List[str]]) -> str:
    """Serialise a country→entries map back to Lua source."""
    parts = ['return{']
    first = True
    for c, lst in country_map.items():
        parts.append('' if first else ',')
        first = False
        parts.append(f"['{c}']={{")
        parts.append(','.join(lst))
        parts.append('}}')
    parts.append('}')
    return ''.join(parts)


def first_fit_decreasing(entries: List[Tuple[str, str]], limit: int):
    """Bin-pack entries into as few bins as possible (FFD heuristic)."""
    entries.sort(key=lambda e: len(e[1]), reverse=True)
    bins: List[Dict[str, List[str]]] = []

    for country, entry in entries:
        for b in bins:
            candidate = lua_dump({**b, country: b.get(country, []) + [entry]})
            if len(candidate.encode()) <= limit:
                b.setdefault(country, []).append(entry)
                break
        else:
            bins.append({country: [entry]})
    return bins


def collect_paths(args: List[str]) -> List[Path]:
    paths: List[Path] = []
    for pat in args:
        for p in glob.glob(pat, recursive=True):
            pth = Path(p)
            if pth.is_dir():
                paths.extend(pth.rglob('data_*.lua'))
            elif pth.is_file():
                paths.append(pth)
    return list(dict.fromkeys(paths))   # deduplicate, preserve order


# ── main ─────────────────────────────────────────────────────────────────────
def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument('paths', nargs='+',
                    help='files / directories / globs to read')
    ap.add_argument('-k', '--kib', type=int, default=MAX_KIB_DEFAULT,
                    help='max chunk size in KiB (default 62)')
    ap.add_argument('-o', '--out', default='packed',
                    help='output directory (default "packed")')
    a = ap.parse_args(argv)

    files = collect_paths(a.paths)
    if not files:
        sys.exit('No input files found.')

    all_entries = [e for f in files for e in parse_file(f)]
    if not all_entries:
        sys.exit('No station entries discovered – check your input files.')

    bins = first_fit_decreasing(all_entries, a.kib * 1024)

    out_dir = Path(a.out).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    for idx, bin_map in enumerate(bins, 1):
        lua = lua_dump(bin_map)
        target = out_dir / f"data_{idx}.lua"
        target.write_text(lua, encoding='utf-8')
        size = len(lua.encode()) / 1024
        print(f"✓ {target}  ({size:.1f} KiB)")

    print(f"\nDone – created {len(bins)} chunk file(s).")


if __name__ == '__main__':
    main()
