#!/usr/bin/env python3
"""Generate an Alire index entry for one validated patchset toolchain release."""

from __future__ import annotations

import hashlib
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PLATFORMS = {
    "linux-x86_64": ("linux", "x86-64"),
    "linux-aarch64": ("linux", "aarch64"),
    "macos-aarch64": ("macos", "aarch64"),
}


def digest(path: pathlib.Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def main() -> int:
    if len(sys.argv) != 5:
        print(
            f"usage: {sys.argv[0]} PATCHSET_VERSION GCC_MAJOR TOOLCHAINS_DIR OUTPUT_DIR",
            file=sys.stderr,
        )
        return 2
    patchset, major, toolchains_arg, output_arg = sys.argv[1:]
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){2}", patchset) or not major.isdigit():
        print("error: patchset must be a three-part numeric version and GCC major must be numeric", file=sys.stderr)
        return 2
    source_version = subprocess.check_output(
        [
            sys.executable,
            str(ROOT / "scripts" / "manifest.py"),
            "patchset",
            patchset,
            major,
            "source_version",
        ],
        text=True,
    ).strip()
    toolchains = pathlib.Path(toolchains_arg).resolve()
    output = pathlib.Path(output_arg).resolve()
    crate_version = f"{source_version}-patchset.{patchset}"
    tag = f"patchset-{patchset}-gcc-{major}"
    base_url = f"https://github.com/flyology-ada/gnat-patches/releases/download/{tag}"

    origins: list[tuple[str, str, str, str]] = []
    for platform, (os_name, arch) in PLATFORMS.items():
        name = f"gnat-flyology-native-gcc-{source_version}-patchset-{patchset}-{platform}.tar.gz"
        matches = list(toolchains.rglob(name))
        if len(matches) != 1:
            print(f"error: expected exactly one {name}, found {len(matches)}", file=sys.stderr)
            return 1
        archive = matches[0]
        sidecar = archive.with_name(archive.name + ".sha256")
        expected_line = f"{digest(archive)}  {archive.name}\n"
        if not sidecar.is_file() or sidecar.read_text() != expected_line:
            print(f"error: checksum sidecar mismatch for {archive.name}", file=sys.stderr)
            return 1
        origins.append((os_name, arch, archive.name, digest(archive)))

    release_dir = output / "index" / "gn" / "gnat_flyology_native"
    release_dir.mkdir(parents=True, exist_ok=True)
    (output / "index" / "index.toml").write_text('version = "1.4.0"\n')
    manifest = release_dir / f"gnat_flyology_native-{crate_version}.toml"
    lines = [
        'name = "gnat_flyology_native"',
        f'version = "{crate_version}"',
        f'provides = ["gnat={source_version}"]',
        'description = "GNAT native compiler with a validated gnat-patches aggregate"',
        'maintainers = ["Yurii Rashkovskii <yrashk@gmail.com>"]',
        'maintainers-logins = ["yrashk"]',
        'licenses = "GPL-3.0-or-later AND GPL-3.0-or-later WITH GCC-exception-3.1"',
        'website = "https://github.com/flyology-ada/gnat-patches"',
        '',
        'auto-gpr-with = false',
        '',
        '[configuration]',
        'disabled = true',
        '',
        '[environment."case(os)".linux]',
        'PATH.prepend = "${CRATE_ROOT}/bin"',
        'LIBRARY_PATH.prepend = "${CRATE_ROOT}/lib64"',
        'LD_LIBRARY_PATH.prepend = "${CRATE_ROOT}/lib64"',
        'LD_RUN_PATH.prepend = "${CRATE_ROOT}/lib64"',
        '',
        '[environment."case(os)".macos]',
        'PATH.prepend = "${CRATE_ROOT}/bin"',
        'LD_LIBRARY_PATH.prepend = "${CRATE_ROOT}/lib"',
        'LD_RUN_PATH.prepend = "${CRATE_ROOT}/lib"',
    ]
    for os_name, arch, name, sha256 in origins:
        lines.extend(
            [
                '',
                f'[origin."case(os)".{os_name}."case(host-arch)".{arch}]',
                'binary = true',
                f'url = "{base_url}/{name}"',
                f'hashes = ["sha256:{sha256}"]',
            ]
        )
    manifest.write_text("\n".join(lines) + "\n")
    print(manifest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
