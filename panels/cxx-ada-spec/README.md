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
- Sixteen runtime suites link C++ and Ada at `-O0` and `-O2`. They check scalar,
  enum, record, union, pointer, reference, and callback calling conventions;
  object size, alignment, and field offsets; ordinary and interface virtual
  dispatch; template qualification, record termination, nested types, explicit
  alignment, namespace and method identity, anonymous enumeration values, and
  `char8_t`, machine vectors, and opaque pointer-to-member values; and the exact
  behavior of known defects.

The known-defect layer currently reproduces malformed template records before
patching, anonymous nested template types before patching, anonymous enum
omissions before patching, pointer-to-member syntax failures, inherited
tail-padding drift, explicit alignment before patching, virtual-inheritance
layout drift,
and several version- or type-specific omissions. Independent problems must
become independent patch bundles.

The coverage summary reports both baselines. After the currently accepted
patches, one atomic case remains non-passing on GCC 15 and 16, and two remain
on GCC 13 and 14 because their `__int128` mapping is also invalid.

The confirmed-history ledger is larger than that residual atomic count:
eleven independent C++ mapper defects now have accepted 1.2.0 bundles, one
version-specific mapper defect remains, two runtime layout defects remain, and
one concrete-inheritance form is a direct-representation boundary. The
following list is only the work still open or intentionally bounded, not the
complete defect history.

The remaining confirmed inventory is deliberately explicit:

- a generated-spec failure on every tested major: concrete secondary multiple
  inheritance;
- an additional generated-spec failure on GCC 13 and 14: `__int128`;
- runtime layout defects on every tested major: inherited tail-padding reuse
  and virtual inheritance;
- tested semantic boundaries rather than hidden mapper successes:
  uninstantiated templates are not emitted, nontrivial standard-library values
  require a facade, and C++ exceptions must not cross the language boundary.

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
