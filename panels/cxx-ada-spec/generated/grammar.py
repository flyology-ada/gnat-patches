#!/usr/bin/env python3
"""Generate deterministic multi-feature C++ translation units.

Unlike the isolated catalog and pairwise covering array, each grammar case
contains several independently generated declarations.  The grammar stays in
the panel's currently representable subset, so every generated Ada unit must
compile.  A fixed seed makes failures reproducible and reviewable.
"""

from __future__ import annotations

import argparse
import pathlib
import random
import sys
import tempfile

sys.dont_write_bytecode = True

from pairwise import classify


CASE_COUNT = 32
SEED = 0xCADA2026


def payload(index: int, kind: str) -> tuple[str, str]:
    name = f"Payload_{index}"
    declaration = {
        "record": f"struct {name} {{ int integer_value; double real_value; }};",
        "enum": f"enum {name} : unsigned {{ {name}_Zero, {name}_One }};",
        "union": f"union {name} {{ int integer_value; double real_value; }};",
    }[kind]
    return name, declaration


def qualify(name: str, form: str) -> str:
    return {
        "value": name,
        "pointer": f"{name} *",
        "const_pointer": f"const {name} *",
        "lvalue_reference": f"{name} &",
    }[form]


def fragment(rng: random.Random, index: int) -> str:
    kind = rng.choice(("record", "enum", "union"))
    carrier = rng.choice(("alias", "field", "parameter", "result"))
    form = rng.choice(("value", "pointer", "const_pointer", "lvalue_reference"))
    scoped = rng.choice((False, True))
    name, declaration = payload(index, kind)
    if scoped:
        namespace = f"scope_{index}"
        declaration = f"namespace {namespace} {{ {declaration} }}"
        reference = f"{namespace}::{name}"
    else:
        reference = name
    type_name = qualify(reference, form)
    use = {
        "alias": f"using Alias_{index} = {type_name};",
        "field": f"struct Carrier_{index} {{ {type_name} item; }};",
        "parameter": f"void consume_{index} ({type_name} value);",
        "result": f"{type_name} produce_{index} ();",
    }[carrier]
    return declaration + "\n" + use


def source_for(case_number: int) -> str:
    rng = random.Random(SEED + case_number)
    fragments = [fragment(rng, case_number * 10 + offset)
                 for offset in range(rng.randint(3, 7))]
    if case_number % 4 == 0:
        fragments.append(
            f"struct Base_{case_number} {{ virtual int value (); }};\n"
            f"struct Derived_{case_number} : Base_{case_number} "
            f"{{ int value () override; }};"
        )
    if case_number % 5 == 0:
        fragments.append(
            f"int overloaded_{case_number} (int);\n"
            f"int overloaded_{case_number} (double);"
        )
    return "\n\n".join(fragments) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("toolchain", type=pathlib.Path)
    parser.add_argument("version")
    args = parser.parse_args()

    toolchain = args.toolchain.resolve()
    gxx = toolchain / "bin" / "g++"
    gnatmake = toolchain / "bin" / "gnatmake"
    failures = 0
    with tempfile.TemporaryDirectory(prefix="gnat-cxx-ada-grammar-") as temp:
        root = pathlib.Path(temp)
        for number in range(CASE_COUNT):
            identifier = f"grammar_{number:02d}"
            directory = root / identifier
            directory.mkdir()
            dump = "-fdump-ada-spec-slim" if number % 2 else "-fdump-ada-spec"
            result, diagnostic = classify(
                gxx, gnatmake, directory, identifier, source_for(number),
                options=("-std=gnu++20",), dump_option=dump,
            )
            if result != "pass":
                failures += 1
                print(f"FAIL {identifier}: expected pass, got {result}")
                if diagnostic:
                    print("  " + diagnostic.splitlines()[0])
            else:
                mode = "slim" if dump.endswith("-slim") else "full"
                print(f"PASS {identifier}: {mode}")

    print(
        f"deterministic grammar survey: {CASE_COUNT} cases, "
        f"{failures} unexpected (seed {SEED}, GCC {args.version})"
    )
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
