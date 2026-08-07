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

Patchset `1.0.0` contains the `storage-model-actuals` correction:

| GCC source | Baseline | Unpatched | Patchset 1.0.0 |
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

GitHub's [documented public-runner labels](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job) used here are `ubuntu-24.04`,
`ubuntu-24.04-arm`, and `macos-15`. The last two are native arm64 runners.

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
./scripts/apply-patchset.sh 1.0.0 16 work/gcc-16.1.0
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

Release publication is a separate manual workflow. The operator supplies both
`patchset_version` and `gcc_major` and explicitly confirms publication. Before
creating `patchset-<version>-gcc-<major>`, the workflow proves that the
aggregate lists every accepted applicable bundle, checks the source baseline,
applies the aggregate with zero fuzz, and packages the series, manifests,
patches, and tests with a SHA-256 inventory. Existing releases are never
replaced. A `publish=false` dispatch performs the same release-candidate checks
and retains the archive without creating a release. A publishing dispatch also
requires a successful full validation workflow for the exact commit being
released.

## Licensing and provenance

Repository-authored scripts and documentation are MIT licensed. Patch hunks
derived from GCC retain GCC's upstream licensing; the first compiler patch is
GPL-3.0-or-later, and its regression test is intended for contribution to the
GCC testsuite under GCC project terms. Each bundle manifest records its
specific provenance and license. Packaging does not relicense patch content.
