# C++ Ada virtual-diamond base storage

A complete C++ object with a virtual base contains that shared base, while the
same class used as a nonvirtual base subobject does not. In a diamond, the
mapper currently declares each direct base component using its larger complete
Ada type, even though C++ allocated only its shortened as-base storage.

For example, on the supported 64-bit Itanium ABI targets each direct base is
16 bytes as a complete object but only 12 bytes inside `Diamond`:

```c++
struct Root { int root_value; };
struct Left : virtual Root { int left_value; };
struct Right : virtual Root { int right_value; };

struct Diamond : Left, Right
{
  int diamond_value;
};
```

The unpatched mapper uses the complete `Left` and `Right` types as components.
Their duplicated virtual `Root` members make Ada's view larger than the C++
object and give the visible fields the wrong addresses:

```ada
type Diamond is limited record
   parent : aliased Left;
   field_2 : aliased Right;
   diamond_value : aliased int;
   field_4 : aliased Root;
end record
with Import => True,
     Convention => CPP;
```

The corrected output emits explicit storage-only views for the shortened base
subobjects. They retain each direct field, omit the shared virtual base, and
use an alignment that their 12-byte object size can satisfy:

```ada
type Left_As_Base is limited record
   left_value : aliased int;
end record
with Convention => C_Pass_By_Copy;
for Left_As_Base'Object_Size use 96;
for Left_As_Base'Alignment use 4;
for Left_As_Base use record
   left_value at 8 range 0 .. 31;
end record;

type Diamond is limited record
   parent : aliased Left_As_Base;
   field_2 : aliased Right_As_Base;
   diamond_value : aliased int;
   field_4 : aliased Root;
end record
with Import => True,
     Convention => CPP;
```

The executable regression runs at `-O0` and `-O2`. C++ constructs a real
diamond and reports its complete size, alignment, and four visible field
offsets. Ada verifies those values, writes through both shortened base views,
the direct member, and the single shared virtual base, and C++ reads all four
values back. Polymorphic concrete secondary bases remain a separate facade
boundary because Ada cannot express their inheritance graph.
