# C++ Ada concrete multiple inheritance

Ada tagged types can have one concrete parent and any number of interface
progenitors, but C++ permits several concrete bases. The mapper currently
prints every tagged C++ base as an Ada progenitor and omits their storage from
the record body.

For example, this class has a primary `Left` subobject, a secondary `Right`
subobject, and a member that reuses `Right`'s complete-object tail padding:

```c++
class Left { virtual int left_value (); int l; };
class Right { virtual int right_value (); int r; };

class Both : public Left, public Right
{
  int left_value () override;
  int right_value () override;
  int both;
};
```

The unpatched mapper produces an illegal Ada derivation. `Right` is a
concrete tagged type, not an interface, and no component describes its
secondary subobject:

```ada
type Both is limited new Left and Right with record
   both : aliased int;
end record
with Import => True,
     Convention => CPP;
```

The corrected mapper uses the address-zero C++ primary base as Ada's one
concrete parent. It emits the secondary base as a nested storage view whose
12-byte size excludes complete-object tail padding, then fixes every visible
component at its C++ ABI offset:

```ada
type Right_As_Base is record
   r : int;
end record
with Convention => C_Pass_By_Copy;
pragma Component_Alignment (Storage_Unit, Right_As_Base);
for Right_As_Base'Size use 96;
for Right_As_Base'Object_Size use 96;
for Right_As_Base'Alignment use 4;
for Right_As_Base use record
   r at 8 range 0 .. 31;
end record;

type Both is limited new Left with record
   field_2 : aliased Right_As_Base;
   both : aliased int;
end record
with Import => True,
     Convention => CPP;
for Both'Object_Size use 256;
for Both use record
   field_2 at 16 range 0 .. 95;
   both at 28 range 0 .. 31;
end record;
```

The storage view intentionally is not another Ada tagged parent. To dispatch
through the secondary C++ base, Ada converts `field_2'Unchecked_Access` from
an access-to-storage type to `access Right'Class` with an instantiation of
`Ada.Unchecked_Conversion`. The address does not change: the secondary vtable
entry performs C++'s required adjustment back to `Both`.

## Interoperability boundary

Fixed-layout concrete multiple inheritance does not require a C++ wrapper for
secondary-base field access or virtual dispatch. Ada can take the address of
the generated nested storage view and dispatch through the converted
`access Right'Class` value directly.

This is ABI-faithful binding support, not native or fully type-safe Ada
multiple inheritance. The conversion is deliberately unchecked, and its
validity depends on the generated component retaining the compiler-provided
C++ subobject offset and layout. The regression uses C++ helpers to construct
and destroy a real C++ object and to provide an independent cross-language
oracle; those helpers are not needed merely to invoke `Right`'s virtual method
from Ada.

A virtual base is different: its address may require a runtime lookup through
the object's C++ ABI metadata. Such a dynamic virtual-base conversion cannot
be represented by a fixed nested component and still requires an imported C++
wrapper or equivalent ABI-aware thunk.

The executable regression runs at `-O0` and `-O2`. It compares C++ `sizeof`
and the secondary-base offset with Ada's object size and component address,
dispatches through the primary, complete, and converted secondary views,
writes every visible field from Ada, and reads all values through C++.
Dynamic virtual-base conversions remain an ABI operation rather than a fixed
nested-component view.
