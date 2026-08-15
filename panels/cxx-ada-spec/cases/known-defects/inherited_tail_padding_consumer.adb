with Ada.Text_IO;
with inherited_tail_padding_c;
with Interfaces.C; use Interfaces.C;
with System;

procedure Inherited_Tail_Padding_Consumer is
   package Bindings renames inherited_tail_padding_c;
   Ada_Base_Bytes : constant int :=
     int (Bindings.Class_Tail_Base.Tail_Base'Object_Size /
          System.Storage_Unit);
   Ada_Derived_Bytes : constant int :=
     int (Bindings.Class_Tail_Derived.Tail_Derived'Object_Size /
          System.Storage_Unit);
begin
   if Ada_Base_Bytes /= Bindings.cpp_base_size then
      raise Program_Error with "base layout already differs";
   end if;
   if Ada_Derived_Bytes = Bindings.cpp_derived_size then
      raise Program_Error with "tail-padding layout defect did not reproduce";
   end if;
   Ada.Text_IO.Put_Line ("PASS expected inherited tail-padding mismatch");
end Inherited_Tail_Padding_Consumer;
