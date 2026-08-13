# Storage-model component actuals

The Ada front end correctly copies a bare object using a nonnative designated
storage model into host memory before a call. GCC 14 through 16 fail to detect
selected, indexed, and slice actuals rooted at the same dereference, so those
forms can be lowered as native memory accesses.

The patch walks component prefixes to the nearest explicit dereference and
uses that storage-model object to select the existing call-by-copy path. Its
`gnat.dg` test is executable and covers explicit and implicit selected and
indexed components, nested components, scalar and record copy-back, ordinary
assignments, and access-value operations.

`patches/gcc-14-16.patch` is canonical for the pinned 14.2.0, 15.3.0, 16.1.0,
and 16.2.0 FSF and Darwin source baselines. `tests/storage_model_actuals.adb`
is a byte-identical runnable copy of the test added by that patch. GCC 13.2.0
uses the fixture only as an unpatched known-good control.
