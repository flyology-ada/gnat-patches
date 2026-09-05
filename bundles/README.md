# Patch bundles

This directory contains reviewable GCC/GNAT fixes, one problem per bundle. Each
bundle has a manifest, one or more source patches, an executable regression, and
a README showing the offending input, the broken output, and the corrected
output. Patchsets select applicable variants by exact GCC release; the bundle
README is the best starting point for reviewing an individual change.

Each bundle addresses an independent problem, but the patches are not all
independent of each other. `standalone_patch` in the manifest records whether a
bundle's patch applies with zero fuzz to pristine upstream source;
`scripts/check-standalone.sh` proves it in CI. Sixteen bundles are standalone.
The rest apply only in the order recorded in
`patchsets/<version>/gcc-<major>.toml`, because their patch text is expressed
against the accumulated tree — sometimes only as line-offset context, sometimes
because they genuinely extend a helper an earlier bundle introduced.

A bundle is either **accepted**, meaning every patchset for an affected GCC
major must contain it, or **staged**, meaning it is curated and validated to the
same standard but deliberately held out of the published patchset. A staged
bundle records why in its manifest, and `scripts/manifest.py validate` refuses
to let one appear in a patchset.

The tables below summarize the bundles. “GCC releases” describes the pinned
releases covered by the bundle, not every possible upstream revision.

## Ada expansion and runtime semantics

These bundles fix GNAT expansion paths outside the C++ binding generator.

| Bundle | GCC releases | Summary |
| --- | --- | --- |
| [Protected `Duration` validity](protected-duration-validity/README.md) | 13.2–16.2 | Removes invalid `Duration` validity checks retained by automatically selected lock-free protected bodies. |
| [Controlled allocator named subpools](controlled-subpool-allocator/README.md) | 13.2, 14.2, 15.1 | Preserves an allocator's explicit subpool while building the controlled object's custom allocation procedure. |
| [Storage-model actuals](storage-model-actuals/README.md) | 14.2–16.2 | Routes selected and indexed designated-storage-model actuals through `Copy_From` and `Copy_To`. |

## C++ to Ada mapper

GCC's C++ to Ada mapper must translate more than C++ spelling. A usable binding
has to preserve namespace and overload identity, emit legal Ada declarations,
match the C++ object and call ABI, and retain virtual dispatch relationships.
Several C++ constructs have no direct Ada equivalent, so the mapper sometimes
needs an explicit storage view or a documented interoperability boundary.

The comprehensive feature panel and its remaining limits are documented in
the [C++ to Ada mapper panel](../panels/cxx-ada-spec/README.md).

### Names, namespaces, and profiles

| Bundle | GCC releases | Summary |
| --- | --- | --- |
| [Namespace identity](cxx-ada-namespace-identity/README.md) | 13.2–16.2 | Maps named C++ namespaces to nested Ada packages instead of flattening and colliding declarations. |
| [Case-fold identity](cxx-ada-casefold-identity/README.md) | 13.2–16.2 | Disambiguates C++ identifiers that differ only by case in Ada. |
| [Qualified method names](cxx-ada-qualified-method-names/README.md) | 13.2–16.2 | Separates cv/ref-qualified overloads and copy/move assignment names. |
| [Enclosing-type method names](cxx-ada-enclosing-type-method-names/README.md) | 13.2–16.2 | Avoids a case-insensitive collision between a method and its enclosing type. |
| [Visible-type method names](cxx-ada-visible-type-method-names/README.md) | 13.2–16.2 | Avoids method collisions with types made visible from another generated class package. |
| [Profile formal/type names](cxx-ada-profile-formal-type-names/README.md) | 13.2–16.2 | Prevents a formal parameter from hiding a type used later in the same Ada profile. |

### Templates and declarations

| Bundle | GCC releases | Summary |
| --- | --- | --- |
| [Template qualification](cxx-ada-template-qualification/README.md) | 13.2–16.2 | Retains generated package qualification on references to concrete template instances. |
| [Template record termination](cxx-ada-template-record-termination/README.md) | 13.2–16.2 | Terminates trivial records emitted inside concrete template packages. |
| [Template nested types](cxx-ada-template-nested-types/README.md) | 13.2–16.2 | Declares anonymous nested field types used by concrete class-template packages. |
| [Anonymous enums](cxx-ada-anonymous-enums/README.md) | 13.2–16.2 | Emits top-level anonymous-enum constants instead of incomplete internal types. |

### Types and non-inheritance layout

