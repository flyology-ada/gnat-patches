#!/usr/bin/env python3
"""Validate and summarize the C++ Ada panel's declared coverage."""

from __future__ import annotations

import pathlib
import sys
import tomllib

sys.dont_write_bytecode = True

from catalog import CASES
from grammar import CASE_COUNT, SEED
from pairwise import AXES, expectation_table, pairwise_cases


ROOT = pathlib.Path(__file__).resolve().parents[3]
PANEL = ROOT / "panels" / "cxx-ada-spec"


def main() -> int:
    with (PANEL / "coverage.toml").open("rb") as stream:
        coverage = tomllib.load(stream)
    with (PANEL / "matrix.toml").open("rb") as stream:
        matrix = tomllib.load(stream)

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
    for major in ("13", "14", "15", "16"):
        expected = expectation_table(expectations_path, major)
        nonpassing = sum(expected.get(case, "pass") != "pass" for case in CASES)
        print(
            f"  GCC {major}: {len(CASES) - nonpassing} compile, "
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
    print(f"mapper tree-code families: {len(coverage['mapper_tree_codes'])}")
    print(f"explicit remaining limits: {len(coverage['limits']['not_yet_covered'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
