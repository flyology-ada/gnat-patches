#!/usr/bin/env python3
"""Create a byte-reproducible gzip-compressed tar archive."""

from __future__ import annotations

import gzip
import pathlib
import sys
import tarfile


def normalized(info: tarfile.TarInfo) -> tarfile.TarInfo:
    info.uid = 0
    info.gid = 0
    info.uname = ""
    info.gname = ""
    info.mtime = 0
    info.pax_headers = {}
    return info


def main() -> int:
    if len(sys.argv) not in (3, 4):
        print(f"usage: {sys.argv[0]} SOURCE_DIR ARCHIVE [ROOT_DIRECTORY]", file=sys.stderr)
        return 2
    source = pathlib.Path(sys.argv[1]).resolve()
    archive = pathlib.Path(sys.argv[2]).resolve()
    root_directory = sys.argv[3] if len(sys.argv) == 4 else ""
    if not source.is_dir() or archive.exists():
        print("error: source must exist and archive must not exist", file=sys.stderr)
        return 1
    if root_directory and (
        pathlib.PurePosixPath(root_directory).name != root_directory
        or root_directory in {".", ".."}
    ):
        print("error: root directory must be one safe path component", file=sys.stderr)
        return 1
    with archive.open("xb") as raw:
        with gzip.GzipFile(filename="", fileobj=raw, mode="wb", mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode="w", format=tarfile.PAX_FORMAT) as tar:
                if root_directory:
                    tar.add(source, arcname=root_directory, recursive=False, filter=normalized)
                for path in sorted(source.rglob("*"), key=lambda item: item.as_posix()):
                    name = path.relative_to(source).as_posix()
                    if root_directory:
                        name = f"{root_directory}/{name}"
                    tar.add(path, arcname=name, recursive=False, filter=normalized)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
