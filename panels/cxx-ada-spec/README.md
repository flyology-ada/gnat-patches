# C++ to Ada specification feature panel

This panel turns exploratory `g++ -fdump-ada-spec` observations into repeatable
evidence. It separates three outcomes that need different treatment:

- a supported mapping, which gets a positive end-to-end C++/Ada case;
- a mapper defect, which gets an independent patch bundle with an executable
  before/after regression;
- a C++ construct Ada cannot represent directly, which is documented as a
  facade boundary rather than disguised as a mapper bug.

`matrix.toml` records feature-level conclusions. `coverage.toml` assigns every
atomic probe to a feature group, lists the runtime oracles, and states the
remaining limits. `generated/coverage.py` fails if a catalog probe is omitted
or assigned twice.

The executable panel currently has four layers:

- 63 isolated atomic probes cover types and layout, pointers and functions,
  templates, inheritance, names and linkage, and runtime/storage declarations.
  Each probe runs in its own directory, so one malformed dump cannot mask a
  later feature. Required declarations are checked before the generated Ada is
  compiled. Versioned expectation files distinguish successful mappings from
  repeatable invalid Ada and omissions.
- 16 generated cases cover all 88 value pairs across payload kind, reference
  carrier, C++ scope, qualifier, and full/slim dump mode. This is pairwise
  interaction coverage, not a hand-selected sample.
- 32 fixed-seed grammar cases combine three to seven declarations per
  translation unit, with periodic inheritance and overload clusters. They
  exercise higher-order interactions in the currently representable subset and
  alternate full and slim dump modes.
- Twenty-nine runtime suites link C++ and Ada at `-O0` and `-O2`. They check scalar,
  enum, record, union, pointer, reference, and callback calling conventions;
  object size, alignment, and field offsets; ordinary, interface, and concrete
  secondary-base virtual dispatch, including recursively nested concrete bases;
  template qualification, record termination,
  nested types, explicit
  alignment, namespace and method identity—including enclosing-type,
  use-visible type/method, and subprogram-profile collisions—anonymous
  enumeration values, and
  `char8_t`, 128-bit integers, machine vectors, and opaque pointer-to-member
  values; uninstantiated-template emission, a nontrivial standard-library value
  facade, C++ exception propagation into an Ada handler; and the exact behavior
  of known defects.

The call-ABI suite reports the `long double` result separately. On Linux
AArch64 with the pinned GCC 13--15 toolchains, GNAT and C++ disagree on that
target calling convention even though the mapper emits the standard
`Interfaces.C.long_double` declaration. That target/runtime boundary is
reported explicitly instead of stopping the suite, so enum, record, union,
pointer, reference, and callback oracles still execute. A mismatch on any
other target remains a failure.

The accepted defect regressions reproduce malformed template records before
patching, anonymous nested template types before patching, anonymous enum
omissions before patching, pointer-to-member syntax failures, standalone
empty-class storage drift, inherited tail-padding drift, explicit alignment
before patching, virtual-inheritance, virtual-diamond, and concrete
multiple-inheritance layout drift, unsigned 128-bit integer failures on GCC 13
and 14 before patching, and several version- or type-specific omissions.
Independent problems must become independent patch bundles.

The coverage summary reports both baselines. After the currently accepted
patches, all 63 atomic cases pass on every supported major.

The confirmed-history ledger is larger than that residual atomic count:
twenty-one independent C++ mapper defects now have accepted 1.2.0 bundles and no
confirmed fixed-layout runtime defect remains. Every linked bundle contains the
offending C++, the unpatched Ada output, the corrected Ada output, and an
executable `-O0`/`-O2` before/after regression:

- [`cxx-ada-template-qualification`](../../bundles/cxx-ada-template-qualification/README.md): references outside a concrete template package lose their instance qualifier;
- [`cxx-ada-template-record-termination`](../../bundles/cxx-ada-template-record-termination/README.md): trivial concrete template records leave their Convention aspect unterminated;
- [`cxx-ada-explicit-alignment`](../../bundles/cxx-ada-explicit-alignment/README.md): explicitly over-aligned records retain only their natural Ada alignment;
- [`cxx-ada-namespace-identity`](../../bundles/cxx-ada-namespace-identity/README.md): distinct named C++ namespaces collapse into duplicate Ada identifiers;
- [`cxx-ada-qualified-method-names`](../../bundles/cxx-ada-qualified-method-names/README.md): cv/ref-qualified overloads and move assignment collapse onto Ada homographs;
- [`cxx-ada-casefold-identity`](../../bundles/cxx-ada-casefold-identity/README.md): C++ identifiers differing only by case collide in Ada;
- [`cxx-ada-template-nested-types`](../../bundles/cxx-ada-template-nested-types/README.md): anonymous field types are emitted outside the concrete template package that needs them;
- [`cxx-ada-anonymous-enums`](../../bundles/cxx-ada-anonymous-enums/README.md): top-level anonymous enumerators and their synthetic type are omitted;
- [`cxx-ada-char8-type`](../../bundles/cxx-ada-char8-type/README.md): `char8_t` maps to a nonexistent Ada identifier;
- [`cxx-ada-int128-types`](../../bundles/cxx-ada-int128-types/README.md): GCC 13 and 14 fail to recognize the unsigned internal 128-bit type name;
- [`cxx-ada-vector-types`](../../bundles/cxx-ada-vector-types/README.md): machine vectors map to placeholders that cannot appear in profiles;
- [`cxx-ada-member-pointers`](../../bundles/cxx-ada-member-pointers/README.md): data- and function-member pointer representations are emitted without Ada types;
- [`cxx-ada-inherited-tail-padding`](../../bundles/cxx-ada-inherited-tail-padding/README.md): Ada inheritance prevents C++ reuse of base tail padding and moves derived fields;
- [`cxx-ada-empty-class-storage`](../../bundles/cxx-ada-empty-class-storage/README.md): empty complete objects receive zero storage while overlapping empty subobjects are represented as ordinary fields;
- [`cxx-ada-virtual-inheritance-layout`](../../bundles/cxx-ada-virtual-inheritance-layout/README.md): virtual bases lose complete size, alignment, and field positions;
- [`cxx-ada-enclosing-type-method-names`](../../bundles/cxx-ada-enclosing-type-method-names/README.md): a method collides case-insensitively with its enclosing Ada type;
- [`cxx-ada-virtual-diamond-layout`](../../bundles/cxx-ada-virtual-diamond-layout/README.md): direct diamond bases incorrectly include their shared virtual base as complete storage;
- [`cxx-ada-profile-formal-type-names`](../../bundles/cxx-ada-profile-formal-type-names/README.md): a formal hides its own, a later formal's, or the result type;
- [`cxx-ada-concrete-multiple-inheritance`](../../bundles/cxx-ada-concrete-multiple-inheritance/README.md): additional concrete bases are emitted as illegal Ada progenitors instead of nested ABI storage;
- [`cxx-ada-visible-type-method-names`](../../bundles/cxx-ada-visible-type-method-names/README.md): a method hides a type made visible from another generated class package;
- [`cxx-ada-derived-virtual-slots`](../../bundles/cxx-ada-derived-virtual-slots/README.md): class-specific destructor names shift later derived virtuals away from their C++ vtable slots.

The following list is only the work still open or intentionally bounded, not
the complete defect history.

The remaining confirmed inventory is deliberately explicit:

- tested semantic boundaries rather than hidden mapper successes:
  uninstantiated templates are not emitted, nontrivial standard-library values
  require a facade, and dynamic virtual-base conversions remain ABI operations.
  C++ exception propagation is tested and supported through Ada's portable
  `others` handler. GNAT's internal API for recovering the foreign language
  identity varies by runtime version and is not claimed as portable behavior;
  Linux AArch64 `long double` interoperability on affected GNAT releases is a
  compiler call-ABI boundary, not a mapper-spelling success.

Run the complete current panel against a compiler root:

```sh
./panels/cxx-ada-spec/run-panel.sh TOOLCHAIN_ROOT GCC_VERSION unpatched
```

Use `patched` after applying every accepted C++ Ada mapper bundle. An expected
pre-patch compiler rejection counts as a passing defect characterization; a
patched run must generate compilable Ada and execute its consumer.

The matrix is deliberately broader than the current patchset. New confirmed
defects must become independent `bundles/<id>/` entries instead of being folded
into the template-qualification patch. The panel is operationally broad but not
mathematically exhaustive; `coverage.toml` explicitly lists constructs still
requiring probes or runtime ABI oracles.
