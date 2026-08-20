#!/usr/bin/env python3
"""Generate the gnat-patches website and JSON catalog.

The site is written entirely from the repository's manifests, patches, tests,
and READMEs. Generation is fail-closed: recorded checksums are recomputed,
cross-references between patchsets and bundles are resolved, and publication
state is read from the GitHub Releases API so an installation command is only
ever shown for a compiler that exists.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))

from sitegen import diffs, model, render  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def write_page(path: Path, markup: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(markup, encoding="utf-8")


def shared_fields(catalog: dict[str, Any]) -> dict[str, Any]:
    return {
        key: catalog[key]
        for key in (
            "schema_version",
            "generated_at",
            "canonical_url",
            "repository_url",
            "publication_checked",
            "latest_patchset",
            "latest_published_patchset",
        )
    }


def generate(root: Path, output: Path, *, offline: bool) -> dict[str, Any]:
    releases = model.fetch_releases(offline=offline)
    catalog = model.load_catalog(root, releases=releases)
    panels = model.load_panels(root, catalog["bundles"])
    catalog["panels"] = panels

    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)

    shared = shared_fields(catalog)
    write_json(output / "patches.json", catalog)

    write_page(output / "index.html", render.render_home(catalog, panels))
    write_page(output / "patchsets" / "index.html", render.render_patchset_index(catalog))

    for patchset in catalog["patchsets"]:
        version = patchset["version"]
        write_page(
            output / "patchsets" / version / "index.html",
            render.render_patchset(catalog, patchset, catalog["bundles"]),
        )
        write_json(
            output / "patchsets" / f"{version}.json", {**shared, "patchset": patchset}
        )

    bundles_intro = render.markdown_html(
        (root / "bundles" / "README.md").read_text(encoding="utf-8"),
        source_path="bundles/README.md",
        prefix="../",
        embedded=True,
    )
    write_page(output / "bundles" / "index.html", render.render_bundle_index(catalog, bundles_intro))

    for bundle in catalog["bundles"]:
        write_bundle(root, output, catalog, bundle, shared)

    staged = [bundle for bundle in catalog["bundles"] if bundle["status"] == "staged"]
    write_page(output / "unreleased" / "index.html", render.render_unreleased(catalog, staged))

    write_page(output / "panels" / "index.html", render.render_panel_index(panels))
    for panel in panels:
        readme = render.markdown_html(
            panel["readme"],
            source_path=panel["readme_path"],
            prefix="../../",
            embedded=True,
        )
        write_page(
            output / "panels" / panel["id"] / "index.html",
            render.render_panel(panel, readme),
        )
        write_json(output / "panels" / f"{panel['id']}.json", {**shared, "panel": panel})

    write_assets(root, output)
    write_text_resources(output, catalog)
    return catalog


def write_bundle(
    root: Path,
    output: Path,
    catalog: dict[str, Any],
    bundle: dict[str, Any],
    shared: dict[str, Any],
) -> None:
    identifier = bundle["id"]
    directory = output / "bundles" / identifier

    patches: dict[str, diffs.Patch] = {}
    for variant in bundle["variants"]:
        source = (root / variant["patch"]).read_text(encoding="utf-8")
        try:
            patches[variant["id"]] = diffs.parse(source)
        except diffs.DiffError as error:
            raise model.CatalogError(f"{identifier}: {variant['patch']}: {error}") from error
        target = directory / "patches" / Path(variant["patch"]).name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(source, encoding="utf-8")

    tests = {}
    for path in bundle["tests"]:
        source = (root / path).read_text(encoding="utf-8")
        tests[path] = source
        target = directory / "tests" / Path(path).name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(source, encoding="utf-8")

    runner = None
    runner_path = bundle.get("repository_test_runner")
    if runner_path:
        source = (root / runner_path).read_text(encoding="utf-8")
        runner = (runner_path, source)
        (directory / Path(runner_path).name).write_text(source, encoding="utf-8")

    readme = render.markdown_html(
        (root / bundle["readme_path"]).read_text(encoding="utf-8"),
        source_path=bundle["readme_path"],
        prefix="../../",
        embedded=True,
    )
    write_page(
        directory / "index.html",
        render.render_bundle(
            catalog, bundle, readme=readme, patches=patches, tests=tests, runner=runner
        ),
    )
    write_json(
        output / "bundles" / f"{identifier}.json",
        {
            **shared,
            "bundle": {
                **bundle,
                "patch_statistics": {
                    variant: {
                        "files": len(patch.files),
                        "additions": patch.additions,
                        "deletions": patch.deletions,
                    }
                    for variant, patch in patches.items()
                },
            },
        },
    )


def write_assets(root: Path, output: Path) -> None:
    website = root / "website"
    styles = output / "assets" / "styles"
    styles.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(website / "assets" / "styles" / "patches.css", styles / "patches.css")
    for name in ("flyology-logo.svg", "flyology-mark.svg"):
        shutil.copyfile(website / "brand" / name, output / name)


def write_text_resources(output: Path, catalog: dict[str, Any]) -> None:
    (output / ".nojekyll").write_text("", encoding="utf-8")
    (output / "llms.txt").write_text(render_llms(catalog), encoding="utf-8")


def render_llms(catalog: dict[str, Any]) -> str:
    canonical = catalog["canonical_url"]
    bundles = "\n".join(
        f"- [{bundle['title']}]({canonical}bundles/{bundle['id']}/): {bundle['problem']}"
        f" Status: {bundle['status']}."
        for bundle in catalog["bundles"]
    )
    panel_links = "\n".join(
        f"- [{panel['title']}]({canonical}panels/{panel['id']}/): {panel['summary']}"
        for panel in catalog.get("panels", [])
    )
    patchsets = "\n".join(
        f"- [Patchset {patchset['version']}]({canonical}patchsets/{patchset['version']}/): "
        + ", ".join(
            f"GCC {target['gcc_major']} pinned to {target['source_version']}"
            for target in patchset["targets"]
        )
        + "."
        for patchset in catalog["patchsets"]
    )
    return f"""# GNAT patches

