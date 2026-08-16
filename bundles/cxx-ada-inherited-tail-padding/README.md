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
complete-object size and fixes each visible field at its C++ position:

```ada
for Tail_Base'Size use 96;
for Tail_Base'Object_Size use 128;
for Tail_Base use record
   value_u at 8 range 0 .. 31;
end record;

for Tail_Derived'Size use 128;
for Tail_Derived'Object_Size use 128;
for Tail_Derived use record
   extra_u at 12 range 0 .. 31;
end record;
```

GNAT already expands assignments of fully represented tagged parents
component by component so a child may safely occupy a parent gap. The patch
permits that overlap without the internal `-gnatd.K` switch only when both
types are imported C++ classes. Ordinary Ada extensions retain the existing
overlap rejection.

The executable regression runs at `-O0` and `-O2`. It compares both Ada object
sizes with C++ `sizeof`, writes the inherited and derived fields through the
Ada view, and reads them back through C++ methods. The compiler tests also
check the emitted clauses and the narrowly permitted GNAT layout.
