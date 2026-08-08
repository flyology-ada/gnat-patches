# Protected `Duration` validity checks

With validity checking enabled, an automatically selected lock-free protected
body is first analyzed before the protected type is marked lock-free. GNAT
therefore inserts validity checks that would have been suppressed for an
explicitly lock-free protected body, then copies those stale checks into the
generated atomic implementation.

On Linux x86-64, optimizing a protected `Duration` assignment produces an
internal compiler error; a protected read can instead raise an erroneous
`CONSTRAINT_ERROR`. The same executable source succeeds on Linux and macOS
AArch64 before the patch, so those lanes are application and build controls
rather than demonstrations of the target-dependent failure.

The correction removes only compiler-generated invalid-data raises while the
lock-free statement copy is traversed. Source `raise Constraint_Error`
statements and other run-time checks are preserved. The executable `gnat.dg`
test assigns and reads a negative `Duration` at `-O2 -gnatVa`.

`patches/gcc-13-16.patch` applies with zero fuzz to all pinned GCC 13.2.0,
14.2.0, 15.3.0, and 16.1.0 FSF and Darwin source baselines.
