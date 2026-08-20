# C++ Ada anonymous enums

Top-level anonymous C++ enumerations are represented internally by synthetic
type declarations. The Ada spec dumper skips those declarations as compiler
artifacts, which loses their enumerators and leaves any signature using the
anonymous type with an incomplete `anon_anon_...` declaration.

Both ordinary sequential values and explicitly valued sparse enumerations
reach the broken path:

```c++
enum { Sequential_Zero, Sequential_One };
enum { Sparse_Minus = -1, Sparse_Five = 5 };

extern "C" int
sequential_value (decltype (Sequential_Zero) value);

extern "C" int
sparse_value (decltype (Sparse_Minus) value);
```

The unpatched mapper emits incomplete internal types and no constants (the
numeric suffixes are compiler-internal and vary):

```ada
type anon_anon_0;
function sequential_value (value : anon_anon_0) return int;

type anon_anon_1;
function sparse_value (value : anon_anon_1) return int;
```

The corrected output assigns consistent synthetic Ada type names within the
unit. Sequential values remain an enumeration; sparse or negative values use
an integer subtype and constants so their exact C++ values are preserved (the
numeric suffixes still vary):

```ada
type anon_enum1704 is
  (Sequential_Zero,
   Sequential_One)
with Convention => C;

subtype anon_enum1706 is int;
Sparse_Minus : constant anon_enum1706 := -1;
Sparse_Five : constant anon_enum1706 := 5;

function sequential_value (value : anon_enum1704) return int;
function sparse_value (value : anon_enum1706) return int;
```

The patch emits an anonymous enumeration once, maps every later reference to
the same synthetic name, and retains the original enumerator names in the
enclosing Ada package. The executable regression compiles the generated Ada
and passes sequential, negative, and sparse values to C++ at `-O0` and `-O2`.

Run it against an unpatched or patched compiler root:

```sh
./bundles/cxx-ada-anonymous-enums/run-test.sh \
  TOOLCHAIN_ROOT GCC_VERSION unpatched
./bundles/cxx-ada-anonymous-enums/run-test.sh \
  TOOLCHAIN_ROOT GCC_VERSION patched
```
