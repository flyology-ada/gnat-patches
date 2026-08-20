# C++ Ada virtual-inheritance layout

The Itanium C++ ABI gives a class with a virtual base an internal virtual-base
table pointer and places the shared base subobject at a runtime-defined offset.
The mapper emits the visible members but currently discards their C++
positions, size, and alignment.

For example, on the supported 64-bit targets this class is 16 bytes, aligned
to 8 bytes, with `derived_value` at byte 8 and the virtual `Root` subobject at
byte 12:

```c++
struct Root
{
  int root_value;
};

struct Virtual : virtual Root
{
  int derived_value;
};
```

The unpatched mapper omits the internal pointer and lets Ada place both visible
components from byte zero. The generated object is therefore only 8 bytes and
aligned to 4:

```ada
type Virtual is limited record
   derived_value : aliased int;
   field_2 : aliased Root;
end record
with Import => True,
     Convention => CPP;
```

The corrected output leaves the internal pointer as an opaque gap while fixing
the complete size, alignment, and both visible components at their C++ ABI
positions:

```ada
for Virtual'Size use 128;
for Virtual'Object_Size use 128;
for Virtual'Alignment use 8;
for Virtual use record
   derived_value at 8 range 0 .. 31;
   field_2 at 12 range 0 .. 31;
end record;
```

The executable regression runs at `-O0` and `-O2`. C++ constructs the object so
its hidden virtual-base pointer is valid. Ada then checks the complete layout,
writes the direct member and virtual-base member through the generated view,
and C++ reads both values back through virtual-base-aware access paths.