| Bundle | GCC releases | Summary |
| --- | --- | --- |
| [Explicit alignment](cxx-ada-explicit-alignment/README.md) | 13.2–16.2 | Emits user-specified record alignment even without packing or bit fields. |
| [`char8_t` type](cxx-ada-char8-type/README.md) | 13.2–16.2 | Maps `char8_t` without referring to a nonexistent `Interfaces.C` type. |
| [128-bit integers](cxx-ada-int128-types/README.md) | 13.2–14.2 | Replaces GCC's internal unsigned 128-bit name with a valid Ada type. |
| [Member pointers](cxx-ada-member-pointers/README.md) | 13.2–16.2 | Emits usable representations for data-member and member-function pointers. |

## Staged: unproven vector method ABI

This bundle is **not** part of patchset `1.2.0`. Its patch is standalone — it
applies to pristine upstream source — and the free-function half of it is
proven: fixed-size vectors become exact Ada machine-vector arrays that
round-trip by value at `-O0` and `-O2`. But the same `VECTOR_TYPE` printer fix
also makes a vector-bearing C++ method print as a callable `Convention => CPP`
binding, and no tested GNAT release classifies that method ABI consistently.
Where the unpatched mapper rejected the spec at compile time, that binding
compiles and can return a wrong value; direct dispatch needs an `extern "C"`
C++ wrapper.

The same patch already fails closed for scalable SVE/RVV vectors, which have no
compile-time lane count, by emitting an explicit `<scalable_vector>` marker. The
bundle ships once the method binding it cannot prove fails closed the same way.
Removing the declaration outright is not that fix: primitive declaration order
assigns the dispatch slot, so dropping a virtual would displace every virtual
declared after it.

It applies before the layout series: `cxx-ada-generated-name-identity` rewrites
the declaration terminator immediately above the alignment emission this patch
adds, so that bundle does not apply without this one.

| Staged bundle | GCC releases | Summary |
| --- | --- | --- |
| [Vector types](cxx-ada-vector-types/README.md) | 13.2–16.2 | Replaces invalid vector placeholders with exact Ada machine-vector types, proven for free-function and `extern "C"` profiles. |

## Staged: C++ object layout and vtable identity

These bundles are **not** part of patchset `1.2.0` either. They are coupled to
Itanium
C++ ABI facts—as-base versus complete-object sizes, secondary base offsets,
virtual-base sharing, and vtable slot identity—and cannot be expressed as
native Ada inheritance, so they need separate upstream review before they ship
in a toolchain. The patches use fixed nested storage views where the ABI
position is static; dynamic virtual-base conversion remains a wrapper or thunk
boundary.

They form one ordered series and apply, in the order below, after the vector
bundle above, on top of a tree that already carries the complete patchset. Two
are here by dependency rather than by ABI judgement:
`cxx-ada-inherited-tail-padding` selects a nested primary-base component that
the virtual-base layout path emits, and `cxx-ada-generated-name-identity`
renames entities the layout bundles introduce and rewrites the declaration
terminator the vector bundle's alignment emission sits under.

| Staged bundle | GCC releases | Summary |
| --- | --- | --- |
| [Inherited tail padding](cxx-ada-inherited-tail-padding/README.md) | 13.2–16.2 | Separates complete-object and as-base sizes and nests a primary base only when C++ actually reuses its tail. |
| [Empty-class storage](cxx-ada-empty-class-storage/README.md) | 13.2–16.2 | Gives complete empty objects one byte, preserves EBO, and omits only an actually overlapping `[[no_unique_address]]` selector. |
| [Virtual inheritance layout](cxx-ada-virtual-inheritance-layout/README.md) | 13.2–16.2 | Restores complete size, alignment, and component positions for classes with virtual bases. |
| [Virtual diamond layout](cxx-ada-virtual-diamond-layout/README.md) | 13.2–16.2 | Uses shortened as-base views for direct diamond legs instead of duplicating their shared virtual base. |
| [Concrete multiple inheritance](cxx-ada-concrete-multiple-inheritance/README.md) | 13.2–16.2 | Keeps the primary base as Ada inheritance and emits concrete secondary bases as exact nested as-base storage. |
| [Derived virtual slots](cxx-ada-derived-virtual-slots/README.md) | 13.2–16.2 | Stabilizes destructor identities so new derived virtuals retain their C++ vtable slots, including through nested secondary bases. |
| [Generated-name identity](cxx-ada-generated-name-identity/README.md) | 13.2–16.2 | Allocates readable synthesized names without colliding with source names or other generated entities. |
