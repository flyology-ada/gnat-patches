#!/usr/bin/env python3
"""Verify and report the single directory at an Alire binary archive root."""

from __future__ import annotations

import pathlib
import sys
import tarfile


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} ARCHIVE", file=sys.stderr)
        return 2
    archive = pathlib.Path(sys.argv[1])
    try:
        with tarfile.open(archive, "r:gz") as tar:
            members = tar.getmembers()
    except (OSError, tarfile.TarError) as exc:
        print(f"error: cannot read {archive}: {exc}", file=sys.stderr)
        return 1
    if not members:
        print("error: Alire binary archive is empty", file=sys.stderr)
        return 1

    roots: set[str] = set()
    root_directories: set[str] = set()
    for member in members:
        path = pathlib.PurePosixPath(member.name)
        if path.is_absolute() or not path.parts or ".." in path.parts:
            print(f"error: unsafe archive member: {member.name}", file=sys.stderr)
            return 1
        roots.add(path.parts[0])
        if len(path.parts) == 1 and member.isdir():
            root_directories.add(path.parts[0])
    if len(roots) != 1 or roots != root_directories:
        print(
            "error: Alire binary archive must contain exactly one root directory",
            file=sys.stderr,
        )
        return 1
    print(next(iter(roots)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
