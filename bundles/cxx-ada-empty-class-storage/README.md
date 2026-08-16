# C++ Ada empty-class storage

C++ gives a complete empty-class object a nonzero size so distinct objects
have distinct addresses, but the same type may consume no storage as an empty
base or as an empty `[[no_unique_address]]` member. The unpatched mapper loses
the complete-object rule.

For example, this code combines all three forms with ordinary member and array
storage:

```c++
struct Empty {};

struct With_Empty_Base : Empty
{
  int value;
};

struct With_Empty_Member
{
  Empty member;
  int value;
};

struct With_No_Unique_Address
{
  [[no_unique_address]] Empty ignored;
  int value;
};
```

The unpatched mapper gives `Empty` a zero `Object_Size`. That happens to make
the base, array, and `[[no_unique_address]]` layouts agree through GNAT's
existing component padding, but standalone objects and ordinary empty members
are too small:

```ada
type Empty is record
   null;
end record
with Convention => C_Pass_By_Copy;

type With_Empty_Base is record
   parent : aliased Empty;
   value : aliased int;
end record
with Convention => C_Pass_By_Copy;

type With_No_Unique_Address is record
   ignored : aliased Empty;
   value : aliased int;
end record
with Convention => C_Pass_By_Copy;
```

The corrected output separates the zero-size value used for overlapping
subobjects from the one-byte complete-object allocation. ABI-ignored empty
bases and members are omitted from the Ada storage view; ordinary empty
members remain present and therefore consume their required byte:

```ada
type Empty is record
   null;
end record
with Convention => C_Pass_By_Copy;

for Empty'Size use 0;
for Empty'Object_Size use 8;

type With_Empty_Base is record
   value : aliased int;
end record
with Convention => C_Pass_By_Copy;

type With_Empty_Member is record
   member : aliased Empty;
   value : aliased int;
end record
with Convention => C_Pass_By_Copy;

type With_No_Unique_Address is record
   value : aliased int;
end record
with Convention => C_Pass_By_Copy;
```

The executable regression runs at `-O0` and `-O2`. It compares C++ and Ada
size, alignment, and field positions for a standalone empty object, empty-base
optimization, an ordinary empty member, an empty-object array, and a C++20
`[[no_unique_address]]` member. A method-bearing empty class is a known-good
control for the separate generated class-package form.
