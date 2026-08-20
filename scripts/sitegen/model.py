"""Load the repository's manifests into the catalog the website publishes.

Loading is fail-closed. Every patch and fixture checksum recorded in a bundle
manifest is recomputed here, every cross-reference between a patchset and a
bundle is resolved, and a bundle that claims a status its patchsets do not
support stops the build. The website therefore cannot describe evidence the
repository does not actually hold.

Release facts are not in the manifests, so publication state is read from the
GitHub Releases API. A build that cannot reach it fails rather than inventing
an installation command for a compiler nobody can install.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import tomllib
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from . import markdown


class CatalogError(ValueError):
    """Raised when the repository does not support what the site would claim."""


REPOSITORY = "flyology-ada/gnat-patches"
REPOSITORY_URL = f"https://github.com/{REPOSITORY}"
RELEASES_API = f"https://api.github.com/repos/{REPOSITORY}/releases"
ALIRE_CRATE = "gnat_flyology_native"
ALIRE_INDEX_URL = "git+https://github.com/flyology-ada/alire-index.git"
SCHEMA_VERSION = 1

PATCHED = "patched"
CONTROL = "control"
STAGED = "staged"
ABSENT = "absent"

ROLE_LABEL = {
    PATCHED: "Patched",
    CONTROL: "Known-good control",
    STAGED: "Staged",
    ABSENT: "Not applicable",
}

ROLE_DESCRIPTION = {
    PATCHED: "The patchset applies this bundle's patch to this compiler.",
    CONTROL: "This release does not have the defect. It ships unpatched and the bundle's regression runs against it as a control.",
    STAGED: "The bundle is held out of the published patchset and its evidence makes no claim about this release.",
    ABSENT: "The patchset does not cover this bundle for this compiler.",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def version_key(version: str) -> tuple[int, ...]:
    return tuple(int(part) if part.isdigit() else 0 for part in version.split("."))


def generated_at() -> str:
    epoch = os.environ.get("SOURCE_DATE_EPOCH")
    instant = datetime.fromtimestamp(int(epoch), UTC) if epoch else datetime.now(UTC)
    return instant.replace(microsecond=0).isoformat().replace("+00:00", "Z")


def load_toml(path: Path) -> dict[str, Any]:
    try:
        return tomllib.loads(path.read_text(encoding="utf-8"))
    except (OSError, tomllib.TOMLDecodeError) as error:
        raise CatalogError(f"{path}: {error}") from error


#  Releases.


@dataclass(frozen=True)
class Release:
    tag: str
    name: str
    url: str
    prerelease: bool
    published_at: str
    assets: tuple[str, ...]

    @property
    def state(self) -> str:
        return "prerelease" if self.prerelease else "published"


def fetch_releases(*, offline: bool = False) -> dict[str, Release] | None:
    """Return every published release keyed by tag, or None when offline."""
    if offline:
        return None

    releases: dict[str, Release] = {}
    page = 1
    while True:
        request = urllib.request.Request(
            f"{RELEASES_API}?per_page=100&page={page}",
            headers={
                "Accept": "application/vnd.github+json",
                "User-Agent": "gnat-patches-site-generator",
                "X-GitHub-Api-Version": "2022-11-28",
            },
        )
        token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
        if token:
            request.add_header("Authorization", f"Bearer {token}")
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                batch = json.load(response)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
            raise CatalogError(
                f"the GitHub Releases API is unreachable: {error}. "
                "Pass --offline to build a site that makes no publication claim."
            ) from error
        if not batch:
            break
        for entry in batch:
            if entry.get("draft"):
                continue
            releases[entry["tag_name"]] = Release(
                tag=entry["tag_name"],
                name=entry.get("name") or entry["tag_name"],
                url=entry["html_url"],
                prerelease=bool(entry.get("prerelease")),
                published_at=entry.get("published_at") or "",
                assets=tuple(asset["name"] for asset in entry.get("assets", [])),
            )
        page += 1
        if len(batch) < 100:
            break
    return releases


ASSET_PLATFORMS = {
    "linux-x86_64": "Linux x86-64",
    "linux-aarch64": "Linux AArch64",
    "macos-aarch64": "macOS AArch64",
}


def release_for(
    releases: dict[str, Release] | None, patchset: str, major: int, source_version: str
) -> dict[str, Any] | None:
    """Return the release facts for one patchset target.

    Two tag spellings are in use: the current one names the exact source
    release, and earlier patchsets named the GCC major alone.
    """
    if releases is None:
        return None
    for tag in (
        f"patchset-{patchset}-gcc-{source_version}",
        f"patchset-{patchset}-gcc-{major}",
    ):
        release = releases.get(tag)
        if release is None:
            continue
        platforms = [
            label
            for suffix, label in ASSET_PLATFORMS.items()
            if any(asset.endswith(f"-{suffix}.tar.gz") for asset in release.assets)
        ]
        return {
            "tag": release.tag,
            "name": release.name,
            "url": release.url,
            "state": release.state,
            "published_at": release.published_at,
            "platforms": platforms,
            "assets": list(release.assets),
            "alire_crate": ALIRE_CRATE,
            "alire_version": f"{source_version}-patchset.{patchset}",
        }
    return None


#  Catalog.


def load_catalog(root: Path, *, releases: dict[str, Release] | None) -> dict[str, Any]:
    sources = load_sources(root)
    bundles = load_bundles(root)
    patchsets = load_patchsets(root, sources, bundles, releases)
    assign_roles(bundles, patchsets)
    verify_bundle_membership(bundles)

    latest = patchsets[0]["version"] if patchsets else None
    published = [
        patchset["version"]
        for patchset in patchsets
        if any(
            (target["release"] or {}).get("state") == "published"
            for target in patchset["targets"]
        )
    ]

    return {
        "schema_version": SCHEMA_VERSION,
        "generated_at": generated_at(),
        "canonical_url": CANONICAL_URL,
        "repository_url": REPOSITORY_URL,
        "publication_checked": releases is not None,
        "latest_patchset": latest,
        "latest_published_patchset": published[0] if published else None,
        "sources": sources,
        "patchsets": patchsets,
        "bundles": bundles,
    }


CANONICAL_URL = "https://gnat-patches.flyology.org/"


def load_sources(root: Path) -> list[dict[str, Any]]:
    sources = []
    for path in sorted((root / "sources").glob("gcc-*.toml")):
        data = load_toml(path)
        data["path"] = str(path.relative_to(root))
        sources.append(data)
    if not sources:
        raise CatalogError("no GCC source manifests were found")
    sources.sort(key=lambda source: version_key(source["version"]))
    return sources


def load_bundles(root: Path) -> list[dict[str, Any]]:
    bundles = []
    for manifest_path in sorted((root / "bundles").glob("*/manifest.toml")):
        directory = manifest_path.parent
        data = load_toml(manifest_path)
        identifier = data.get("id")
        if identifier != directory.name:
            raise CatalogError(
                f"{manifest_path}: id {identifier!r} does not match directory {directory.name!r}"
            )

        readme_path = directory / "README.md"
        if not readme_path.is_file():
            raise CatalogError(f"{identifier}: README.md is missing")
        readme = readme_path.read_text(encoding="utf-8")
        title = markdown.first_heading(readme)
        if not title:
            raise CatalogError(f"{identifier}: README.md has no heading to use as a title")

        verify_checksums(root, data)
        verify_versions(data)

        data["title"] = title
        data["readme_path"] = str(readme_path.relative_to(root))
        data["directory"] = str(directory.relative_to(root))
        data["tests"] = [
            str(path.relative_to(root))
            for path in sorted(directory.glob("tests/*"))
            if path.is_file()
        ]
        if not data["tests"]:
            raise CatalogError(f"{identifier}: an accepted bundle ships executable tests")
        bundles.append(data)

    if not bundles:
        raise CatalogError("no bundles were found")
    return bundles


def verify_checksums(root: Path, bundle: dict[str, Any]) -> None:
    identifier = bundle["id"]
    variants = bundle.get("variants") or []
    if not variants:
        raise CatalogError(f"{identifier}: no patch variants are declared")

    for variant in variants:
        patch_path = root / variant["patch"]
        if not patch_path.is_file():
            raise CatalogError(f"{identifier}: patch {variant['patch']} is missing")
        actual = sha256(patch_path)
        if actual != variant["sha256"]:
            raise CatalogError(
                f"{identifier}: {variant['patch']} hashes to {actual}, "
                f"manifest records {variant['sha256']}"
            )

    fixture_path = root / bundle["repository_fixture"]
    if not fixture_path.is_file():
        raise CatalogError(f"{identifier}: fixture {bundle['repository_fixture']} is missing")
    actual = sha256(fixture_path)
    if actual != bundle["fixture_sha256"]:
        raise CatalogError(
            f"{identifier}: {bundle['repository_fixture']} hashes to {actual}, "
            f"manifest records {bundle['fixture_sha256']}"
        )

    runner_path = root / bundle["repository_test_runner"]
    if not runner_path.is_file():
        raise CatalogError(f"{identifier}: test runner {bundle['repository_test_runner']} is missing")
    if not os.access(runner_path, os.X_OK):
        raise CatalogError(f"{identifier}: test runner {bundle['repository_test_runner']} is not executable")


def verify_versions(bundle: dict[str, Any]) -> None:
    identifier = bundle["id"]
    affected = list(bundle.get("affected_versions") or [])
    known_good = list(bundle.get("known_good_versions") or [])

    overlap = sorted(set(affected) & set(known_good))
    if overlap:
        raise CatalogError(
            f"{identifier}: {', '.join(overlap)} is both affected and known good"
        )

    covered: dict[str, str] = {}
    for variant in bundle["variants"]:
        for version in variant["versions"]:
            if version in covered:
                raise CatalogError(
                    f"{identifier}: variants {covered[version]} and {variant['id']} "
                    f"both claim {version}"
                )
            covered[version] = variant["id"]

    uncovered = sorted(set(affected) - set(covered))
    if uncovered:
        raise CatalogError(
            f"{identifier}: affected releases without a patch variant: {', '.join(uncovered)}"
        )


def load_patchsets(
    root: Path,
    sources: list[dict[str, Any]],
    bundles: list[dict[str, Any]],
    releases: dict[str, Release] | None,
) -> list[dict[str, Any]]:
    known = {bundle["id"] for bundle in bundles}
    source_versions = {source["version"] for source in sources}
    grouped: dict[str, list[dict[str, Any]]] = {}

    for path in sorted((root / "patchsets").glob("*/gcc-*.toml")):
        data = load_toml(path)
        version = data["patchset_version"]
        if version != path.parent.name:
            raise CatalogError(
                f"{path}: declares patchset {version} inside directory {path.parent.name}"
            )
        source_version = data["source_version"]
        if source_version not in source_versions:
            raise CatalogError(f"{path}: no source manifest for GCC {source_version}")

        for key in ("bundles", "control_tests", "staged_bundles"):
            for identifier in data.get(key, []):
                if identifier not in known:
                    raise CatalogError(f"{path}: {key} names unknown bundle {identifier}")

        overlap = set(data.get("bundles", [])) & set(data.get("control_tests", []))
        if overlap:
            raise CatalogError(
                f"{path}: {', '.join(sorted(overlap))} is both patched and a control"
            )
        staged_overlap = set(data.get("staged_bundles", [])) & (
            set(data.get("bundles", [])) | set(data.get("control_tests", []))
        )
        if staged_overlap:
            raise CatalogError(
                f"{path}: staged bundle {', '.join(sorted(staged_overlap))} is also published"
            )

        data["path"] = str(path.relative_to(root))
        data["release"] = release_for(
            releases, version, int(data["gcc_major"]), source_version
        )
        grouped.setdefault(version, []).append(data)

    patchsets = []
    for version, targets in grouped.items():
        targets.sort(key=lambda target: target["gcc_major"])
        patchsets.append(
            {
                "version": version,
                "targets": targets,
            }
        )
    patchsets.sort(key=lambda patchset: version_key(patchset["version"]), reverse=True)
    for index, patchset in enumerate(patchsets):
        patchset["latest"] = index == 0
        patchset["superseded_by"] = patchsets[index - 1]["version"] if index else None
    if not patchsets:
        raise CatalogError("no patchsets were found")
    return patchsets


def assign_roles(bundles: list[dict[str, Any]], patchsets: list[dict[str, Any]]) -> None:
    """Record how every patchset treats every bundle on every GCC major."""
    for bundle in bundles:
        roles: dict[str, dict[str, Any]] = {}
        for patchset in patchsets:
            entries = {}
            for target in patchset["targets"]:
                identifier = bundle["id"]
                if identifier in target.get("bundles", []):
                    role = PATCHED
                elif identifier in target.get("control_tests", []):
                    role = CONTROL
                elif identifier in target.get("staged_bundles", []):
                    role = STAGED
                else:
                    role = ABSENT
                entries[str(target["gcc_major"])] = {
                    "role": role,
                    "source_version": target["source_version"],
                    "variant": variant_for(bundle, target["source_version"])
                    if role == PATCHED
                    else None,
                }
            roles[patchset["version"]] = entries
        bundle["roles"] = roles


def variant_for(bundle: dict[str, Any], source_version: str) -> str | None:
    for variant in bundle["variants"]:
        if source_version in variant["versions"]:
            return variant["id"]
    return None


def verify_bundle_membership(bundles: list[dict[str, Any]]) -> None:
    """Hold every bundle to the membership its status promises."""
    for bundle in bundles:
        identifier = bundle["id"]
        status = bundle["status"]
        roles = {
            entry["role"]
            for patchset in bundle["roles"].values()
            for entry in patchset.values()
        }

        if status == "accepted":
            if PATCHED not in roles and CONTROL not in roles:
                raise CatalogError(
                    f"{identifier}: an accepted bundle appears in no patchset"
                )
            if STAGED in roles:
                raise CatalogError(
                    f"{identifier}: an accepted bundle is staged by a patchset"
                )
        elif status == "staged":
            if PATCHED in roles or CONTROL in roles:
                raise CatalogError(
                    f"{identifier}: a staged bundle is published by a patchset"
                )
            if STAGED not in roles:
                raise CatalogError(
                    f"{identifier}: a staged bundle appears in no patchset's staged list"
                )
            for dependency in bundle.get("staged_depends_on", []):
                if dependency not in {other["id"] for other in bundles}:
                    raise CatalogError(
                        f"{identifier}: staged_depends_on names unknown bundle {dependency}"
                    )
        else:
            raise CatalogError(f"{identifier}: unknown status {status!r}")


#  Panel.


def load_panels(root: Path, bundles: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Return every panel the repository defines, in identifier order."""
    panels = []
    for matrix_path in sorted((root / "panels").glob("*/matrix.toml")):
        directory = matrix_path.parent
        identifier = directory.name
        matrix = load_toml(matrix_path)
        if matrix.get("panel") != identifier:
            raise CatalogError(
                f"{matrix_path}: declares panel {matrix.get('panel')!r} "
                f"inside directory {identifier!r}"
            )

        coverage_path = directory / "coverage.toml"
        if not coverage_path.is_file():
            raise CatalogError(f"panel {identifier}: coverage.toml is missing")
        coverage = load_toml(coverage_path)

        readme_path = directory / "README.md"
        if not readme_path.is_file():
            raise CatalogError(f"panel {identifier}: README.md is missing")
        readme = readme_path.read_text(encoding="utf-8")
        title = markdown.first_heading(readme)
        if not title:
            raise CatalogError(f"panel {identifier}: README.md has no heading to use as a title")

        known = {bundle["id"] for bundle in bundles}
        for feature in matrix.get("features", []):
            feature["evidence_references"] = parse_evidence(
                root, directory, feature.get("evidence", ""), known, feature["id"]
            )

        for suite in coverage.get("runtime", {}).get("suites", []):
            if not (root / suite).exists():
                raise CatalogError(
                    f"panel {identifier}: coverage names missing runtime suite {suite}"
                )

        panels.append(
            {
                "id": identifier,
                "title": title,
                "summary": markdown.first_paragraph(readme),
                "matrix": matrix,
                "coverage": coverage,
                "readme": readme,
                "readme_path": str(readme_path.relative_to(root)),
                "directory": str(directory.relative_to(root)),
            }
        )

    if not panels:
        raise CatalogError("no panels were found")
    return panels


