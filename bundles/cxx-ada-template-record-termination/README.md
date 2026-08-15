# C++ Ada template record termination

`dump_ada_template` writes concrete class-template instances inside nested Ada
packages. For trivial records, `dump_ada_structure` deliberately leaves the
terminating semicolon to its caller, but the template caller did not add it.
The resulting aspect ends at `C_Pass_By_Copy` and GNAT rejects the generated
specification.

A minimal offending declaration is a trivial concrete template instance:

```c++
template <typename T>
struct Plain { T value; };

template struct Plain<int>;
```

The unpatched mapper produces an unterminated record declaration:

```ada
package Plain_int is
   type Plain is limited record
      value : aliased int;
   end record
   with Convention => C_Pass_By_Copy
end;
```

The corrected output terminates the representation aspect before the package
continues:

```ada
package Plain_int is
   type Plain is limited record
      value : aliased int;
   end record
   with Convention => C_Pass_By_Copy;
end;
```

The patch terminates records only when the structure printer did not already
do so while emitting methods or static fields. The executable regression
covers the shared path with primary, partial-specialization,
full-specialization, nested, constrained, and template-template instances.

Run it against an unpatched or patched compiler root:

```sh
./bundles/cxx-ada-template-record-termination/run-test.sh \
  TOOLCHAIN_ROOT GCC_VERSION unpatched
./bundles/cxx-ada-template-record-termination/run-test.sh \
  TOOLCHAIN_ROOT GCC_VERSION patched
```
