# GNAT patchsets

This repository curates reproducible GCC/GNAT fixes while they are being
reported, reviewed, or backported upstream. It contains patch bundles,
executable regression fixtures, pinned source metadata, and the scripts used
to apply and validate them. It does not contain a GCC source tree.

Every accepted patch bundle includes at least one executable regression test.
A code-only change is not an accepted bundle. Each compiler problem gets its
own `bundles/<id>/` directory and its own regression; a new problem never folds
itself into an existing bundle's patch.

Separate directories are not the same as separate patches. A bundle records
whether its patch applies to pristine upstream source with
`standalone_patch`, and `scripts/check-standalone.sh` proves that claim against
the pinned source in CI. Fourteen of the twenty-four bundles are standalone.
The other ten form an ordered series: their patch text is expressed against the
accumulated tree, so upstream submission means either regenerating them against
trunk or sending them as a declared series. `patchsets/<version>/gcc-<major>.toml`
records the order they apply in.

This repository is not a GCC fork. It curates patches against unmodified,
checksum-pinned upstream sources and proves them with source builds.

## Current patchset

Patchset `1.2.0` is the current repository candidate for GCC 13, 14, 15, and
16. It contains eighteen independent corrections, each with its own executable
regression. Patchset `1.1.0` remains the latest published release until the
`1.2.0` validation and publication workflows complete.

