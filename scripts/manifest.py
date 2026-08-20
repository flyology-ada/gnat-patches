#!/usr/bin/env python3
"""Read and validate gnat-patches manifests using Python's standard library."""

from __future__ import annotations

import argparse
import hashlib
import os
import pathlib
import sys
import tomllib

ROOT = pathlib.Path(__file__).resolve().parent.parent


class ManifestError(RuntimeError):
    pass


def load(path: pathlib.Path) -> dict:
    try:
        with path.open("rb") as stream:
            return tomllib.load(stream)
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise ManifestError(f"cannot read {path.relative_to(ROOT)}: {exc}") from exc


def source_path(version: str) -> pathlib.Path:
    path = ROOT / "sources" / f"gcc-{version}.toml"
    if not path.is_file():
        raise ManifestError(f"unsupported GCC source version: {version}")
    return path


def helper_path(version: str) -> pathlib.Path:
    path = ROOT / "sources" / f"binutils-{version}.toml"
    if not path.is_file():
        raise ManifestError(f"unsupported Binutils source version: {version}")
    return path


def patchset_path(version: str, major: int) -> pathlib.Path:
    path = ROOT / "patchsets" / version / f"gcc-{major}.toml"
    if not path.is_file():
        raise ManifestError(f"unsupported patchset/GCC pair: {version}/gcc-{major}")
    return path


def bundle_path(bundle_id: str) -> pathlib.Path:
    path = ROOT / "bundles" / bundle_id / "manifest.toml"
    if not path.is_file():
        raise ManifestError(f"unknown bundle: {bundle_id}")
    return path


def nested(data: dict, key: str):
    value = data
    for part in key.split("."):
        if not isinstance(value, dict) or part not in value:
            raise ManifestError(f"missing manifest field: {key}")
        value = value[part]
    return value


def emit(value) -> None:
    if isinstance(value, list):
        for item in value:
            print(item)
    elif isinstance(value, bool):
        print("true" if value else "false")
    else:
        print(value)


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def patchset_key(version: str) -> tuple[int, int, int]:
    try:
        parts = tuple(int(part) for part in version.split("."))
    except (AttributeError, ValueError) as exc:
        raise ManifestError(f"invalid patchset version: {version}") from exc
    if len(parts) != 3 or any(part < 0 for part in parts):
        raise ManifestError(f"invalid patchset version: {version}")
    return parts


def selected_variant(bundle: dict, version: str) -> dict:
    matches = [item for item in bundle.get("variants", []) if version in item.get("versions", [])]
    if len(matches) != 1:
        raise ManifestError(
            f"bundle {bundle.get('id')} has {len(matches)} variants for GCC {version}; expected exactly one"
        )
    return matches[0]


def extract_added_file(patch: pathlib.Path, target: str) -> bytes:
    lines = patch.read_bytes().splitlines(keepends=True)
    marker = f"diff --git a/{target} b/{target}".encode()
    inside = False
    hunk = False
    result: list[bytes] = []
    for line in lines:
        if line.rstrip(b"\r\n") == marker:
            inside = True
            hunk = False
            continue
        if inside and line.startswith(b"diff --git "):
            break
        if not inside:
            continue
        if line.startswith(b"@@ "):
            hunk = True
            continue
        if hunk and line.startswith(b"+") and not line.startswith(b"+++"):
            result.append(line[1:])
    if not result:
        raise ManifestError(f"{patch.relative_to(ROOT)} does not add {target}")
    return b"".join(result)


BUNDLE_STATUSES = ("accepted", "staged")


def curated_bundles() -> dict[str, dict]:
    """Every bundle this repository curates, accepted or staged."""

    result = {}
    for path in sorted((ROOT / "bundles").glob("*/manifest.toml")):
        bundle = load(path)
        bundle_id = bundle.get("id")
        if not bundle_id or bundle_id in result:
            raise ManifestError(f"invalid or duplicate bundle id in {path.relative_to(ROOT)}")
        if bundle.get("status") not in BUNDLE_STATUSES:
            raise ManifestError(
                f"bundle {bundle_id} status must be one of {list(BUNDLE_STATUSES)}"
            )
        result[bundle_id] = bundle
    return result


