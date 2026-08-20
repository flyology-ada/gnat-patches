#!/usr/bin/env python3
"""Generate a stable pairwise C++ type-reference survey and compile its Ada.

The cases cover every pair among payload kind, reference carrier, C++ scope,
and qualifier.  Each case is isolated so one invalid dump cannot mask another.
Expected non-passing results are recorded by case and GCC major in
expectations.toml; any unclassified result is a panel failure.
"""

from __future__ import annotations

import argparse
import itertools
import pathlib
import re
import subprocess
import tempfile
import tomllib


AXES = {
    "payload": ("record", "enum", "union"),
    "carrier": ("alias", "field", "parameter", "result"),
    "scope": ("global", "namespace"),
    "qualifier": ("value", "pointer", "const_pointer", "lvalue_reference"),
    "dump": ("slim", "full"),
}


def covered_pairs(case: tuple[str, ...]) -> set[tuple[int, str, int, str]]:
    return {
        (left, case[left], right, case[right])
        for left in range(len(case))
        for right in range(left + 1, len(case))
    }


def pairwise_cases() -> list[tuple[str, ...]]:
    combinations = list(itertools.product(*AXES.values()))
    uncovered = set().union(*(covered_pairs(case) for case in combinations))
    selected: list[tuple[str, ...]] = []
    while uncovered:
        best = max(
            combinations,
            key=lambda case: (len(covered_pairs(case) & uncovered), tuple(case)),
        )
        selected.append(best)
        uncovered -= covered_pairs(best)
        combinations.remove(best)
    return sorted(selected)


def case_id(case: tuple[str, ...]) -> str:
    short = {
        "record": "rec",
        "enum": "enum",
        "union": "union",
        "alias": "alias",
        "field": "field",
        "parameter": "param",
        "result": "result",
        "global": "global",
        "namespace": "ns",
        "value": "value",
        "pointer": "ptr",
        "const_pointer": "cptr",
        "lvalue_reference": "lref",
        "slim": "slim",
        "full": "full",
    }
    return "pw_" + "_".join(short[value] for value in case)


def source_for(case: tuple[str, ...]) -> str:
    payload, carrier, scope, qualifier = case[:4]
    declarations = {
        "record": "struct Payload { int value; };",
        "enum": "enum Payload { Payload_Zero, Payload_One };",
        "union": "union Payload { int integer_value; double real_value; };",
    }
    if scope == "namespace":
        declaration = f"namespace survey {{ {declarations[payload]} }}"
        base = "survey::Payload"
    else:
        declaration = declarations[payload]
        base = "Payload"

    qualified = {
        "value": base,
        "pointer": f"{base} *",
        "const_pointer": f"const {base} *",
        "lvalue_reference": f"{base} &",
    }[qualifier]
    use = {
        "alias": f"using External = {qualified};",
        "field": f"struct Carrier {{ {qualified} item; }};",
        "parameter": f"void consume ({qualified} value);",
        "result": f"{qualified} produce ();",
    }[carrier]
    return f"{declaration}\n\n{use}\n"


# A staged compiler carries the patchset plus the staged bundles, so its
# expectations start from the patched ones and then override.
STATE_CHAIN = {
    "unpatched": ("unpatched",),
    "patched": ("patched",),
    "staged": ("patched", "staged"),
}


def state_layers(state: str | None) -> tuple[str, ...]:
    if not state:
        return ()
    if state not in STATE_CHAIN:
        raise ValueError(f"unknown panel state: {state}")
    return STATE_CHAIN[state]


def expectation_table(
    path: pathlib.Path, major: str, state: str | None = None
) -> dict[str, str]:
    with path.open("rb") as stream:
        data = tomllib.load(stream)
    expected = {case: result for case, result in data.get("all", {}).items()}
    expected.update(data.get(f"gcc_{major}", {}))
    for layer in state_layers(state):
        expected.update(data.get(layer, {}))
        expected.update(data.get(f"{layer}_gcc_{major}", {}))
    return expected


def run(command: list[str], cwd: pathlib.Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, text=True, capture_output=True)


def classify(gxx: pathlib.Path, gnatmake: pathlib.Path, directory: pathlib.Path,
             identifier: str, source: str, *, options: tuple[str, ...] = (),
             must_contain: tuple[str, ...] = (),
             dump_option: str = "-fdump-ada-spec-slim") -> tuple[str, str]:
    cpp = directory / f"{identifier}.C"
    cpp.write_text(source)
    compiled = run(
        [str(gxx), "-c", *options, dump_option, cpp.name], directory
    )
    if compiled.returncode:
        if "internal compiler error" in compiled.stderr.lower():
            return "cxx-ice", compiled.stderr
        return "cxx-reject", compiled.stderr

    spec = directory / f"{identifier}_c.ads"
    if not spec.exists():
        return "no-spec", compiled.stdout + compiled.stderr

    generated = spec.read_text()
    missing = [pattern for pattern in must_contain
               if not re.search(pattern, generated, re.MULTILINE)]
    if missing:
        return "spec-mismatch", f"missing pattern: {missing[0]}"

    consumer_name = f"consume_{identifier}"
    consumer = directory / f"{consumer_name}.adb"
    consumer.write_text(
        f"with {identifier}_c;\n\n"
        f"procedure {consumer_name.title().replace('_', '_')} is\n"
        "begin\n"
        "   null;\n"
        f"end {consumer_name.title().replace('_', '_')};\n"
    )
    ada = run([str(gnatmake), "-q", "-f", "-c", consumer.name], directory)
    if ada.returncode:
        diagnostic = re.sub(r"^.*?:\d+:\d+: ", "", ada.stderr, flags=re.MULTILINE)
        return "ada-reject", diagnostic
    return "pass", ""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("toolchain", type=pathlib.Path)
    parser.add_argument("version")
    parser.add_argument("--discover", action="store_true")
    args = parser.parse_args()

    major = args.version.split(".", 1)[0]
    gxx = args.toolchain.resolve() / "bin" / "g++"
    gnatmake = args.toolchain.resolve() / "bin" / "gnatmake"
    for executable in (gxx, gnatmake):
        if not executable.is_file():
            parser.error(f"missing executable: {executable}")

    expectations = expectation_table(
        pathlib.Path(__file__).with_name("expectations.toml"), major
    )
    failures = 0
    cases = pairwise_cases()
    with tempfile.TemporaryDirectory(prefix="gnat-cxx-ada-pairwise-") as temp:
        root = pathlib.Path(temp)
        for case in cases:
            identifier = case_id(case)
            directory = root / identifier
            directory.mkdir()
            result, diagnostic = classify(
                gxx, gnatmake, directory, identifier, source_for(case),
                dump_option=f"-fdump-ada-spec{'-slim' if case[4] == 'slim' else ''}",
            )
            if args.discover:
                print(f'{identifier} = "{result}"')
                if diagnostic:
                    print("  " + diagnostic.splitlines()[0])
                continue
            expected = expectations.get(identifier, "pass")
            if result != expected:
                failures += 1
                print(f"FAIL {identifier}: expected {expected}, got {result}")
                if diagnostic:
                    print("  " + diagnostic.splitlines()[0])
            else:
                print(f"PASS {identifier}: {result}")

    print(
        f"pairwise C++ Ada survey: {len(cases)} cases, "
        f"{failures} unexpected (GCC {args.version})"
    )
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
