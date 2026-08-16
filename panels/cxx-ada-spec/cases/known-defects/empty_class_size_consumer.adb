with Ada.Text_IO;
with Empty_Class_Size_C;
with Interfaces.C; use Interfaces.C;
with System;

procedure Empty_Class_Size_Consumer is
   package Bindings renames Empty_Class_Size_C;
   With_Object : Bindings.With_Empty_Base;

   function Bytes (Bits : Natural) return unsigned_long is
     (unsigned_long (Bits / System.Storage_Unit));
begin
   if Bytes (Bindings.Empty'Object_Size) = Bindings.cpp_empty_size then
      raise Program_Error with "empty-class size defect did not reproduce";
   end if;

   if Bytes (Bindings.With_Empty_Base'Object_Size) /=
        Bindings.cpp_with_empty_base_size
     or else unsigned_long (With_Object.value'Position) /=
       Bindings.cpp_with_empty_base_value_offset
   then
      raise Program_Error with "empty-base optimization also differs";
   end if;

   Ada.Text_IO.Put_Line
     ("PASS expected standalone empty-class mismatch with matching EBO");
end Empty_Class_Size_Consumer;