def with_status(bundles: dict[str, dict], status: str) -> dict[str, dict]:
    return {
        bundle_id: bundle
        for bundle_id, bundle in bundles.items()
        if bundle["status"] == status
    }


def bundle_release_key(bundle: dict) -> tuple[int, int, int]:
    """The patchset release a bundle is scheduled against, by status."""

    field = "introduced_in_patchset" if bundle["status"] == "accepted" else "staged_in_patchset"
    return patchset_key(bundle.get(field))


def validate_bundle(bundle: dict) -> None:
    bundle_id = bundle["id"]
    bundle_release_key(bundle)
    # Whether this patch applies to pristine upstream source, or only in the
    # patchset's recorded order. scripts/check-standalone.sh proves the claim.
    if not isinstance(bundle.get("standalone_patch"), bool):
        raise ManifestError(f"bundle {bundle_id} must declare a boolean standalone_patch")
    if bundle["status"] == "accepted":
        if "staged_in_patchset" in bundle:
            raise ManifestError(f"accepted bundle {bundle_id} declares staged_in_patchset")
    else:
        if "introduced_in_patchset" in bundle:
            raise ManifestError(f"staged bundle {bundle_id} declares introduced_in_patchset")
        if not bundle.get("staged_reason"):
            raise ManifestError(f"staged bundle {bundle_id} has no staged_reason")
        for dependency in bundle.get("staged_depends_on", []):
            if dependency == bundle_id:
                raise ManifestError(f"staged bundle {bundle_id} depends on itself")
    tests = bundle.get("regression_tests", [])
    if not tests:
        raise ManifestError(f"accepted bundle {bundle_id} has no regression tests")
    fixture = ROOT / bundle["repository_fixture"]
    if not fixture.is_file() or sha256(fixture) != bundle["fixture_sha256"]:
        raise ManifestError(f"fixture checksum mismatch for {bundle_id}")
    runner = ROOT / bundle.get("repository_test_runner", "")
    if not runner.is_file() or not os.access(runner, os.X_OK):
        raise ManifestError(f"missing or nonexecutable regression runner for {bundle_id}")
    affected = set(bundle.get("affected_versions", []))
    known_good = set(bundle.get("known_good_versions", []))
    if not affected or affected & known_good:
        raise ManifestError(f"invalid affected/known-good split for {bundle_id}")
    coverage: set[str] = set()
    for variant in bundle.get("variants", []):
        versions = set(variant.get("versions", []))
        if not versions or coverage & versions:
            raise ManifestError(f"overlapping or empty variants for {bundle_id}")
        coverage |= versions
        patch = ROOT / variant["patch"]
        if not patch.is_file() or sha256(patch) != variant["sha256"]:
            raise ManifestError(f"patch checksum mismatch for {bundle_id}/{variant.get('id')}")
        added = extract_added_file(patch, tests[0])
        if added != fixture.read_bytes():
            raise ManifestError(f"repository fixture differs from the patch test for {bundle_id}")
    if coverage != affected:
        raise ManifestError(f"variants do not exactly cover affected versions for {bundle_id}")
    for version in affected | known_good:
        source_path(version)


def applicable(
    bundles: dict[str, dict], release_key: tuple[int, int, int], version: str, field: str
) -> list[str]:
    return sorted(
        bundle_id
        for bundle_id, bundle in bundles.items()
        if bundle_release_key(bundle) <= release_key and version in bundle.get(field, [])
    )


