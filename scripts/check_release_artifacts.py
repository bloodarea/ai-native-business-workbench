#!/usr/bin/env python3
"""Check release staging directories or ZIP/TAR files for private artifacts.

This is a pathname-only guard, NOT a secret scanner or Electron ASAR inspector.
Always combine it with explicit packaging allowlists and manual review.
Usage: python scripts/check_release_artifacts.py <directory-or-archive> [...]
"""
from __future__ import annotations

import argparse
import sys
import tarfile
import zipfile
from pathlib import Path, PurePosixPath

BAD_SUFFIXES = (".db", ".sqlite", ".sqlite3", ".log", ".pem", ".key", ".p12", ".pfx")
BAD_EXACT_NAMES = {"agents.md", "technical_design.md"}
BAD_PARTS = {".ainbw", ".anbw", ".agents", "node_modules", "__pycache__"}


def disallowed(filename: str) -> bool:
    parts = [part.lower() for part in filename.replace("\\", "/").split("/") if part not in ("", ".")]
    if not parts:
        return False
    if any(part in BAD_PARTS for part in parts):
        return True
    if any(parts[i:i+2] == ["docs", "internal"] for i in range(len(parts)-1)):
        return True
    if any(part.startswith(".env") and not part.endswith(".example") for part in parts):
        return True
    if parts[-1] in BAD_EXACT_NAMES or parts[-1].endswith(BAD_SUFFIXES):
        return True
    if parts[-1].endswith((".db-wal", ".db-shm", ".sqlite-wal", ".sqlite-shm")):
        return True
    return False


def entries(path: Path) -> list[str]:
    if path.is_dir():
        return [p.relative_to(path).as_posix() for p in path.rglob("*") if p.is_file()]
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as z:
            return [x.filename for x in z.infolist() if not x.is_dir()]
    if tarfile.is_tarfile(path):
        with tarfile.open(path, "r:*") as t:
            return [x.name for x in t.getmembers() if x.isfile()]
    raise ValueError("Supported: directory, .zip, or tar archive. Binary installers / ASAR require separate inspection.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", type=Path)
    args = parser.parse_args()
    failed = False
    for path in args.paths:
        try:
            if not path.exists():
                raise ValueError("path does not exist")
            names = entries(path)
            bad = [p for p in names if disallowed(p)]
            if bad:
                failed = True
                print(f"BLOCKED {path} — {len(bad)} forbidden path(s)", file=sys.stderr)
                for p in bad[:40]:
                    print("  - " + p, file=sys.stderr)
            else:
                print(f"OK {path} — {len(names)} paths checked")
        except (OSError, ValueError, tarfile.TarError, zipfile.BadZipFile) as exc:
            failed = True
            print(f"ERROR {path}: {exc}", file=sys.stderr)
    if failed:
        return 1
    print("Reminder: path checks cannot find secrets in file contents or embedded binary/ASAR resources.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
