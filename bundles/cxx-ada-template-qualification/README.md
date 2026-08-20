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

An alias-template instance is the subtle GCC 13 case. When that mapper emits a
second package for the alias, it names the Ada type `Alias_Box`, but its
constructor result falls back to the underlying C++ type name, which is
ambiguous between the two used `Box` packages:

```ada
package Alias_Box_int is
   type Alias_Box is limited record
      -- ...
   end record;
   function New_Alias_Box return Box;
end Alias_Box_int;
```

The corrected constructor result uses the type declared in its own package, as
required by Ada's `CPP_Constructor` rule:

```ada
function New_Alias_Box return Alias_Box;
```

The patch finds the nested package that the mapper already generates for each
concrete template instance and qualifies external references with it. It
tracks the current generated package, rather than only the C++ type identity,
because `Alias_Box<int>` and `Box<int>` are the same C++ type but are emitted
under different Ada names. Internal references use the current package's own
type name, while external references use the concrete instance's qualified
name. The patch covers typedefs, ordinary `using` aliases,
alias-template instances, record
fields, function parameters, and function results. References inside the
instance's own package remain unqualified.

GCC 14 and later do not emit that duplicate alias package for this fixture.
The regression therefore requires the exact self-owned constructor result
whenever the package is present, without requiring a declaration that those
versions intentionally omit.

The executable repository regression first asks `g++` to generate the Ada
specification, then compiles and runs an Ada program that depends on it.  The
unpatched test requires GNAT's ambiguous-name rejection; the patched test
requires all five qualified external forms, validates any emitted alias
constructor, and prints `PASS C++ Ada template qualification` at `-O0` and
`-O2`.

The defect was recovered from a local exploratory transcript and independently
reproduced with the pinned GCC 13.2.0, 14.2.0, 15.3.0, 16.1.0, and 16.2.0 toolchains.
`patches/gcc-13-14.patch` and `patches/gcc-15-16.patch` differ only where
the mapper's pretty-printer parameter changed from `buffer` to `pp`.
