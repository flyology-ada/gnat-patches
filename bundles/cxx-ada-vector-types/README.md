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

The `Ada` convention is intentional for a direct vector parameter or result.
GNAT's foreign conventions classify an Ada array as a reference parameter even
after `vector_type` changes its machine mode. Native Ada convention passes the
machine vector directly, matching the C++ target ABI, while `External_Name`
still selects the C++ symbol. A compile-only correction using `Convention =>
CPP` would silently corrupt calls and is rejected by the runtime oracle.

The executable regression round-trips signed integer and double vectors through
C++ at `-O0` and `-O2`, so it checks generated syntax, alignment, register
classification, parameter passing, and return values.

Run it against an unpatched or patched compiler root:

```sh
./bundles/cxx-ada-vector-types/run-test.sh \
  TOOLCHAIN_ROOT GCC_VERSION unpatched
./bundles/cxx-ada-vector-types/run-test.sh \
  TOOLCHAIN_ROOT GCC_VERSION patched
```
