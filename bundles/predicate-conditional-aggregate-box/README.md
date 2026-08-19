# Boxed aggregate in a predicated conditional expression

A record aggregate that contains a box is expanded top down by its parent
construct. `Convert_To_Assignments` sets `Expansion_Delayed` on it, and since
GCC 15 `Delay_Conditional_Expressions_Between` propagates that delay to every
conditional expression between the aggregate and the parent that will drive the
expansion, which here is a component association of the enclosing aggregate.

When the inner record type carries a checked `Dynamic_Predicate`, resolution of
the enclosing aggregate applies the predicate check to that component first.
The check duplicates the expression, so `Remove_Side_Effects` relocates the
conditional expression into a standalone `Rnn : constant Ann := <expr>'Reference;`
declaration and leaves `Rnn.all` behind. The parent that was going to drive the
delayed expansion is no longer above the expression.

`Remove_Side_Effects` already handles precisely this for a delayed *aggregate*:
when it builds the reference it clears `Expansion_Delayed` and `Analyzed` so
the relocated aggregate is expanded in full. GCC 15 introduced delayed
*conditional expressions* without extending that handling. The conditional
expression and the boxed aggregates in its dependent expressions therefore keep
their delayed flags, nothing ever expands them, and an aggregate reaches
`gnat_to_gnu`, which asserts that no aggregate with delayed expansion can reach
the code generator. The compiler aborts with a GNAT BUG DETECTED box reporting
`in gnat_to_gnu, at ada/gcc-interface/trans.cc` and produces no object file.

The patch extends the existing delayed-aggregate handling in
`Remove_Side_Effects` to delayed conditional expressions. It cancels the delay
on the conditional expression, on the dependent aggregates, and on nested
delayed conditional expressions, and schedules them for reanalysis. The
relocated expression is then expanded exactly as the same code is without a
predicate, and as GCC 13 and 14 already expand it. The predicate check itself
is unchanged and still runs against the selected branch.

GCC 13 and 14 expand the branch aggregates before the predicate check
relocates the conditional expression, so they compile and run the fixture
unchanged and remain unpatched known-good controls.

`patches/gcc-15-16.patch` is canonical for the pinned 15.3.0, 16.1.0, and
16.2.0 baselines. The pinned FSF and Darwin `exp_util.adb` blobs are identical
per GCC release, so the single patch is unambiguous for both source flavors;
each hunk lands at a line offset because later releases moved surrounding code.

`tests/predicate_conditional_aggregate_box.adb` is a byte-identical runnable
copy of the test added by the patch. It covers `others => <>` and a named
`Component => <>`, a compile-time-known and a run-time condition, an if
expression and a case expression, and an object declaration and an assignment
statement. Every case checks that the box actually supplied the component
default `High => 25`, so a correction that compiled but dropped the default
fails. Two further cases select a branch that violates the predicate and
require `Assertion_Error`, so a correction that suppressed the check also
fails.

A qualified expression written around the conditional expression is
deliberately outside this bundle. It reaches the same assertion by a different
route: `Expand_N_Qualified_Expression` distributes the qualification into the
dependent expressions and replaces the delayed conditional expression with a
fresh one that does not carry `Expansion_Delayed`. That form aborts GCC 15 and
16 with no predicate at all, so it has a different ingredient set and belongs
in its own bundle.

The defect is in the target-independent front end, and it was measured on
`aarch64-apple-darwin` only: GCC 13.2.0, 14.1.0, and 14.2.0 compile and run the
fixture, and GCC 15.0.1, 15.3.0, 16.1.0, and 16.2.0 abort. No Linux measurement
was taken before this bundle was written; the Linux x86-64 and AArch64 lanes of
the patchset are its first Linux measurement.
