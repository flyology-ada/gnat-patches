# C++ Ada template nested types

`dump_ada_template` writes each concrete class-template instance into a nested
Ada package, but it bypasses the nested-type prepass used for ordinary record
declarations. Array fields then refer to an anonymous Ada array type that the
package never declares.

Both a non-type argument and its defaulted form reach the same broken path:

```c++
template <typename T, unsigned N>
struct Buffer { T values[N]; };
template struct Buffer<int, 4>;

template <typename T = int, unsigned N = 2>
struct Defaults { T values[N]; };
template struct Defaults<>;
```

The unpatched mapper emits references to internal `anon_array...` names but no
declarations for them (the numeric suffix is compiler-internal and varies):

```ada
package Buffer_int_4 is
   type Buffer is limited record
      values : aliased anon_array1712;
   end record
   with Convention => C_Pass_By_Copy;
end;

package Defaults_int_2 is
   type Defaults is limited record
      values : aliased anon_array1713;
   end record
   with Convention => C_Pass_By_Copy;
end;
```

The corrected output declares each nested type before the record that uses it:

```ada
package Buffer_int_4 is
   type anon_array1712 is array (0 .. 3) of aliased int;
   type Buffer is limited record
      values : aliased anon_array1712;
   end record
   with Convention => C_Pass_By_Copy;
end;

package Defaults_int_2 is
   type anon_array1713 is array (0 .. 1) of aliased int;
   type Defaults is limited record
      values : aliased anon_array1713;
   end record
   with Convention => C_Pass_By_Copy;
end;
```

The patch invokes the existing recursive nested-type prepass before printing a
concrete template record. The executable regression covers both template forms,
compiles their generated Ada, and passes both arrays to C++ at `-O0` and `-O2`
to verify layout as well as syntax.

Run it against an unpatched or patched compiler root:

```sh
./bundles/cxx-ada-template-nested-types/run-test.sh \
  TOOLCHAIN_ROOT GCC_VERSION unpatched
./bundles/cxx-ada-template-nested-types/run-test.sh \
  TOOLCHAIN_ROOT GCC_VERSION patched
```
