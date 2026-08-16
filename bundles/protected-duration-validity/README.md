# Protected `Duration` validity checks

With validity checking enabled, an automatically selected lock-free protected
body is first analyzed before the protected type is marked lock-free. GNAT
therefore inserts validity checks that would have been suppressed for an
explicitly lock-free protected body, then copies those stale checks into the
generated atomic implementation.

On Linux x86-64 with `-gnatVa`, GCC 13.2.0 through 16.2.0 fail in two ways
before the patch:

- At `-O0` the program builds but raises
  `CONSTRAINT_ERROR ... invalid data` on assignment of a valid negative
  `Duration`.
- At `-O2` the front end aborts in `fold_convert_loc` and no executable is
  produced. The exact `fold-const.cc` line differs per release.

The same executable source succeeds on Linux and macOS AArch64 before the
patch, so those lanes are application and build controls rather than
demonstrations of the target-dependent failure. The stale check is present in
the tree on every target.

The correction removes only compiler-generated invalid-data raises while the
lock-free statement copy is traversed. Source `raise Constraint_Error`
statements and other run-time checks are preserved. The executable `gnat.dg`
test assigns and reads a negative `Duration` at `-O2 -gnatVa`.

`patches/gcc-13-16.patch` applies with `patch --fuzz=0` to all pinned GCC
13.2.0, 14.2.0, 15.3.0, 16.1.0, and 16.2.0 FSF and Darwin source baselines.
The pinned FSF and Darwin `exp_ch9.adb` blobs are identical per GCC release,
and the hunk anchor is unique in each file, so the single canonical patch is
unambiguous even where a release moved the surrounding code and the hunk lands
at an offset.
