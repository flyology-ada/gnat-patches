with Ada.Text_IO;
with Interfaces.C; use Interfaces.C;
with System;
with Virtual_Inheritance_Layout_C;

procedure Virtual_Inheritance_Layout_Consumer is
   package Bindings renames Virtual_Inheritance_Layout_C;
   subtype Virtual is Bindings.Class_Virtual.Virtual;
   Object : access Virtual := Bindings.cpp_create (101, 202);

   function Bytes (Bits : Natural) return unsigned_long is
     (unsigned_long (Bits / System.Storage_Unit));

   Layout_Matches : constant Boolean :=
     Bytes (Virtual'Object_Size) = Bindings.cpp_virtual_size
     and then unsigned_long (Virtual'Alignment) =
       Bindings.cpp_virtual_alignment
     and then unsigned_long (Object.derived_value'Position) =
       Bindings.cpp_derived_offset
     and then unsigned_long (Object.field_2'Position) =
       Bindings.cpp_root_offset;
begin
   if Object = null
     or else Bytes (Bindings.Root'Object_Size) /= Bindings.cpp_root_size
     or else Bindings.cpp_root_value (Object) /= 101
     or else Bindings.cpp_derived_value (Object) /= 202
   then
      raise Program_Error with "C++ virtual object setup differs";
   end if;

   if Layout_Matches then
      Object.derived_value := 303;
      Object.field_2.root_value := 404;
      if Bindings.cpp_derived_value (Object) /= 303
        or else Bindings.cpp_root_value (Object) /= 404
      then
         raise Program_Error with "Ada writes use the wrong virtual layout";
      end if;
      Ada.Text_IO.Put_Line ("MATCH C++ Ada virtual inheritance");
   else
      Ada.Text_IO.Put_Line ("MISMATCH C++ Ada virtual inheritance");
   end if;

   Bindings.cpp_delete (Object);
end Virtual_Inheritance_Layout_Consumer;