> Independent GCC and GNAT patch bundles, each with an executable regression, validated against pinned GCC source releases and published as patchsets.

A bundle is one compiler problem: a patch with version variants, an executable
regression run at -O0 and -O2 before and after the patch, and an explanation.
A patchset selects the bundles that apply to one pinned GCC source release per
supported major. A bundle a patchset holds back is staged, and no patched run
makes a claim about it. A release that does not have a defect is not patched
for it; the bundle's regression runs there as a control instead.

## Catalog

- [Home]({canonical}): The latest patchset and what each compiler receives.
- [Patchsets]({canonical}patchsets/): Every patchset and the GCC releases it covers.
- [Bundles]({canonical}bundles/): Every bundle, accepted and staged.
- [Unreleased]({canonical}unreleased/): Bundles held out of the published patchset.
- [Panels]({canonical}panels/): State and evidence for every mapping feature the repository exercises.
- [Catalog JSON]({canonical}patches.json): Complete machine-readable catalog.

## Patchsets

{patchsets}

## Bundles

{bundles}

## Panels

{panel_links}

## JSON

Every resource is generated from the repository's TOML manifests and is served
with Access-Control-Allow-Origin: *. `{canonical}patchsets/<version>.json` is one
patchset, `{canonical}bundles/<id>.json` is one bundle, and
`{canonical}panels/<id>.json` is one coverage panel.

A patchset target carries `bundles`, `control_tests`, and `staged_bundles`. A
bundle in `bundles` is patched on that compiler. A bundle in `control_tests` is
not patched there: that release does not have the defect, and the bundle's
regression runs against the unpatched compiler as a control. A bundle in
`staged_bundles` is held back, and no patched run makes a claim about it. A
bundle's `roles` field is that relationship inverted: `roles[patchset][major]`
gives the role and, when the role is patched, the patch variant that applies.

`release` is null when no toolchain release carries that patchset for that
compiler; otherwise `alire_crate` and `alire_version` give the exact Alire
selection and `state` is `published` or `prerelease`. `publication_checked`
reports whether release facts were read at build time; when it is false the
site makes no claim about what is installable.

## Optional

- [Source repository]({catalog['repository_url']}): Manifests, patches, tests, and the site generator.
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT)
    parser.add_argument("--output", type=Path, default=ROOT / "build" / "site")
    parser.add_argument(
        "--offline",
        action="store_true",
        help="skip the release query and publish no installation commands",
    )
    arguments = parser.parse_args()

    try:
        catalog = generate(
            arguments.source.resolve(), arguments.output.resolve(), offline=arguments.offline
        )
    except (model.CatalogError, OSError) as error:
        print(f"site generation failed: {error}", file=sys.stderr)
        return 1

    print(
        f"Generated {len(catalog['bundles'])} bundles and "
        f"{len(catalog['patchsets'])} patchsets at {arguments.output}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
