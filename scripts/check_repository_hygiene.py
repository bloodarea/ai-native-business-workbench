#!/usr/bin/env python3
"""Fail when a Git index contains local-only AINBW materials.

Run from the repository root after git add, or in public CI.
Does not replace secret scanning or checking built installers.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".svg", ".webp", ".gif", ".avif"}


def prohibited(path: str) -> bool:
    p = path.replace("\\", "/")
    parts = p.split("/")
    low = p.lower()
    name = parts[-1].lower()
    if low in {"agents.md"} or ".agents" in parts:
        return True
    if any(part.lower() in {".ainbw", ".anbw"} for part in parts):
        return True
    if parts and parts[0].lower() == "references":
        return True
    if low.startswith("docs/"):
        return not (low.startswith("docs/public/") and Path(low).suffix in IMAGE_SUFFIXES)
    if name.startswith(".env") and not name.endswith(".example"):
        return True
    if name.endswith((".db", ".sqlite", ".sqlite3", ".pem", ".key", ".p12", ".pfx")):
        return True
    return False


def main() -> int:
    run = subprocess.run(["git", "ls-files", "-z", "--cached"], cwd=ROOT, capture_output=True)
    if run.returncode:
        print("ERROR: unable to list Git index. Run inside an initialized Git repo.", file=sys.stderr)
        return 2
    tracked = [x.decode("utf-8", "surrogateescape") for x in run.stdout.split(b"\0") if x]
    violations = [p for p in tracked if prohibited(p)]
    if violations:
        print("BLOCKED: private or non-public material is in the Git index:", file=sys.stderr)
        for p in violations:
            print("  - " + p, file=sys.stderr)
        print("Use git rm --cached to untrack; inspect any already-pushed history.", file=sys.stderr)
        return 1
    print(f"OK: {len(tracked)} tracked files passed path-level public hygiene checks.")
    print("Reminder: manually inspect files/diagrams, run secret scanning, and inspect release archives.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