REPOSITORY_ROOTS = ("bundles/", "panels/", "sources/", "scripts/", "ci/", "patchsets/")


def parse_evidence(
    root: Path, panel: Path, evidence: str, known: set[str], feature: str
) -> list[dict[str, Any]]:
    """Return the evidence field as resolved references.

    Evidence is a comma-separated list. An element naming a path is either
    repository-relative or relative to the panel directory, and may carry a
    ``:case`` suffix. An element without a path is a further case name for the
    file that preceded it.
    """
    references: list[dict[str, Any]] = []
    for piece in (part.strip() for part in evidence.split(",")):
        if not piece:
            continue
        if "/" not in piece:
            if not references:
                raise CatalogError(
                    f"panel feature {feature}: case {piece!r} names no file"
                )
            references[-1]["cases"].append(piece)
            continue

        path, _, case = piece.partition(":")
        relative = path if path.startswith(REPOSITORY_ROOTS) else str(
            (panel / path).relative_to(root)
        )
        if not (root / relative).exists():
            raise CatalogError(
                f"panel feature {feature}: evidence path {relative} does not exist"
            )
        reference: dict[str, Any] = {
            "path": relative,
            "cases": [case] if case else [],
            "bundle": None,
        }
        if relative.startswith("bundles/"):
            identifier = relative.split("/")[1]
            if identifier not in known:
                raise CatalogError(
                    f"panel feature {feature}: evidence names unknown bundle {identifier}"
                )
            reference["bundle"] = identifier
        references.append(reference)

    if not references:
        raise CatalogError(f"panel feature {feature}: no evidence is recorded")
    return references


FEATURE_STATE_LABEL = {
    "verified-working": "Verified working",
    "verified-working-with-guard": "Verified working with a guard",
    "patched": "Fixed by a bundle",
    "staged": "Staged",
    "unsupported": "Unsupported",
    "known-broken": "Known broken",
}


def feature_state_label(state: str) -> str:
    return FEATURE_STATE_LABEL.get(state, re.sub(r"[-_]+", " ", state).capitalize())