def validate_patchset(version: str, major: int, bundles: dict[str, dict]) -> dict:
    patchset = load(patchset_path(version, major))
    release_key = patchset_key(version)
    if patchset.get("patchset_version") != version or patchset.get("gcc_major") != major:
        raise ManifestError(f"patchset identity mismatch for {version}/gcc-{major}")
    source = load(source_path(patchset["source_version"]))
    if source.get("major") != major:
        raise ManifestError(f"source major mismatch for {version}/gcc-{major}")
    accepted = with_status(bundles, "accepted")
    staged = with_status(bundles, "staged")
    source_version = patchset["source_version"]
    expected = applicable(accepted, release_key, source_version, "affected_versions")
    declared = patchset.get("bundles", [])
    if len(declared) != len(set(declared)) or sorted(declared) != expected:
        raise ManifestError(
            f"{version}/gcc-{major} must contain every accepted applicable bundle: {expected}"
        )
    controls = patchset.get("control_tests", [])
    expected_controls = applicable(
        accepted, release_key, source_version, "known_good_versions"
    )
    if sorted(controls) != expected_controls:
        raise ManifestError(
            f"{version}/gcc-{major} control list must be exactly {expected_controls}"
        )
    expected_staged = applicable(staged, release_key, source_version, "affected_versions")
    declared_staged = patchset.get("staged_bundles", [])
    if (
        len(declared_staged) != len(set(declared_staged))
        or sorted(declared_staged) != expected_staged
    ):
        raise ManifestError(
            f"{version}/gcc-{major} staged list must be exactly {expected_staged}"
        )
    if set(declared_staged) & set(declared + controls):
        raise ManifestError(
            f"{version}/gcc-{major} lists a staged bundle as a patchset bundle or control"
        )
    for bundle_id in declared_staged:
        missing = [
            dependency
            for dependency in bundles[bundle_id].get("staged_depends_on", [])
            if dependency not in declared_staged
        ]
        if missing:
            raise ManifestError(
                f"{version}/gcc-{major} stages {bundle_id} without its prerequisites: {missing}"
            )
    for bundle_id in declared + declared_staged:
        selected_variant(bundles[bundle_id], source_version)
    return patchset


def validate_all(version: str | None = None, major: int | None = None) -> None:
    helper = load(helper_path("2.46.1"))
    if (
        helper.get("version") != "2.46.1"
        or len(helper.get("sha512", "")) != 128
        or not helper.get("url", "").endswith(helper.get("archive", "missing"))
    ):
        raise ManifestError("invalid Binutils helper source manifest")
    bundles = curated_bundles()
    for bundle in bundles.values():
        validate_bundle(bundle)
    for bundle in with_status(bundles, "staged").values():
        for dependency in bundle.get("staged_depends_on", []):
            if dependency not in bundles:
                raise ManifestError(
                    f"staged bundle {bundle['id']} depends on unknown bundle {dependency}"
                )
            if bundles[dependency]["status"] != "staged":
                raise ManifestError(
                    f"staged bundle {bundle['id']} depends on accepted bundle {dependency}"
                )
    if version is not None and major is not None:
        validate_patchset(version, major, bundles)
    else:
        for path in sorted((ROOT / "patchsets").glob("*/gcc-*.toml")):
            data = load(path)
            validate_patchset(data["patchset_version"], data["gcc_major"], bundles)


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    get_source = sub.add_parser("source")
    get_source.add_argument("version")
    get_source.add_argument("field")
    get_helper = sub.add_parser("helper")
    get_helper.add_argument("version")
    get_helper.add_argument("field")
    get_patchset = sub.add_parser("patchset")
    get_patchset.add_argument("version")
    get_patchset.add_argument("major", type=int)
    get_patchset.add_argument("field")
    get_bundle = sub.add_parser("bundle")
    get_bundle.add_argument("bundle_id")
    get_bundle.add_argument("version")
    get_bundle.add_argument("field", choices=("patch", "sha256", "variant", "runner"))
    get_bundle_field = sub.add_parser("bundle-field")
    get_bundle_field.add_argument("bundle_id")
    get_bundle_field.add_argument("field")
    validate = sub.add_parser("validate")
    validate.add_argument("--patchset")
    validate.add_argument("--gcc", type=int)
    args = parser.parse_args()
    try:
        if args.command == "source":
            emit(nested(load(source_path(args.version)), args.field))
        elif args.command == "helper":
            emit(nested(load(helper_path(args.version)), args.field))
        elif args.command == "patchset":
            emit(nested(load(patchset_path(args.version, args.major)), args.field))
        elif args.command == "bundle-field":
            emit(nested(load(bundle_path(args.bundle_id)), args.field))
        elif args.command == "bundle":
            bundle = load(bundle_path(args.bundle_id))
            if args.field == "runner":
                emit(bundle["repository_test_runner"])
            else:
                variant = selected_variant(bundle, args.version)
                key = "id" if args.field == "variant" else args.field
                emit(variant[key])
        elif args.command == "validate":
            if (args.patchset is None) != (args.gcc is None):
                raise ManifestError("--patchset and --gcc must be supplied together")
            validate_all(args.patchset, args.gcc)
            print("manifest validation: PASS")
    except ManifestError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
