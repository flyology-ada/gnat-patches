# C++ Ada machine vector types

GCC represents fixed-size C++ vectors as `VECTOR_TYPE`, but the Ada spec
dumper prints the placeholder `<vector>`. Both typedef declarations and every
function signature using them are therefore invalid Ada.

The offending C++ includes integer and floating-point vectors passed and
returned by value:

```c++
typedef int Int_Vector __attribute__((vector_size(16)));
typedef double Double_Vector __attribute__((vector_size(16)));

Int_Vector vector_identity (Int_Vector value);
Double_Vector double_vector_identity (Double_Vector value);
```

The unpatched mapper produces placeholders rather than types:

```ada
subtype Int_Vector is <vector>;
subtype Double_Vector is <vector>;

function vector_identity (value : <vector>) return <vector>;
function double_vector_identity (value : <vector>) return <vector>;
```

The corrected output declares fixed arrays with the vector's exact element
count and alignment, marks them as GNAT machine vectors, and reuses their names
in signatures:

```ada
type Int_Vector is array (0 .. 3) of int;
for Int_Vector'Alignment use 16;
pragma Machine_Attribute (Int_Vector, "vector_type");

type Double_Vector is array (0 .. 1) of double;
for Double_Vector'Alignment use 16;
pragma Machine_Attribute (Double_Vector, "vector_type");

function vector_identity (value : Int_Vector) return Int_Vector
with Import => True,
     Convention => Ada,
     External_Name => "_Z15vector_identityDv4_i";
```

Free and C-wrapper vector profiles use `Convention => Ada`, whose native
machine-vector mode matches the target C++ vector ABI without first treating
the representative Ada array as a foreign aggregate.

Vector-bearing C++ methods are a separate ABI boundary. They must retain
`Convention => CPP` so GNAT preserves C++ method and dispatch-table identity,
but direct class-wide calls are not portable: GNAT releases and targets differ
on whether the Ada array is classified before or after `vector_type` changes
its machine mode. Both conventions have produced wrong values in the tested
GCC 13 and 14 matrix. The portable binding is a C++ wrapper:

```c++
extern "C" Int_Vector
cpp_transform_vector (Vector_Object *object, Int_Vector value)
{
  return object->transform (value);
}
```

```ada
function cpp_transform_vector
  (object : access Class_Vector_Object.Vector_Object;
   value : Int_Vector) return Int_Vector
with Import => True,
     Convention => Ada,
     External_Name => "cpp_transform_vector";
```

The wrapper still executes the real C++ virtual call; only the unstable
cross-language method-call sequence stays on the C++ side.

Scalable SVE/RVV vectors do not have a compile-time lane count and cannot be
described by an Ada fixed array. The mapper checks `TYPE_VECTOR_SUBPARTS`
before reading it and emits the explicit `<scalable_vector>` unsupported marker
instead of asserting or silently using the minimum runtime lane count.

The executable regression round-trips signed integer and double vectors through
free functions and a C wrapper around a virtual C++ call at `-O0` and `-O2`, so
it checks generated syntax, alignment, register classification, parameter
passing, return values, and preserved C++ method identity. A target-specific
GCC test covers the scalable-vector guard.

Run it against an unpatched or patched compiler root:

```sh
./bundles/cxx-ada-vector-types/run-test.sh \
  TOOLCHAIN_ROOT GCC_VERSION unpatched
./bundles/cxx-ada-vector-types/run-test.sh \
  TOOLCHAIN_ROOT GCC_VERSION patched
```
