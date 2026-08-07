# GNAT patchsets

This repository curates reproducible GCC/GNAT fixes while they are being
reported, reviewed, or backported upstream. It contains patch bundles,
executable regression fixtures, pinned source metadata, and the scripts used
to apply and validate them. It does not contain a GCC source tree.

Every accepted patch bundle includes at least one executable regression test.
A code-only change is not an accepted bundle. Independent compiler problems
live in independent `bundles/<id>/` directories; a new problem does not modify
or depend on an existing bundle.

## Current patchset

Patchset `1.0.1` contains the `storage-model-actuals` correction:

| GCC source | Baseline | Unpatched | Patchset 1.0.1 |
| --- | --- | --- | --- |
| 13.2.0 | known-good control | test passes | no code patch; test passes |
| 14.2.0 | affected | test raises `CONSTRAINT_ERROR` | test passes at `-O0` and `-O2` |
| 15.3.0 | affected | test raises `CONSTRAINT_ERROR` | test passes at `-O0` and `-O2` |
| 16.1.0 | affected | test raises `CONSTRAINT_ERROR` | test passes at `-O0` and `-O2` |

The canonical patch applies with zero fuzz to the pinned FSF release sources
and the pinned Darwin-maintainer sources for GCC 14, 15, and 16. GCC 13 is
deliberately tested without a code patch.

## Layout

- `bundles/<id>/manifest.toml`: problem, provenance, applicability, commands,
  test expectations, licensing, upstream state, and checksums.
- `bundles/<id>/patches/`: complete patches, including their GCC testsuite
  additions.
- `bundles/<id>/tests/`: byte-identical, directly runnable copies of the
  regression programs.
- `sources/`: exact FSF release and Darwin source identities.
- `patchsets/<version>/gcc-<major>.toml`: ordered aggregate for one GCC major.
- `scripts/`: fetch, verification, application, build, test, and packaging
  entry points.
- [`flyology-ada/alire-index`](https://github.com/flyology-ada/alire-index):
  release-generated `gnat_flyology_native` compiler entries; compiler binaries
  remain immutable release assets in this repository.

## Source baselines

Linux uses [official FSF release tarballs](https://gcc.gnu.org/releases.html), verified by the
published SHA-512 checksum and cross-checked against the release tag commit and
tree. macOS arm64 uses [Iain Sandoe's public Darwin GCC release tags](https://github.com/iains), the same
public source family used by [Alire's `GNAT-FSF-builds`](https://github.com/alire-project/GNAT-FSF-builds/blob/main/specs/gcc.anod). Those checkouts are
verified by exact commit and tree IDs.

This split is required. FSF GCC 16.1 does not provide an
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

## Local validation

Prerequisites are a recent Python 3, POSIX shell tools, Git, GNU patch, and a
working GNAT bootstrap compiler. Linux compiler builds also need the usual GCC
development packages; macOS builds need Xcode command-line tools plus GMP,
MPFR, and MPC from Homebrew.

`fetch-bootstrap.sh` checksum-verifies the GNAT-FSF archive before extraction.
On Darwin it then quarantines the archive's `include-fixed` directory: those
headers are generated from the Xcode SDK used to build the bootstrap and are
not valid inputs for a later runner SDK. The compiler build consequently reads
the current pinned runner's SDK headers and generates its own fixed headers.
The original directory remains beside it as `include-fixed.bootstrap-sdk` for
diagnostics; it is not searched by GCC.

```sh
./scripts/verify-repository.sh
./scripts/fetch-source.sh 16.1.0 work/gcc-16.1.0
./scripts/apply-patchset.sh 1.0.1 16 work/gcc-16.1.0
PATH=/path/to/bootstrap/bin:$PATH \
  ./scripts/build-gnat.sh work/gcc-16.1.0 build/gcc-16 install/gcc-16
./scripts/run-regressions.sh install/gcc-16 patched
```

To apply exactly one bundle instead of an aggregate:

```sh
./scripts/apply-bundle.sh storage-model-actuals 16.1.0 work/gcc-16.1.0
```

All application paths use `patch --fuzz=0` and verify the recorded SHA-256
before touching a source tree.

## CI and releases

Validation builds GCC/GNAT from source on Linux x86_64, Linux arm64, and macOS
arm64 for GCC 13 through 16. It runs the unpatched control with the bootstrap
compiler, builds the declared source baseline, and runs the executable fixture
at `-O0` and `-O2`. Source and bootstrap downloads are checksum-verified even
when restored from cache. Failed jobs retain compact test and configuration
logs.

Each successful source-build lane also creates a relocatable native compiler
archive and reruns the same executable regression from a fresh extraction.
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
creating `patchset-<version>-gcc-<major>`, the workflow proves that the
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
2.1.1 must install it with a workspace-local selection and run the bundle's
regression at `-O0` and `-O2` on all three supported hosts. Only then does CI
promote the same assets to a stable release. Toolchain archives contain exactly
one top-level directory, as required by Alire's binary-origin deployment.

After a release is published, add the Flyology index once and, from an Alire
workspace, select the desired patched compiler locally:

```sh
alr index --add \
  git+https://github.com/flyology-ada/alire-index.git \
  --name flyology --before community
alr -n toolchain --select --local \
  gnat_flyology_native=16.1.0-patchset.1.0.1
```

The Alire crate configures `PATH` and the platform library paths. A project may
select `gprbuild` separately through its usual Alire toolchain configuration.
There is intentionally no macOS x86-64 origin.

The release attaches the generated manifest. A fail-closed importer owned by
`flyology-ada/alire-index` verifies its release tag, platform set, asset URLs,
and checksum sidecars before committing it with that repository's scoped
`GITHUB_TOKEN`; no cross-repository credential is stored here.

## Licensing and provenance

Repository-authored scripts and documentation are MIT licensed. Patch hunks
derived from GCC retain GCC's upstream licensing; the first compiler patch is
GPL-3.0-or-later, and its regression test is intended for contribution to the
GCC testsuite under GCC project terms. Each bundle manifest records its
specific provenance and license. Packaging does not relicense patch content.
