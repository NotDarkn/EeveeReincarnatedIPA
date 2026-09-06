#!/usr/bin/env python3
"""
l10n_lint.py — Localization key linter for EeveeSpotifyReincarnated.

Cross-checks every *.lproj/Localizable.strings against the English baseline and
optionally against keys actually referenced in Swift sources.

Checks:
  1. Missing keys   — key exists in en.lproj but not in locale X (error)
  2. Extra keys     — key exists in locale X but not in en.lproj (error, usually stale)
  3. Unused keys    — key defined in en.lproj but never referenced in Swift code
                      (warning; .strings values are used dynamically so review
                      each hit manually before deleting)
  4. Format args    — key uses %@" / %@d style placeholders but the locale's
                      value has a different number of them (error)

Usage:
  python3 Tools/l10n_lint.py                 # lint all locales
  python3 Tools/l10n_lint.py --locale ko     # lint a single locale
  python3 Tools/l10n_lint.py --no-usage      # skip the Swift cross-reference
  python3 Tools/l10n_lint.py --quiet         # only print problems (exit code)

Exit code is 1 when errors (missing/extra/format) are found, 0 otherwise.
Warnings (unused keys) alone do not fail the run.
"""

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BUNDLE_DIR = REPO_ROOT / "layout" / "Library" / "Application Support" / "EeveeSpotify.bundle"
SOURCES_DIR = REPO_ROOT / "Sources"

BASELINE = "en"

# One .strings entry: key = "value";  (value may contain escaped quotes)
ENTRY_RE = re.compile(r'^\s*(?P<key>"(?:[^"\\]|\\.)*"|[\w.\-]+)\s*=\s*"(?P<value>(?:[^"\\]|\\.)*)"\s*;', re.M)
COMMENT_RE = re.compile(r"/\*.*?\*/", re.S)
LINE_COMMENT_RE = re.compile(r"^\s*//.*$", re.M)

# Format specifiers that must match across translations: %@, %1$@, %d, %ld, %lu...
FORMAT_SPEC_RE = re.compile(r"%\d+\$[@dDuUxXoOfeEgGcCsS]|%[@dDuUxXoOfeEgGcCsS]")


def parse_strings_file(path: Path) -> dict[str, str]:
    """Parse a .strings file into an ordered {key: value} dict."""
    text = path.read_text(encoding="utf-8")
    text = COMMENT_RE.sub("", text)
    text = LINE_COMMENT_RE.sub("", text)
    entries = {}
    for m in ENTRY_RE.finditer(text):
        key = m.group("key").strip('"')
        entries[key] = m.group("value")
    return entries


def referenced_keys() -> set[str]:
    """Collect localization keys referenced anywhere in Swift sources."""
    keys: set[str] = set()
    if not SOURCES_DIR.exists():
        return keys
    swift_files = list(SOURCES_DIR.rglob("*.swift"))
    # Match: "key".localized / .localizeWithFormat / String(localized:) style usage,
    # plus raw table lookups. Keys are [a-zA-Z0-9_.-]+ quoted strings.
    patterns = [
        re.compile(r'"([A-Za-z0-9_.\-]+)"\s*\.\s*localized'),
        re.compile(r'"([A-Za-z0-9_.\-]+)"\s*\.\s*localizeWithFormat'),
        re.compile(r'localizedString\(\s*"([A-Za-z0-9_.\-]+)"'),
        re.compile(r'table:\s*[^,]+,\s*value:\s*"([A-Za-z0-9_.\-]+)"'),
    ]
    for sf in swift_files:
        try:
            text = sf.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for pat in patterns:
            keys.update(pat.findall(text))
    return keys


def count_format_specs(value: str) -> int:
    return len(FORMAT_SPEC_RE.findall(value))


def locale_dirs() -> list[Path]:
    return sorted(p for p in BUNDLE_DIR.glob("*.lproj") if p.is_dir())


def main() -> int:
    parser = argparse.ArgumentParser(description="Lint .strings localization files")
    parser.add_argument("--locale", help="lint only this locale code (e.g. ko, zh-CN)")
    parser.add_argument("--no-usage", action="store_true", help="skip unused-key check against Swift sources")
    parser.add_argument("--quiet", action="store_true", help="only print locales with problems")
    args = parser.parse_args()

    if not BUNDLE_DIR.exists():
        print(f"error: bundle dir not found: {BUNDLE_DIR}", file=sys.stderr)
        return 2

    baseline_path = BUNDLE_DIR / f"{BASELINE}.lproj" / "Localizable.strings"
    if not baseline_path.exists():
        print(f"error: baseline file not found: {baseline_path}", file=sys.stderr)
        return 2

    baseline = parse_strings_file(baseline_path)
    usage = set() if args.no_usage else referenced_keys()

    locales = locale_dirs()
    if not locales:
        print("error: no *.lproj directories found", file=sys.stderr)
        return 2

    had_errors = False
    summary: list[str] = []

    for loc_dir in locales:
        loc = loc_dir.name.replace(".lproj", "")
        if loc == BASELINE:
            continue
        if args.locale and loc != args.locale:
            continue
        strings_path = loc_dir / "Localizable.strings"
        if not strings_path.exists():
            summary.append(f"{loc}: MISSING Localizable.strings")
            had_errors = True
            continue

        entries = parse_strings_file(strings_path)
        baseline_keys = set(baseline)
        loc_keys = set(entries)

        missing = sorted(baseline_keys - loc_keys)
        extra = sorted(loc_keys - baseline_keys)

        # Format-specifier mismatches for keys present in both
        fmt_bad = []
        for key in sorted(baseline_keys & loc_keys):
            n_base = count_format_specs(baseline[key])
            n_loc = count_format_specs(entries[key])
            if n_base != n_loc:
                fmt_bad.append(f"{key} (en has {n_base}, {loc} has {n_loc})")

        unused = sorted(k for k in baseline_keys if k not in usage)

        if args.quiet and not (missing or extra or fmt_bad):
            continue

        print(f"=== {loc} ===")
        print(f"  total keys: {len(loc_keys)} (baseline has {len(baseline_keys)})")
        if missing:
            print(f"  MISSING ({len(missing)}):")
            for k in missing:
                print(f"    - {k}")
        if extra:
            print(f"  EXTRA / stale ({len(extra)}):")
            for k in extra:
                print(f"    - {k}")
        if fmt_bad:
            print(f"  FORMAT-ARG MISMATCH ({len(fmt_bad)}):")
            for k in fmt_bad:
                print(f"    - {k}")
        if unused and not args.no_usage:
            print(f"  UNUSED in Swift code ({len(unused)}) [warning, review before deleting]:")
            for k in unused:
                print(f"    - {k}")
        if not (missing or extra or fmt_bad or unused):
            print("  OK — fully in sync")
        print()

        if missing or extra or fmt_bad:
            had_errors = True
        summary.append(
            f"{loc}: {len(loc_keys)} keys, {len(missing)} missing, {len(extra)} extra"
            + (f", {len(fmt_bad)} format mismatch" if fmt_bad else "")
        )

    if not args.quiet and summary:
        print("---- summary ----")
        for line in summary:
            print(line)

    return 1 if had_errors else 0


if __name__ == "__main__":
    sys.exit(main())
