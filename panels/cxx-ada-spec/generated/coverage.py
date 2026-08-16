#!/usr/bin/env python3
"""Validate and summarize the C++ Ada panel's declared coverage."""

from __future__ import annotations

import pathlib
import re
import sys
import tomllib

sys.dont_write_bytecode = True

from catalog import CASES
from grammar import CASE_COUNT, SEED
from pairwise import AXES, expectation_table, pairwise_cases


ROOT = pathlib.Path(__file__).resolve().parents[3]
PANEL = ROOT / "panels" / "cxx-ada-spec"


def accepted_cxx_bundles() -> dict[str, tuple[pathlib.Path, dict]]:
    """Return every accepted C++ Ada defect bundle by manifest identity."""
    result: dict[str, tuple[pathlib.Path, dict]] = {}
    for path in sorted((ROOT / "bundles").glob("cxx-ada-*/manifest.toml")):
        with path.open("rb") as stream:
            manifest = tomllib.load(stream)
        bundle_id = manifest.get("id")
        if manifest.get("status") == "accepted":
            if not bundle_id or bundle_id in result:
                raise SystemExit(f"error: invalid C++ Ada bundle identity in {path}")
            result[bundle_id] = (path.parent, manifest)
    return result


def validate_confirmed_bundles(coverage: dict, matrix: dict) -> int:
    """Prove that every confirmed mapper defect keeps its full evidence chain."""
    bundles = accepted_cxx_bundles()
    expected_suites = {f"bundles/{bundle_id}" for bundle_id in bundles}
    declared_suites = {
        suite for suite in coverage["runtime"]["suites"]
        if suite.startswith("bundles/cxx-ada-")
    }
    if declared_suites != expected_suites:
        missing = sorted(expected_suites - declared_suites)
        extra = sorted(declared_suites - expected_suites)
        if missing:
            print("error: confirmed bundles absent from runtime coverage: " +
                  ", ".join(missing))
        if extra:
            print("error: unknown C++ Ada runtime bundles: " + ", ".join(extra))
        raise SystemExit(1)

    driver = (PANEL / "run-panel.sh").read_text()
    panel_readme = (PANEL / "README.md").read_text()
    evidence = "\n".join(
        feature.get("evidence", "") for feature in matrix["features"]
    )
    fence_pattern = re.compile(
        r"^```([^\n]*)\n(.*?)^```$", re.MULTILINE | re.DOTALL
    )
    before_words = re.compile(
        r"unpatched|before (?:the )?patch|current|stock GCC|broken|wrong|"
        r"loses|omits|too small|does not exist",
        re.IGNORECASE,
    )
    after_words = re.compile(
        r"corrected|after (?:the )?patch|with the patch|patched|should|fix",
        re.IGNORECASE,
    )

    for bundle_id, (directory, manifest) in bundles.items():
        runner_rel = manifest["repository_test_runner"]
        runner = (ROOT / runner_rel).read_text()
        if runner_rel not in driver:
            raise SystemExit(
                f"error: confirmed bundle {bundle_id} is absent from run-panel.sh"
            )
        if not re.search(r"for optimization in 0 2; do", runner):
            raise SystemExit(
                f"error: confirmed bundle {bundle_id} does not run at -O0 and -O2"
            )
        if "unpatched" not in runner or "patched" not in runner:
            raise SystemExit(
                f"error: confirmed bundle {bundle_id} lacks before/after execution"
            )

        bundle_ref = f"bundles/{bundle_id}"
        if bundle_ref not in evidence:
            raise SystemExit(
                f"error: confirmed bundle {bundle_id} has no matrix evidence"
            )
        if f"{bundle_ref}/README.md" not in panel_readme:
            raise SystemExit(
                f"error: confirmed bundle {bundle_id} is absent from the "
                "panel defect ledger"
            )

        readme_path = directory / "README.md"
        if not readme_path.is_file():
            raise SystemExit(f"error: confirmed bundle {bundle_id} has no README")
        readme = readme_path.read_text()
        blocks = [(match.group(1), match.group(2))
                  for match in fence_pattern.finditer(readme)]
        languages = [language for language, _ in blocks]
        try:
            cpp_index = languages.index("c++")
            first_ada = languages.index("ada", cpp_index + 1)
            second_ada = languages.index("ada", first_ada + 1)
        except ValueError as exc:
            raise SystemExit(
                f"error: {bundle_id} README must show offending C++, "
                "unpatched Ada, and corrected Ada inline"
            ) from exc
        if any(not blocks[index][1].strip()
               for index in (cpp_index, first_ada, second_ada)):
            raise SystemExit(
                f"error: {bundle_id} README contains an empty required example"
            )
        if not before_words.search(readme) or not after_words.search(readme):
            raise SystemExit(
                f"error: {bundle_id} README does not identify both current "
                "and corrected output"
            )

    return len(bundles)


