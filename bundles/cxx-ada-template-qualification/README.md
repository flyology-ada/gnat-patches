# C++ Ada template-instance qualification

The C++ `-fdump-ada-spec` mapper emits each concrete class-template
instantiation in a nested Ada package, then adds a `use` clause for every
such package.  References to an instance outside its package are emitted with
only the class name.  Once two instantiations exist, those references are
ambiguous and the generated Ada specification cannot compile.

For example, this C++ declaration creates two concrete instances and refers to
them outside their generated packages:

```c++
extern template class Box<int>;
extern template class Box<double>;

using Int_Box = Box<int>;
template <typename T> using Alias_Box = Box<T>;
using Alias_Int_Box = Alias_Box<int>;
struct Holder { Box<int> item; };
Box<double> identity (Box<double> value);
```

The unpatched mapper loses the instance packages:

```ada
subtype Int_Box is Box;
subtype Alias_Int_Box is Alias_Box;
item : aliased Box;
function identity (value : Box) return Box;
```

Because both `Box_int` and `Box_double` are made directly visible, `Box` is
ambiguous. The corrected output names the owning package at every external
reference:

```ada
subtype Int_Box is Box_int.Box;
subtype Alias_Int_Box is Box_int.Box;
item : aliased Box_int.Box;
function identity
  (value : Box_double.Box) return Box_double.Box;
```

The patch finds the nested package that the mapper already generates for each
concrete template instance and qualifies external references with it.  It
covers typedefs, ordinary `using` aliases, alias-template instances, record
fields, function parameters, and function results. References inside the
instance's own package remain unqualified.

The executable repository regression first asks `g++` to generate the Ada
specification, then compiles and runs an Ada program that depends on it.  The
unpatched test requires GNAT's ambiguous-name rejection; the patched test
requires all four qualified forms and prints
`PASS C++ Ada template qualification` at `-O0` and `-O2`.

The defect was recovered from a local exploratory transcript and independently
reproduced with the pinned GCC 13.2.0, 14.2.0, 15.3.0, 16.1.0, and 16.2.0 toolchains.
`patches/gcc-13-14.patch` and `patches/gcc-15-16.patch` differ only where
the mapper's pretty-printer parameter changed from `buffer` to `pp`.
