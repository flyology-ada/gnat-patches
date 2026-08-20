# gnat-patches agent guide

This repository curates independent GCC/GNAT patch bundles and validates them
against pinned source baselines. It is not a GCC source fork. Never commit GCC
source trees, compiler builds, downloaded bootstrap compilers, or generated
artifacts.

## Patch invariants

- Every accepted bundle MUST contain one or more executable regression tests.
  A code-only patch is invalid.
- Keep unrelated compiler problems in separate directories under `bundles/`.
- Use one canonical patch across releases only after exact, zero-fuzz context
  checks. Otherwise add explicit version variants and record each checksum.
- One bundle per problem, but do not claim more independence than the patches
  have. Declare `standalone_patch` honestly; `scripts/check-standalone.sh`
  proves it against pristine source in every CI lane. A non-standalone bundle
  applies only in the order its patchset records.
- Known-good releases are unpatched controls. Never manufacture a code patch
  for a release that does not have the defect.
- Source manifests fail closed on release archive checksum, Git commit, and Git
  tree identity. Do not substitute a nearby tag or branch tip.
- A patchset release contains every accepted bundle applicable to its declared
  GCC major. `scripts/manifest.py validate-patchset` is authoritative.
- A bundle is `accepted` only if every binding its patch makes the mapper
  emit is either proven by an executable regression or explicitly
  non-callable. Whatever the patch cannot prove must fail closed: an explicit
  unsupported marker that keeps the generated spec from compiling, or an
  opaque representation Ada cannot invoke. A patch that emits a callable
  binding it does not exercise is `staged`, however complete the rest of it
  is, because it replaces a loud compile-time rejection with a silently wrong
  value. Needing a hand-written C++ wrapper is not by itself a staging
  reason; emitting a binding that hides the need for one is.
- A bundle held out of the published patchset is `status = "staged"`. Staging
  changes nothing about the evidence: the bundle still needs patch variants for
  every affected release, an executable `-O0`/`-O2` before/after regression, a
  README with the offending C++ and both Ada outputs, matrix evidence, and a
  panel ledger entry. Record `staged_reason` and any `staged_depends_on`, list
  it in the patchset's `staged_bundles`, and never in `bundles` or
  `control_tests`. A `patched` regression or panel run must make no claim about
  a staged subject.
- Patchset publication is gated by both patchset version and GCC major. Do not
  publish from a tag alone and do not overwrite an existing release.
- Alire toolchain assets are outputs of successful source-build lanes, not
  repackaged bootstrap compilers. Re-run the regression after relocating each
  archive, require exactly one top-level directory for Alire deployment,
  publish only the three supported native hosts, and keep the
  `gnat_flyology_native` index checksums identical to release assets.
- Publish generated compiler manifests to the existing
  `flyology-ada/alire-index` main branch through that repository's fail-closed
  release importer. Do not add or store a cross-repository write credential in
  this repository.
- Bundle the compiler's non-system numerical runtime libraries. On macOS,
  replace Homebrew-specific dylib paths before archiving; an archive that only
  works on the build runner is invalid.
- A macOS compiler must not retain a versioned GitHub runner SDK path in its
  built-in specs. Use the GNAT-FSF portable Command Line Tools/Xcode.app SDK
  selection and prove it by linking the regression after an Alire install.
- Linux packages use CI-built, checksum-pinned GNU Binutils 2.46.1 helpers.
  Never copy binutils or compiler executables from the bootstrap archive, and
  attach the corresponding Binutils source archive to each release.

## Changes and verification

- Use `rg` for discovery and `apply_patch` for hand edits.
- Preserve executable bits on scripts.
- Run `./scripts/verify-repository.sh`, `git diff --check`, and the smallest
  relevant source/application or compiler regression checks.
- Keep GitHub Actions immutable by pinning third-party actions to commit SHAs.
- Do not add `continue-on-error` to a validation lane.
- Keep prose factual. Distinguish a verified result from a CI expectation.

Use Problem/Solution commit messages:

```text
Problem: <present-tense problem statement>

<Context and impact.>

Solution: <one-line solution statement>

<What changed and why.>
```
