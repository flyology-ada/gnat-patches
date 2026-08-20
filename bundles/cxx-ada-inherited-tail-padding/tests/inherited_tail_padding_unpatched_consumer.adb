with Ada.Text_IO;
with Inherited_Tail_Padding_C;
with Interfaces.C; use Interfaces.C;
with System;

procedure Inherited_Tail_Padding_Consumer is
   package Bindings renames Inherited_Tail_Padding_C;

   Object : aliased Bindings.Class_Tail_Derived.Tail_Derived :=
     Bindings.Class_Tail_Derived.New_Tail_Derived (31, 47);
   Ada_Base_Bytes : constant unsigned_long :=
     unsigned_long
       (Bindings.Class_Tail_Base.Tail_Base'Object_Size /
        System.Storage_Unit);
   Ada_Derived_Bytes : constant unsigned_long :=
     unsigned_long
       (Bindings.Class_Tail_Derived.Tail_Derived'Object_Size /
        System.Storage_Unit);
begin
   Object.value_u := 211;
   Object.extra_u := 307;

   if Ada_Base_Bytes = Bindings.cpp_base_size
     and then Ada_Derived_Bytes = Bindings.cpp_derived_size
     and then Bindings.cpp_value (Object'Access) = 211
     and then Bindings.cpp_extra (Object'Access) = 307
   then
      Ada.Text_IO.Put_Line ("MATCH C++ Ada inherited tail padding");
   else
      Ada.Text_IO.Put_Line ("MISMATCH C++ Ada inherited tail padding");
   end if;
end Inherited_Tail_Padding_Consumer;
