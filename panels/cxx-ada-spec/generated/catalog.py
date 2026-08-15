#!/usr/bin/env python3
"""Run isolated mapper probes for atomic C++ language and ABI features."""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
import tempfile
import tomllib

sys.dont_write_bytecode = True

from pairwise import classify, expectation_table


# Each entry is (C++ source, required Ada-spec regexes).  Compilation of the
# generated Ada is always required unless the expectation table classifies a
# deliberate boundary or known defect.
CASES: dict[str, tuple[str, tuple[str, ...]]] = {
    "fundamental_scalars": (
        """\
bool f_bool(bool v); char f_char(char v); signed char f_schar(signed char v);
unsigned char f_uchar(unsigned char v); short f_short(short v);
unsigned short f_ushort(unsigned short v); int f_int(int v);
unsigned int f_uint(unsigned int v); long f_long(long v);
unsigned long f_ulong(unsigned long v); long long f_ll(long long v);
unsigned long long f_ull(unsigned long long v); float f_float(float v);
double f_double(double v); long double f_long_double(long double v);
""",
        (r"function f_bool", r"function f_long_double"),
    ),
    "extended_characters": (
        "wchar_t wide(wchar_t); char16_t c16(char16_t); "
        "char32_t c32(char32_t); char8_t c8(char8_t);\n",
        (r"function wide", r"function c16", r"function c32", r"function c8"),
    ),
    "complex_and_vector": (
        "typedef __complex__ double Complex; "
        "typedef int Vector4 __attribute__((vector_size(16))); "
        "Complex complex_value(Complex); Vector4 vector_value(Vector4);\n",
        (r"complex_value", r"vector_value"),
    ),
    "integer_128": (
        "__int128 signed_128(__int128); "
        "unsigned __int128 unsigned_128(unsigned __int128);\n",
        (r"signed_128", r"unsigned_128"),
    ),
    "nullptr_type": (
        "decltype(nullptr) null_value();\n",
        (r"function null_value",),
    ),
    "multidimensional_arrays": (
        "struct Matrix { int values[2][3]; };\n",
        (r"type Matrix", r"values"),
    ),
    "incomplete_forward_declaration": (
        "struct Opaque; Opaque* create_opaque(); void consume_opaque(Opaque*);\n",
        (r"Opaque", r"create_opaque", r"consume_opaque"),
    ),
    "multiple_indirection": (
        "struct Item { int value; }; Item** find_item(Item*** source);\n",
        (r"type Item", r"find_item"),
    ),
    "flexible_array": (
        "struct Packet { unsigned size; unsigned char data[]; };\n",
        (r"type Packet", r"data"),
    ),
    "function_pointer": (
        "using Callback = int (*)(double); int call(Callback, double);\n",
        (r"access function", r"function call"),
    ),
    "data_member_pointer": (
        "struct Object { int field; }; using Member = int Object::*;\n",
        (r"type Object",),
    ),
    "member_function_pointer": (
        "struct Object { int method(double) const; }; "
        "using Method = int (Object::*)(double) const;\n",
        (r"type Object", r"function method"),
    ),
    "scoped_enums": (
        "enum Plain : unsigned char { P0, P1 }; "
        "enum class Scoped : unsigned short { S0, S1 };\n",
        (r"type Plain", r"type Scoped"),
    ),
    "bit_fields": (
        "struct Bits { unsigned first : 3; signed second : 5; bool flag : 1; };\n",
        (r"type Bits", r"first", r"second", r"flag"),
    ),
    "packing_alignment": (
        "struct __attribute__((packed)) Packed { char c; int i; }; "
        "struct alignas(32) Aligned { int value; };\n",
        (r"type Packed", r"type Aligned"),
    ),
    "anonymous_aggregates": (
        "struct Outer { union { int integer_value; double real_value; }; "
        "struct { short x; short y; }; };\n",
        (r"type Outer",),
    ),
    "free_overloads": (
        "int convert(int); int convert(double); int convert(int, int);\n",
        (r"function convert",),
    ),
    "method_cv_overloads": (
        "struct Accessor { int get(); int get() const; int get() volatile; };\n",
        (r"type Accessor", r"function get"),
    ),
    "ref_qualified_methods": (
        "struct RefQualified { int get() &; int get() &&; int view() const &; };\n",
        (r"type RefQualified", r"function get", r"function view"),
    ),
    "free_rvalue_references": (
        "struct Value { int field; }; void consume(Value&&); Value&& forward(Value&&);\n",
        (r"type Value", r"consume", r"forward"),
    ),
    "noexcept_default_arguments": (
        "int calculate(int value = 3) noexcept;\n",
        (r"function calculate",),
    ),
    "variadic_function": (
        "int sum(unsigned count, ...);\n",
        (r"function sum",),
    ),
    "operators": (
        "struct Number { Number operator+(const Number&) const; "
        "Number& operator+=(const Number&); int operator[](unsigned) const; "
        "bool operator==(const Number&) const; };\n",
        (r"type Number",),
    ),
    "conversion_operators": (
        "struct Convertible { explicit operator bool() const; operator int() const; };\n",
        (r"type Convertible",),
    ),
    "deleted_defaulted": (
        "struct Managed { Managed() = default; Managed(const Managed&) = delete; "
        "Managed& operator=(const Managed&) = default; };\n",
        (r"type Managed",),
    ),
    "friend_function": (
        "struct Friendly { friend int inspect(const Friendly&); int value; };\n",
        (r"type Friendly", r"inspect"),
    ),
    "copy_move_constructors": (
        "struct Value { Value(); Value(const Value&); Value(Value&&); "
        "Value& operator=(const Value&); Value& operator=(Value&&); };\n",
        (r"type Value", r"CPP_Constructor"),
    ),
    "function_template_instance": (
        "template <class T> T identity(T value) { return value; } "
        "template int identity<int>(int);\n",
        (),
    ),
    "non_type_template": (
        "template <class T, unsigned N> struct Buffer { T values[N]; }; "
        "template struct Buffer<int, 4>;\n",
        (r"package Buffer",),
    ),
    "partial_specialization": (
        "template <class T, bool B> struct Select; "
        "template <class T> struct Select<T, false> { T value; }; "
        "template struct Select<int, false>;\n",
        (r"package c_Select",),
    ),
    "full_specialization": (
        "template <class T> struct Box { T value; }; "
        "template <> struct Box<bool> { unsigned value; }; "
        "using BoolBox = Box<bool>;\n",
        (r"BoolBox",),
    ),
    "alias_template": (
        "template <class T> struct Box { T value; }; "
        "template <class T> using Alias = Box<T>; "
        "using IntAlias = Alias<int>;\n",
        (r"IntAlias",),
    ),
    "member_template": (
        "struct Factory { template <class T> T make(T value); int ordinary(); };\n",
        (r"type Factory", r"ordinary"),
    ),
    "nested_template": (
        "template <class T> struct Outer { template <class U> struct Inner { U value; }; }; "
        "template struct Outer<int>;\n",
        (r"package Outer",),
    ),
    "default_template_arguments": (
        "template <class T = int, unsigned N = 2> struct Defaults { T values[N]; }; "
        "template struct Defaults<>;\n",
        (r"package Defaults",),
    ),
    "template_template_parameter": (
        "template <class T> struct Box { T value; }; "
        "template <template <class> class C, class T> struct Wrapper { C<T> item; }; "
        "template struct Wrapper<Box, int>;\n",
        (r"package Wrapper",),
    ),
    "variable_template": (
        "template <class T> T variable = T(); template int variable<int>;\n",
        (),
    ),
    "constrained_template": (
        "template <class T> concept IntegralSized = sizeof(T) >= sizeof(int); "
        "template <IntegralSized T> struct Constrained { T value; }; "
        "template struct Constrained<int>;\n",
        (r"package Constrained",),
    ),
    "abstract_virtual_destructor": (
        "struct Abstract { virtual ~Abstract(); virtual int value() const = 0; };\n",
        (r"type c_Abstract", r"Delete_c_Abstract", r"function value"),
    ),
    "covariant_return": (
        "struct Base { virtual Base* clone() const; }; "
        "struct Derived : Base { Derived* clone() const override; };\n",
        (r"type Base", r"type Derived", r"function clone"),
    ),
    "final_override": (
        "struct BaseFinal { virtual int value(); }; "
        "struct Final final : BaseFinal { int value() final; };\n",
        (r"type BaseFinal", r"type Final", r"function value"),
    ),
    "empty_base": (
        "struct Empty {}; struct WithEmpty : Empty { int value; };\n",
        (r"type Empty", r"type WithEmpty"),
    ),
    "virtual_inheritance": (
        "struct Root { int value; }; struct Virtual : virtual Root { int extra; };\n",
        (r"type Root", r"type Virtual"),
    ),
    "diamond_inheritance": (
        "struct Root { virtual int value(); }; struct Left : virtual Root {}; "
        "struct Right : virtual Root {}; struct Diamond : Left, Right {};\n",
        (r"type Diamond",),
    ),
    "concrete_multiple_inheritance": (
        "struct Left { virtual int left(); int l; }; "
        "struct Right { virtual int right(); int r; }; "
        "struct Both : Left, Right { int both; };\n",
        (r"type Both",),
    ),
    "nonpublic_inheritance": (
        "struct PublicBase { int value; }; "
        "struct PrivateDerived : private PublicBase { int private_value; }; "
        "struct ProtectedDerived : protected PublicBase { int protected_value; };\n",
        (r"type PublicBase", r"type PrivateDerived", r"type ProtectedDerived"),
    ),
    "inline_namespace": (
        "namespace api { inline namespace v1 { struct Item { int value; }; } } "
        "api::Item consume(api::Item);\n",
        (r"type (?:api_v1_)?Item", r"function consume"),
    ),
    "nested_namespace": (
        "namespace first::second { struct Item { int value; }; } "
        "first::second::Item consume(first::second::Item);\n",
        (r"type (?:first_second_)?Item", r"function consume"),
    ),
    "anonymous_namespace": (
        "namespace { struct Hidden { int value; }; Hidden consume(Hidden); }\n",
        (r"type Hidden", r"function consume"),
    ),
    "casefold_collision": (
        "struct Item { int upper; }; struct ITEM { double lower; };\n",
        (r"type Item", r"type ITEM"),
    ),
    "ada_reserved_names": (
        "struct range { int delta; }; int digits(range value);\n",
        (r"range", r"delta", r"digits"),
    ),
    "nested_class": (
        "struct Outer { struct Inner { int value; }; Inner make(); };\n",
        (r"type Outer", r"type Inner", r"function make"),
    ),
    "namespace_alias": (
        "namespace original { struct Item { int value; }; } "
        "namespace alias = original; alias::Item consume(alias::Item);\n",
        (r"type (?:original_)?Item", r"function consume"),
    ),
    "typedef_and_using": (
        "struct Original { int value; }; typedef Original OldAlias; "
        "using NewAlias = Original;\n",
        (r"OldAlias", r"NewAlias"),
    ),
    "globals_constants": (
        "extern int global_value; extern const unsigned constant_value; "
        "constexpr int compile_value = 4; constexpr double real_constant = 1.25;\n",
        (r"global_value", r"constant_value", r"compile_value", r"real_constant"),
    ),
    "volatile_global": (
        "extern volatile int volatile_value; extern const volatile long cv_value;\n",
        (r"volatile_value", r"cv_value"),
    ),
    "string_constant_array": (
        "const char message[6] = \"hello\";\n",
        (r"message",),
    ),
    "anonymous_enum": (
        "enum { Anonymous_Zero, Anonymous_One }; int use_anonymous(int);\n",
        (r"Anonymous_Zero", r"Anonymous_One"),
    ),
    "exception_throw": (
        "struct Failure { int code; }; int may_throw(bool fail) "
        "{ if (fail) throw Failure{7}; return 3; }\n",
        (r"type Failure", r"may_throw"),
    ),
    "constexpr_consteval": (
        "constexpr int square(int value) { return value * value; } "
        "consteval int immediate(int value) { return value + 1; } "
        "constexpr int answer = immediate(41);\n",
        (r"square", r"immediate", r"answer"),
    ),
    "thread_local_storage": (
        "extern thread_local int tls_value;\n",
        (r"tls_value",),
    ),
    "extern_c_linkage": (
        "extern \"C\" { struct C_Record { int value; }; int c_function(C_Record); }\n",
        (r"type C_Record", r"c_function"),
    ),
    "static_data_member": (
        "struct Counter { static int count; int value; };\n",
        (r"type Counter", r"count"),
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("toolchain", type=pathlib.Path)
    parser.add_argument("version")
    parser.add_argument("--discover", action="store_true")
    parser.add_argument("--case", choices=sorted(CASES))
    parser.add_argument("--show-spec", action="store_true")
    parser.add_argument("--state", choices=("unpatched", "patched"),
                        default="unpatched")
    args = parser.parse_args()

    major = args.version.split(".", 1)[0]
    toolchain = args.toolchain.resolve()
    gxx = toolchain / "bin" / "g++"
    gnatmake = toolchain / "bin" / "gnatmake"
    expectations = expectation_table(
        pathlib.Path(__file__).with_name("catalog-expectations.toml"),
        major,
        args.state,
    )
    with pathlib.Path(__file__).with_name("catalog-expectations.toml").open(
        "rb"
    ) as stream:
        expectation_data = tomllib.load(stream)
    diagnostics = dict(expectation_data.get("diagnostics", {}))
    diagnostics.update(expectation_data.get(f"diagnostics_gcc_{major}", {}))
    diagnostics.update(expectation_data.get(f"diagnostics_{args.state}", {}))
    diagnostics.update(
        expectation_data.get(f"diagnostics_{args.state}_gcc_{major}", {})
    )
    failures = 0
    with tempfile.TemporaryDirectory(prefix="gnat-cxx-ada-catalog-") as temp:
        root = pathlib.Path(temp)
        selected = CASES.items()
        if args.case:
            selected = ((args.case, CASES[args.case]),)
        for identifier, (source, patterns) in sorted(selected):
            directory = root / identifier
            directory.mkdir()
            result, diagnostic = classify(
                gxx, gnatmake, directory, identifier, source,
                options=("-std=gnu++20",), must_contain=patterns,
            )
            if args.show_spec:
                spec = directory / f"{identifier}_c.ads"
                if spec.exists():
                    print(spec.read_text())
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
            elif result != "pass" and identifier in diagnostics and not re.search(
                diagnostics[identifier], diagnostic, re.IGNORECASE
            ):
                failures += 1
                print(
                    f"FAIL {identifier}: {result} did not match diagnostic "
                    f"/{diagnostics[identifier]}/"
                )
                if diagnostic:
                    print("  " + diagnostic.splitlines()[0])
            else:
                print(f"PASS {identifier}: {result}")

    print(
        f"atomic C++ Ada catalog: {len(CASES)} cases, "
        f"{failures} unexpected (GCC {args.version})"
    )
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
