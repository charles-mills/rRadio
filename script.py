#!/usr/bin/env python3
"""
truncate_station_names.py

Usage examples
--------------
# single file
python truncate_station_names.py data_1.lua

# many files at once (shell glob is easiest on *nix)
python truncate_station_names.py data_*.lua

# explicit list
python truncate_station_names.py data_3.lua data_7.lua data_30.lua

The patched versions are written to   patched/<original-filename>
"""

from __future__ import annotations
import argparse, glob, os, re, sys
from pathlib import Path

# ── configuration ────────────────────────────────────────────────────────────
MAX_LEN = 50            # maximum length for station names
NAME_RE  = re.compile(r"n='([^']*)'")   # captures the station name text

def truncate(match: re.Match[str]) -> str:
    """Return the replacement string (truncated if needed) for one regex hit."""
    original = match.group(1)
    if len(original) <= MAX_LEN:
        return match.group(0)           # leave untouched
    return f"n='{original[:MAX_LEN]}'"  # simple hard cut

def process_file(src: Path, out_dir: Path) -> None:
    """Read *src*, patch its content, and write to out_dir/src.name."""
    text = src.read_text(encoding='utf-8')
    patched = NAME_RE.sub(truncate, text)
    out_file = out_dir / src.name
    out_dir.mkdir(parents=True, exist_ok=True)
    out_file.write_text(patched, encoding='utf-8')
    print(f"✓ {src} → {out_file}")

def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="Truncate station names in Lua data files to ≤50 characters."
    )
    parser.add_argument(
        'paths', nargs='+',
        help="File paths or glob patterns (e.g. data_*.lua)"
    )
    parser.add_argument(
        '-o', '--out', default='patched',
        help="Destination directory for patched files (default: patched)"
    )
    args = parser.parse_args(argv)

    # expand globs *after* argparse so Windows users can pass wildcards too
    files: list[Path] = [
        Path(p) for pattern in args.paths for p in glob.glob(pattern, recursive=False)
    ]

    if not files:
        sys.exit("No matching files found.")

    out_dir = Path(args.out)
    for f in files:
        process_file(f, out_dir)

if __name__ == "__main__":
    main()
