# C++ Ada empty-class storage

C++ gives a complete empty-class object a nonzero size so distinct objects
have distinct addresses. An empty base may consume no storage, while a named
`[[no_unique_address]]` member remains a real subobject with an address and may
need storage to remain distinct from another member of the same type. The
unpatched mapper loses the complete-object rule.

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

The corrected output separates the zero-size value used for empty-base
optimization from the one-byte complete-object allocation. Artificial empty
base fields are omitted. A named `[[no_unique_address]]` member is retained
when it has distinct storage, but is omitted when C++ actually overlaps it
with another field: Ada rejects overlapping selectable record components.

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

For two same-type overlapping members, C++ requires distinct addresses and
GCC places them at bytes 0 and 1. They do not overlap one another, so both stay
visible as ordinary one-byte Ada components and the two-byte object remains
correct. The mapper therefore does not treat `DECL_FIELD_ABI_IGNORED` as an
unconditional instruction to erase a field; it checks the actual field ranges.

The omitted single `ignored` selector is an access limitation, not hidden
storage drift. Code that must name or take the address of that C++ subobject
needs a C++ accessor wrapper. The direct Ada record still has the correct size
and exposes every non-overlapped field.

The executable regression runs at `-O0` and `-O2`. It compares C++ and Ada
size, alignment, and available field positions for a standalone empty object,
empty-base optimization, an ordinary empty member, an empty-object array, and
C++20 single and repeated `[[no_unique_address]]` members. It also verifies
that only the actually overlapping selector is omitted. A method-bearing empty
class is a known-good control for the separate generated class-package form.
