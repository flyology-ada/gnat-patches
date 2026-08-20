# C++ Ada inherited tail padding

C++ may reuse the tail padding of a non-POD base subobject for a derived
member. The Ada mapper currently loses the distinction between the base's
data size and complete-object size, so GNAT places the derived member after
the whole base object.

For example, on the supported 64-bit targets this C++ code gives both classes
a complete-object size of 16 bytes; `extra_` occupies bytes 12 through 15:

```c++
class Tail_Base
{
public:
  Tail_Base (int);
  virtual ~Tail_Base ();
protected:
  int value_;
};

class Tail_Derived : public Tail_Base
{
private:
  int extra_;
};
```

The unpatched mapper produces an Ada parent whose value and object sizes are
both 16 bytes, then appends `extra_u` after it. GNAT therefore makes the
derived object 24 bytes:

```ada
type Tail_Base is tagged limited record
   value_u : aliased int;
end record
with Import => True,
     Convention => CPP;

type Tail_Derived is limited new Tail_Base with record
   extra_u : aliased int;
end record
with Import => True,
     Convention => CPP;
```

The corrected output records the C++ base data size separately from its
complete-object size. Because an Ada extension cannot place a child component
inside its parent's `Object_Size`, a derived class that actually reuses the
tail maps its primary base to a nested as-base storage view:

```ada
for Tail_Base'Size use 96;
for Tail_Base'Object_Size use 128;
for Tail_Base use record
   value_u at 8 range 0 .. 31;
end record;

type Tail_Base_As_Base is record
   value_u : int;
end record
with Convention => C_Pass_By_Copy;
pragma Component_Alignment (Storage_Unit, Tail_Base_As_Base);
for Tail_Base_As_Base'Size use 96;
for Tail_Base_As_Base'Object_Size use 96;
for Tail_Base_As_Base'Alignment use 4;
for Tail_Base_As_Base use record
   value_u at 8 range 0 .. 31;
end record;

type Tail_Derived is limited record
   parent : aliased Tail_Base_As_Base;
   extra_u : aliased int;
end record
with Import => True,
     Convention => CPP;
for Tail_Derived'Size use 128;
for Tail_Derived'Object_Size use 128;
for Tail_Derived use record
   parent at 0 range 0 .. 95;
   extra_u at 12 range 0 .. 31;
end record;
```

Tail reuse is not limited to polymorphic classes. For example:

```c++
struct Plain_Base { short s; char c; Plain_Base (); };
struct Plain_Derived : Plain_Base { char d; };
```

GCC gives `Plain_Base` four complete-object bytes but only three bytes as a
base, places `d` at byte 3, and keeps `sizeof (Plain_Derived) == 4`. The
corrected predicate therefore uses the C++ as-base size for every class and
examines every direct non-virtual base, rather than requiring a tagged class
with exactly one base.

For a three-byte plain base the storage view also uses
`pragma Component_Alignment (Storage_Unit, Plain_Base_As_Base)`, `Size` and
`Object_Size` of 24 bits, and alignment 1. That keeps the base component
addressable without forcing Ada to round its object size back to four bytes.

The nested view deliberately models static C++ storage, not native Ada
inheritance. Operations on the complete derived object still use its imported
C++ profiles; code that needs a typed base view may take the nested component's
address and perform the same explicit access-view conversion described by the
concrete multiple-inheritance bundle.

The executable regression runs at `-O0` and `-O2`. It covers polymorphic,
ordinary single-base, and ordinary multiple-base reuse, compares Ada object
sizes with C++ `sizeof`, writes fields through the Ada view, and reads them
back through C++ methods. The compiler tests also check the exact nested
as-base clauses and reduced component alignment.