def main() -> int:
    with (PANEL / "coverage.toml").open("rb") as stream:
        coverage = tomllib.load(stream)
    with (PANEL / "matrix.toml").open("rb") as stream:
        matrix = tomllib.load(stream)

    confirmed_count = validate_confirmed_bundles(coverage, matrix)

    driver = (PANEL / "run-panel.sh").read_text()
    for suite in coverage["runtime"]["suites"]:
        directory = ROOT / suite
        runner = directory / "run-test.sh"
        if not directory.is_dir() or not runner.is_file():
            raise SystemExit(f"error: runtime suite {suite} has no run-test.sh")
        runner_rel = runner.relative_to(ROOT).as_posix()
        if runner_rel not in driver:
            raise SystemExit(
                f"error: runtime suite {suite} is absent from run-panel.sh"
            )

    assigned: dict[str, str] = {}
    for group in coverage["groups"]:
        for case in group["cases"]:
            if case in assigned:
                raise SystemExit(
                    f"error: atomic case {case} is in both {assigned[case]} and {group['id']}"
                )
            assigned[case] = group["id"]

    missing = sorted(set(CASES) - set(assigned))
    unknown = sorted(set(assigned) - set(CASES))
    if missing or unknown:
        if missing:
            print("error: unclassified atomic cases: " + ", ".join(missing))
        if unknown:
            print("error: unknown classified cases: " + ", ".join(unknown))
        return 1

    mapped_unknown = sorted(
        {
            case
            for cases in coverage["mapper_tree_codes"].values()
            for case in cases
        }
        - set(CASES)
    )
    if mapped_unknown:
        print("error: mapper tree-code map names unknown cases: " +
              ", ".join(mapped_unknown))
        return 1

    expectations_path = PANEL / "generated" / "catalog-expectations.toml"
    print(f"atomic catalog: {len(CASES)} cases in {len(coverage['groups'])} groups")
    for state in ("unpatched", "patched"):
        print(f"  {state} expectations:")
        for major in ("13", "14", "15", "16"):
            expected = expectation_table(expectations_path, major, state)
            nonpassing = sum(
                expected.get(case, "pass") != "pass" for case in CASES
            )
            print(
                f"    GCC {major}: {len(CASES) - nonpassing} compile, "
                f"{nonpassing} classified non-passing"
            )

    combinations = pairwise_cases()
    pair_count = sum(
        len(left) * len(right)
        for index, left in enumerate(AXES.values())
        for right in list(AXES.values())[index + 1:]
    )
    declared = matrix["coverage"]
    actual_counts = {
        "atomic_cases": len(CASES),
        "pairwise_cases": len(combinations),
        "pairwise_value_pairs": pair_count,
        "grammar_cases": CASE_COUNT,
        "runtime_suites": len(coverage["runtime"]["suites"]),
    }
    for key, actual in actual_counts.items():
        if declared.get(key) != actual:
            print(
                f"error: matrix coverage {key}={declared.get(key)!r}, "
                f"computed {actual}"
            )
            return 1
    print(
        f"pairwise survey: {len(combinations)} generated cases cover "
        f"all {pair_count} value pairs across {len(AXES)} axes"
    )
    print(f"deterministic grammar survey: {CASE_COUNT} cases, seed {SEED}")
    print(f"runtime suites: {len(coverage['runtime']['suites'])}")
    print(
        f"confirmed C++ defects: {confirmed_count} bundles with inline "
        "before/after evidence"
    )
    print(f"mapper tree-code families: {len(coverage['mapper_tree_codes'])}")
    print(f"explicit remaining limits: {len(coverage['limits']['not_yet_covered'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