Seven further C++ mapper bundles are curated here but deliberately held out of
`1.2.0`; see [staged bundles](#staged-bundles) below.

- `storage-model-actuals`: selected and indexed actuals rooted at a
  `Designated_Storage_Model` dereference bypass `Copy_From` and `Copy_To`.
  GCC 13 does not have this defect and remains its known-good control.
- `protected-duration-validity`: an automatically selected lock-free protected
  body retains validity checks inserted before the protected type was marked
  lock-free. GCC 13 through 16 are affected.
- `cxx-ada-template-qualification`: the C++ Ada spec dumper emits concrete
  template instances in nested packages but drops those package qualifiers
  from aliases, fields, parameters, and results. Two instantiations therefore
  make the generated Ada spec ambiguous. GCC 13 through 16 are affected.
- `cxx-ada-template-record-termination`: the dumper omits the semicolon after
  trivial records emitted inside concrete template-instance packages. Primary,
  specialized, nested, constrained, and template-template forms all reach the
  same broken printer path. GCC 13 through 16 are affected.
- `cxx-ada-explicit-alignment`: the dumper omits a record's user-specified
  `alignas` unless the layout is also packed or contains bit fields, so Ada and
  C++ disagree on object size and alignment. GCC 13 through 16 are affected.
- `cxx-ada-namespace-identity`: the dumper flattens named C++ namespaces, so
  unrelated declarations with the same unqualified name collide in Ada. The
  correction preserves complete named namespace paths in records, functions,
  aliases, type references, and generated class packages. GCC 13 through 16
  are affected.
- `cxx-ada-qualified-method-names`: cv/ref-qualified methods and copy/move
  assignment operators collapse onto identical Ada declarations. Stable Ada
  suffixes preserve the C++ distinctions and make every imported symbol
  callable. GCC 13 through 16 are affected.
- `cxx-ada-casefold-identity`: distinct C++ identifiers that differ only by
  case become duplicate Ada names. Scope-local suffixes preserve records,
  functions, aliases, fields, and every generated reference. GCC 13 through
  16 are affected.
- `cxx-ada-template-nested-types`: concrete class-template packages reference
  anonymous array field types without declaring them. The normal nested-type
  prepass now runs for non-type and defaulted template arguments. GCC 13
  through 16 are affected.
- `cxx-ada-anonymous-enums`: top-level anonymous enumerations lose their
  constants and appear in signatures as incomplete internal types. Synthetic
  Ada enum names consistently preserve sequential and sparse values. GCC 13
  through 16 are affected.
- `cxx-ada-char8-type`: the dumper emits the undefined Ada name `char8_t`.
  Mapping it to ABI-equivalent `Interfaces.C.unsigned_char` produces a usable
  binding while retaining the distinct C++ mangled symbol. GCC 13 through 16
  are affected.
- `cxx-ada-int128-types`: GCC 13 and 14 recognize signed `__int128` but emit
  unsigned `__int128` as the undefined Ada identifier `uu_int128_unsigned`.
  Prefix recognition maps both forms to `Interfaces.C.Extensions`; GCC 15 and
  16 are known-good controls.
- `cxx-ada-vector-types`: fixed-size C++ vectors are printed as `<vector>`.
  Exact Ada machine-vector arrays, target alignment, and direct vector ABI
  classification make integer and floating vectors callable. GCC 13 through
  16 are affected.
- `cxx-ada-member-pointers`: data-member offsets and member-function pointer
  records contain blank Ada types. Itanium ABI representations preserve data,
  nonvirtual, virtual, and null values as opaque callable-through-C++ values.
  GCC 13 through 16 are affected.
- `cxx-ada-enclosing-type-method-names`: a method whose spelling differs from
  its enclosing type only by case becomes an illegal duplicate Ada identifier.
  Only the colliding method receives a stable `_Method` suffix and keeps its
  C++ external symbol. GCC 13 through 16 are affected.
- `cxx-ada-profile-formal-type-names`: a formal parameter can hide its own
  type, a later formal's type, or the result type in the same generated Ada
  profile, so GNAT rejects the binding. Only a hiding formal receives a stable
  `the_` prefix. GCC 13 through 16 are affected.
- `cxx-ada-visible-type-method-names`: a method can collide with a type made
  use-visible from another generated class package, making later Ada profiles
  ambiguous. Only a method matching a visible generated type receives a stable
  `_Method` suffix. GCC 13 through 16 are affected.
- `predicate-conditional-aggregate-box`: relocating a delayed conditional
  expression into a reference, in order to apply a `Dynamic_Predicate` check,
  leaves the boxed aggregates in its branches unexpanded and aborts the
  compiler. GCC 15 and 16 are affected; GCC 13 and 14 are known-good controls.

| Bundle | 13.2.0 | 14.2.0 | 15.3.0 | 16.2.0 |
| --- | --- | --- | --- | --- |
| `storage-model-actuals` | known-good control | affected | affected | affected |
| `protected-duration-validity` | affected | affected | affected | affected |
| `cxx-ada-template-qualification` | affected | affected | affected | affected |
| `cxx-ada-template-record-termination` | affected | affected | affected | affected |
| `cxx-ada-explicit-alignment` | affected | affected | affected | affected |
| `cxx-ada-namespace-identity` | affected | affected | affected | affected |
| `cxx-ada-qualified-method-names` | affected | affected | affected | affected |
| `cxx-ada-casefold-identity` | affected | affected | affected | affected |
| `cxx-ada-template-nested-types` | affected | affected | affected | affected |
| `cxx-ada-anonymous-enums` | affected | affected | affected | affected |
| `cxx-ada-char8-type` | affected | affected | affected | affected |
| `cxx-ada-member-pointers` | affected | affected | affected | affected |
| `cxx-ada-vector-types` | affected | affected | affected | affected |
| `cxx-ada-enclosing-type-method-names` | affected | affected | affected | affected |
| `cxx-ada-profile-formal-type-names` | affected | affected | affected | affected |
| `cxx-ada-visible-type-method-names` | affected | affected | affected | affected |
| `cxx-ada-int128-types` | affected | affected | known-good control | known-good control |
| `predicate-conditional-aggregate-box` | known-good control | known-good control | affected | affected |
| **Patchset 1.2.0** | patched toolchain | patched toolchain | patched toolchain | validation candidate |

Patchset `1.1.0`, which contains the first two bundles, is the published
patchset. GCC 13 was an unpatched control in patchset `1.0.1` because the only
bundle at that time did not affect it; it carries a real code patch from
`1.1.0` onwards.

Each canonical patch is required to apply with `patch --fuzz=0` to the pinned
FSF release sources and to the pinned Darwin-maintainer sources of every GCC
major it declares. Exact context is required, so no hunk may apply with fuzz; a
hunk may land at a line offset where a release moved surrounding code.

### Staged bundles

A staged bundle is curated, checksum-pinned, and validated exactly like an
accepted one: it has patch variants for every affected release, an executable
`-O0`/`-O2` before/after regression, a README showing the offending C++ with
both the current and the corrected Ada, and an entry in the panel ledger.
It is simply not part of the published patchset yet.

Patchset `1.2.0` stages the C++ object-layout and vtable-identity work. These
patches are coupled to Itanium C++ ABI facts—as-base versus complete-object
sizes, secondary base offsets, virtual-base sharing, and vtable slot
identity—and cannot be expressed as native Ada inheritance, so they need
separate upstream review before they ship in a toolchain. They form one ordered
series, not seven independent patches.

| Staged bundle | 13.2.0 | 14.2.0 | 15.3.0 | 16.2.0 |
| --- | --- | --- | --- | --- |
| `cxx-ada-inherited-tail-padding` | affected | affected | affected | affected |
| `cxx-ada-empty-class-storage` | affected | affected | affected | affected |
| `cxx-ada-virtual-inheritance-layout` | affected | affected | affected | affected |
| `cxx-ada-virtual-diamond-layout` | affected | affected | affected | affected |
| `cxx-ada-concrete-multiple-inheritance` | affected | affected | affected | affected |
| `cxx-ada-derived-virtual-slots` | affected | affected | affected | affected |
| `cxx-ada-generated-name-identity` | affected | affected | affected | affected |

Two of the seven are staged by dependency rather than by ABI judgement.
`cxx-ada-inherited-tail-padding` decides *when* to nest a primary-base
component, but the virtual-base layout path is what emits it, so on its own the
patch does not produce the corrected record. CI proved that by building it.
And
`cxx-ada-generated-name-identity` renames the as-base types, synthetic base
components, and destructor entities the layout bundles introduce, so its patch
does not apply without them.

Staged bundles apply, in the order recorded in
`patchsets/1.2.0/gcc-<major>.toml`, on top of a tree that already has the
complete patchset:

```sh
./scripts/apply-patchset.sh 1.2.0 16 work/gcc-16.2.0
./scripts/apply-staged.sh 1.2.0 16 work/gcc-16.2.0
```

A compiler built that way is a *staged* toolchain. Every regression and panel
runner distinguishes the three states:

- `unpatched`: pinned upstream source, defects characterized;
- `patched`: patchset `1.2.0` only, the state a release ships;
- `staged`: patchset `1.2.0` plus the staged bundles.

A `patched` panel run makes no claim about a staged subject and reports those
suites as skipped. `scripts/package-patchset.sh` and the release workflow never
see a staged bundle.

The `predicate-conditional-aggregate-box` abort was measured on
`aarch64-apple-darwin` only before the bundle was written. It is an abort in
the target-independent front end, so no target-specific behaviour is claimed
for it; the Linux x86-64 and AArch64 lanes of patchset `1.2.0` are its first
Linux measurement.

### Target-dependent protected `Duration` failure

The protected `Duration` defect is a front-end defect, but it does not surface
identically on every target. Before the patch, with `-gnatVa`:

- On Linux x86-64 at `-O0` the regression builds but raises
  `CONSTRAINT_ERROR ... invalid data` when a valid negative `Duration` is
  assigned.
- On Linux x86-64 at `-O2` the front end aborts in `fold_convert_loc` and no
  executable is produced. The exact `fold-const.cc` line differs per release.
- On Linux and macOS AArch64 the same executable round trip succeeds at both
  optimization levels.

The AArch64 lanes are therefore unpatched *target controls*, not evidence that
the source defect is absent: the stale check is present in the tree on every
target. An explicitly `Lock_Free` protected object compiles correctly, which is
what identifies automatic lock-free selection as the cause. The regression
runner encodes exactly this. For an unpatched `x86_64-*-linux*` compiler it
requires the run-time rejection at `-O0` and the compiler abort at `-O2`; on
every other target it requires the unpatched round trip to succeed; and once
patched it requires success at both `-O0` and `-O2` everywhere.

## Layout

- `bundles/<id>/manifest.toml`: problem, provenance, applicability, commands,
  test expectations, licensing, upstream state, and checksums.
- `bundles/<id>/patches/`: complete patches, including their GCC testsuite
  additions.
- `bundles/<id>/tests/`: byte-identical, directly runnable copies of the
  regression programs.
- `sources/`: exact FSF release and Darwin source identities.
- `patchsets/<version>/gcc-<major>.toml`: ordered aggregate for one GCC major.
- `panels/cxx-ada-spec/`: executable C++ feature inventory, confirmed mapper
  holes, representation boundaries, and planned probes.
- `scripts/`: fetch, verification, application, build, test, and packaging
  entry points.
- [`flyology-ada/alire-index`](https://github.com/flyology-ada/alire-index):
  release-generated `gnat_flyology_native` compiler entries; compiler binaries
  remain immutable release assets in this repository.

## Source baselines

Linux uses [official FSF release tarballs](https://gcc.gnu.org/releases.html), verified by the
published SHA-512 checksum and cross-checked against the release tag commit and
tree. macOS arm64 uses pinned public Darwin GCC tags derived from
[Iain Sandoe's branches](https://github.com/iains), the same public source
family used by [Alire's `GNAT-FSF-builds`](https://github.com/alire-project/GNAT-FSF-builds/blob/main/specs/gcc.anod).
The GCC 16.2 candidate preserves Iain's complete AArch64 Darwin history and
merges the signed FSF 16.2 release in the public
[`flyology-ada/gcc-16-branch`](https://github.com/flyology-ada/gcc-16-branch)
fork. Every checkout is verified by an exact tag, commit, and tree identity.

This split is required. FSF GCC 16.1 and 16.2 do not provide an
`aarch64-*-darwin` target in `gcc/config.gcc`; substituting the unmodified FSF
tarball would create a lane that cannot build GNAT for Apple Silicon. The
Darwin tags are public source, so the macOS arm64 lane is real and
redistributable. CI intentionally has no macOS x86_64 matrix.

GitHub's [documented public-runner labels](https://github.com/actions/runner-images#available-images) used here are `ubuntu-24.04`,
`ubuntu-24.04-arm`, `macos-14`, and `macos-15`; both macOS labels and the
Ubuntu arm label are native arm64 runners. GCC 14 through 16 use the pinned
`macos-15`/Xcode 16.4 baseline. GCC 13 uses the pinned
`macos-14`/Xcode 15.4 baseline from the public GNAT-FSF 13.2.0-2 Apple-Silicon
build workflow. This is required because Xcode 16.4's assembler rejects the
older GCC 13 Darwin `libgcc` LSE CFI layout. The workflow fails if its exact
Xcode application is absent; it does not fall forward to a newer assembler.
The installed compiler does not retain that versioned runner SDK path. Its
built-in Darwin spec follows the public GNAT-FSF distribution baseline and
selects the Command Line Tools SDK when present, otherwise the SDK below the
standard `/Applications/Xcode.app` path. This is validated again after Alire
installs the release on a fresh consumer runner.

## Local validation

Prerequisites are a recent Python 3, POSIX shell tools, Git, GNU patch, and a
working GNAT bootstrap compiler. Linux compiler builds also need the usual GCC
development packages; macOS builds need Xcode command-line tools plus GMP,
MPFR, and MPC from Homebrew.

`fetch-bootstrap.sh` checksum-verifies the bootstrap URL declared for each
host before extraction. GCC 16.2 uses the published
`16.1.0-patchset.1.1.0` Flyology compiler only as stage zero; CI builds a
separate unpatched 16.2 compiler for the before-patch controls.
On Darwin it then quarantines the archive's `include-fixed` directory: those
headers are generated from the Xcode SDK used to build the bootstrap and are
not valid inputs for a later runner SDK. The compiler build consequently reads
the current pinned runner's SDK headers. After installation, `build-gnat.sh`
also quarantines the fixed headers generated from that pinned build SDK. The
installed compiler deliberately selects the portable Command Line Tools or
standard Xcode SDK path at use time, so retaining build-SDK declarations such
as `FILE` would mix two SDKs and can break ordinary C++ headers including
`<string>`. The original directories remain beside the active include search
path as `include-fixed.bootstrap-sdk` and `include-fixed.build-sdk` for
diagnostics; neither is searched by GCC.

```sh
./scripts/verify-repository.sh
./scripts/fetch-source.sh 16.2.0 work/gcc-16.2.0
./scripts/apply-patchset.sh 1.2.0 16 work/gcc-16.2.0
PATH=/path/to/bootstrap/bin:$PATH \
  ./scripts/build-gnat.sh work/gcc-16.2.0 build/gcc-16 install/gcc-16
./scripts/run-regressions.sh install/gcc-16 1.2.0 16 patched
```

`run-regressions.sh` takes a toolchain root, a patchset version, a GCC major,
and whether that toolchain is `unpatched`, `patched`, or `staged`. It resolves
the applicable bundles and known-good controls from the selected patchset and
runs each bundle's own executable regression, so the same command covers a
bootstrap compiler, a freshly built compiler, and a relocated release archive:

```sh
./scripts/run-regressions.sh "$BOOTSTRAP_ROOT" 1.2.0 16 unpatched
```

A `staged` toolchain additionally carries the staged bundles, so that state
selects their regressions as well:

```sh
./scripts/run-regressions.sh install/gcc-16 1.2.0 16 staged
```

To apply exactly one bundle instead of an aggregate:

```sh
./scripts/apply-bundle.sh protected-duration-validity 16.2.0 work/gcc-16.2.0
```

All application paths use `patch --fuzz=0` and verify the recorded SHA-256
before touching a source tree.

## CI and releases

Validation builds GCC/GNAT from source on Linux x86_64, Linux arm64, and macOS
arm64 for GCC 13 through 16, which is twelve independent source-build lanes.
Each lane proves the unpatched controls, applies the complete `1.2.0`
aggregate to the declared source baseline, builds the compiler, and runs every
applicable bundle's executable regression at `-O0` and `-O2`. Each lane then
checks that the staged bundles still apply with zero fuzz on top of that
release's patchset; it does not rebuild for them. A separate GCC 16.2 Linux
x86_64 lane builds a staged compiler and runs the staged regressions and the
staged panel, so the staged bundles keep executable before/after evidence
without entering a shipped toolchain. When the
bootstrap already contains the patchset, as for GCC 16.2, CI first builds and
tests a separate unpatched compiler from the pinned source, discards that
control build, and then performs a fresh patched build. Source and bootstrap
downloads are checksum-verified even when restored from cache. Failed jobs
retain compact test and configuration logs.

Each successful source-build lane also creates a relocatable native C, C++, and
Ada compiler archive and reruns the same executable regression from a fresh extraction.
These are the only compiler binaries eligible for a release; bootstrap
archives are never republished as patched toolchains. The archives include the
non-system GMP, MPFR, and MPC-family libraries used by the compiler build; the
macOS packager rewrites their Homebrew install names to loader-relative paths,
then ad-hoc signs and strictly verifies every loadable Mach-O image after
relocation and stripping. The generated Alire entry supplies the package's
`lib` directory through `DYLD_LIBRARY_PATH` as well as the conventional
GNAT-native environment variables, so GCC's bare Darwin `libgcc_s` install
name also resolves for linked programs run through Alire.
Linux archives include GNU Binutils 2.46.1 built in CI from the checksum-pinned
Sourceware release, matching the helper version in the GNAT-FSF build spec.
The corresponding Binutils source archive and checksum accompany every
release. Its linker is configured with the host's native multiarch library
directories plus the conventional Linux library directories, so relocation
does not retain a CI installation prefix.

Linux consumers still need their distribution's normal C development files
(startup objects, libc headers, and linker scripts), just as they do for the
community `gnat_native` toolchain. The package does not embed or replace the
host libc.

Release publication is a separate manual workflow. The operator supplies both
`patchset_version` and `gcc_major` and explicitly confirms publication. Before
creating `patchset-<version>-gcc-<gcc-version>`, the workflow proves that the
aggregate lists every accepted applicable bundle, checks the source baseline,
applies the aggregate with zero fuzz, and packages the series, manifests,
patches, and tests with a SHA-256 inventory. Existing releases are never
replaced. A `publish=false` dispatch performs the same release-candidate checks
and retains the archive without creating a release. A publishing dispatch also
requires a successful full validation workflow for the exact commit being
released. The release also contains native toolchain archives for Linux
x86-64, Linux AArch64, and macOS AArch64. CI generates an Alire index entry
whose version is `<gcc-version>-patchset.<patchset-version>` and whose
`provides` field exposes the underlying GNAT version.

A publishing dispatch first creates an immutable prerelease candidate. Alire
2.1.1 must install it with a workspace-local selection and run every applicable
bundle's regression at `-O0` and `-O2` on all three supported hosts. Only then
does CI promote the same assets to a stable release. Toolchain archives contain
exactly one top-level directory, as required by Alire's binary-origin
deployment.

After a release is published, add the Flyology index once and, from an Alire
workspace, select the desired patched compiler locally:

```sh
alr index --add \
  git+https://github.com/flyology-ada/alire-index.git \
  --name flyology --before community
alr -n toolchain --select --local \
  gnat_flyology_native=16.2.0-patchset.1.1.0
```

Patchset `1.1.0` currently publishes four compiler versions:

```text
gnat_flyology_native=13.2.0-patchset.1.1.0
gnat_flyology_native=14.2.0-patchset.1.1.0
gnat_flyology_native=15.3.0-patchset.1.1.0
gnat_flyology_native=16.1.0-patchset.1.1.0
```

The GCC 16.2 validation candidate will add
`gnat_flyology_native=16.2.0-patchset.1.1.0` without replacing the immutable
16.1 release.

Patchset `1.2.0` adds the `predicate-conditional-aggregate-box` correction on
top of those two bundles and is not published yet. Its releases will add
`gnat_flyology_native=<gcc-version>-patchset.1.2.0` entries without replacing
any immutable `1.1.0` release.

The Alire crate configures `PATH` and the platform library paths. A project may
select `gprbuild` separately through its usual Alire toolchain configuration.
There is intentionally no macOS x86-64 origin.

The release attaches the generated manifest. A fail-closed importer owned by
`flyology-ada/alire-index` verifies its release tag, platform set, asset URLs,
and checksum sidecars before committing it with that repository's scoped
`GITHUB_TOKEN`; no cross-repository credential is stored here.

## Licensing and provenance

Repository-authored scripts and documentation are MIT licensed. Patch hunks
derived from GCC retain GCC's upstream licensing; both compiler patches are
GPL-3.0-or-later, and their regression tests are intended for contribution to
the GCC testsuite under GCC project terms. Each bundle manifest records its
specific provenance and license. Packaging does not relicense patch content.
