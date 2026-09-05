# Controlled allocator named subpools

Exact GNAT 13.2, 14.2, and 15.1 sources lose an explicitly named subpool while
expanding an allocator for a controlled aggregate. Their expansion paths differ
after the controlled-allocation rewrite, but each creates a replacement
allocator and omits `Subpool_Handle_Name`. The generated procedure consequently
passes a null subpool and calls the pool's `Default_Subpool_For_Pool` instead
of the allocator's named subpool.

The failure is independent of optimization. At both `-O0` and `-O2`, the
executable regression raises:

```text
PROGRAM_ERROR : System.Storage_Pools.Subpools.Default_Subpool_For_Pool:
default Default_Subpool_For_Pool called; must be overridden
```

An adjacent plain allocator succeeds with the same pool and named subpool,
isolating the defect to the controlled-aggregate expansion path.

## Correction

The GCC 13/14 variant copies `Subpool_Handle_Name` from the source allocator
onto each synthesized no-initialization allocator before
`Build_Allocate_Deallocate_Proc` examines it. The GCC 15.1 variant propagates
the name while constructing each replacement allocator. Both variants cover
the ordinary and interface controlled-aggregate branches and make the custom
allocator pass the selected subpool just as the source allocator requested.

This is a focused backport of upstream GCC commit
`5dd4b922bb341aa3b821e600ff2e46aa6ed6e850` ("Ada: Fix subpool dropped from
allocator initialized by aggregate"). The GCC 15.1 `exp_ch4.adb` hunks are the
upstream correction; the GCC 13/14 variant expresses the same invariant in the
older expansion. The bundle does not backport the upstream commit's separate
build-in-place function and C++ constructor paths in `exp_ch6.adb`, which are
outside this controlled-qualified-expression regression. GCC 15.3.0, 16.1.0,
and 16.2.0 contain the correction and are known-good controls. GCC 15.2 has not
been tested and is deliberately unclassified.

## Executable evidence

`tests/controlled_subpool_allocator.adb` provides an instrumented
`Root_Storage_Pool_With_Subpools`. It allocates adjacent plain and controlled
objects, including one through an interface access type, into one explicit
subpool and checks that:

- all three allocations reach the named subpool;
- each subpool-selection expression is evaluated exactly once;
- all allocated values survive;
- releasing the subpool releases it once and finalizes both controlled objects
  exactly once.

The runner builds and executes the fixture with assertions enabled at `-O0`
and `-O2`. Before the patch it requires the specific default-subpool
`PROGRAM_ERROR` on GCC 13.2.0, 14.2.0, and 15.1.0. After the patch, and on
known-good controls, it requires the exact success marker:

```text
PASS controlled named subpool allocator
```

Local Darwin AArch64 characterization with the pinned bootstrap compilers
produced the following matrix:

| GCC release | `-O0` | `-O2` | Classification |
| --- | --- | --- | --- |
| 13.2.0 | expected `PROGRAM_ERROR` | expected `PROGRAM_ERROR` | affected |
| 14.2.0 | expected `PROGRAM_ERROR` | expected `PROGRAM_ERROR` | affected |
| 15.1.0 | expected `PROGRAM_ERROR` | expected `PROGRAM_ERROR` | affected |
| 15.3.0 | pass | pass | known-good control |
| 16.1.0 | pass | pass | known-good control |

The 15.1 executable is the official Alire `gnat_native` 15.1.2 Darwin AArch64
asset `gnat-aarch64-darwin-15.1.0-2.tar.gz`, whose SHA-256 is
`60748c5436aba29243333ca1f26c1ef694749644d2f194ab3cbe9f58c53ca829`.
The packaged compiler reports `15.0.1 20250418 (prerelease)`; the GNAT-FSF
release and source identity are therefore recorded alongside, rather than
silently replacing, the compiler's own version string. The release build
specification selects Darwin source ref `gcc-15-1-darwin-rc1`, now pinned here
at commit `845fee6ec56db98b84888f782fe7daea99b4b358`, whose `gcc/DATESTAMP`
is `20250418`.

From that exact patched Darwin source, a local source build completed `gnat1`,
the GNAT tools, `libgcc`, and the Ada runtime. The installed compiler passed
this runner at both `-O0` and `-O2`. A full local package build under Xcode
26.6 was not claimed: the unmodified GCC 15.1 Darwin `libatomic` and
`libstdc++` builds stopped on unrelated unresolved symbols. The GNAT tools used
the pinned 15.3 bootstrap's static C++ runtime for their host-tool links; the
frontend and Ada runtime exercised by the regression were built from the
patched 15.1 source.

The patchset matrix builds GCC 16.2.0 from its exact pinned source and runs it
as the control; the older 16.1.0 bootstrap used for that build is not treated
as the 16.2.0 executable result.

## Source identities and application

The appropriate patch variant applies with `patch --fuzz=0` to all six pinned
affected source identities:

| Release and flavor | Commit/tree identity | `exp_ch4.adb` SHA-256 |
| --- | --- | --- |
| GCC 13.2.0 FSF | `c891d8dc23e1a46ad9f3e757d09e57b500d40044` / `e0036ea6a50a6a9e2b4ffe6e1a7c5276452f1023` | `c2e54ceb420e3146c10d6535f7f4d7d12cf9e0833fcf080fdb92e23aa5f3175a` |
| GCC 13.2.0 Darwin | `46003d70a6411362e9de99ced8242f52129d5f9a` / `608a198adec22ab00cff48d887e30de4dadf2434` | `c2e54ceb420e3146c10d6535f7f4d7d12cf9e0833fcf080fdb92e23aa5f3175a` |
| GCC 14.2.0 FSF | `04696df09633baf97cdbbdd6e9929b9d472161d3` / `1357078fcfcdd78685d385d705c2fa137251cb01` | `0237809863b40b8a19d9a438836aea6781b2ad7493b66cd548af630b2c5a0a6c` |
| GCC 14.2.0 Darwin | `aac1e84d685e43400873ca882b9c81154f9baa26` / `a3f48716d9accaff42c4a64d0fc42aada527708d` | `0237809863b40b8a19d9a438836aea6781b2ad7493b66cd548af630b2c5a0a6c` |
| GCC 15.1.0 FSF | `1b306039ac49f8ad91ca71d3de3150a3c9fa792a` / `9c666d84a329c64b13758acc00820cc34249d22d` | `ba49eb279cac6111e91839e7de79527895da51c7f5c064e8fbce2f02cbdf31c8` |
| GCC 15.1.0 Darwin | `845fee6ec56db98b84888f782fe7daea99b4b358` / `30376aff8a0f6f85da80ea164bd5941375bf0166` | `ba49eb279cac6111e91839e7de79527895da51c7f5c064e8fbce2f02cbdf31c8` |

The FSF and Darwin `exp_ch4.adb` blobs are identical within each affected
release. GCC 14 moves surrounding code by one line, but both older-version
hunks still apply with zero fuzz. GCC 15.1 uses its own variant because the
controlled-allocation expansion was restructured. No nearby source, 15.2
inference, or branch-tip substitution is accepted.
