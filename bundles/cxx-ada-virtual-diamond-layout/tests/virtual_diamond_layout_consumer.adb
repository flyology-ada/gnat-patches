with Ada.Text_IO;
with Interfaces.C; use Interfaces.C;
with System;
with Virtual_Diamond_Layout_C;

procedure Virtual_Diamond_Layout_Consumer is
   package Bindings renames Virtual_Diamond_Layout_C;
   subtype Diamond is Bindings.Class_Diamond.Diamond;
   Object : access Diamond := Bindings.cpp_diamond_create (11, 22, 33, 44);

   function Bytes (Bits : Natural) return unsigned_long is
     (unsigned_long (Bits / System.Storage_Unit));

   Layout_Matches : constant Boolean :=
     Bytes (Diamond'Object_Size) = Bindings.cpp_diamond_size
     and then unsigned_long (Diamond'Alignment) =
       Bindings.cpp_diamond_alignment
     and then unsigned_long
       (Object.parent'Position + Object.parent.left_value'Position) =
       Bindings.cpp_diamond_left_offset
     and then unsigned_long
       (Object.field_2'Position + Object.field_2.right_value'Position) =
       Bindings.cpp_diamond_right_offset
     and then unsigned_long (Object.diamond_value'Position) =
       Bindings.cpp_diamond_value_offset
     and then unsigned_long (Object.field_4'Position) =
       Bindings.cpp_diamond_root_offset;
begin
   if Object = null
     or else Bytes (Bindings.Diamond_Root'Object_Size) /=
       Bindings.cpp_diamond_root_size
     or else Bindings.cpp_diamond_root_value (Object) /= 11
     or else Bindings.cpp_diamond_left_value (Object) /= 22
     or else Bindings.cpp_diamond_right_value (Object) /= 33
     or else Bindings.cpp_diamond_value (Object) /= 44
   then
      raise Program_Error with "C++ virtual diamond setup differs";
   end if;

   if not Layout_Matches then
      raise Program_Error with "C++ and Ada virtual diamond layouts differ";
   end if;

   Object.parent.left_value := 55;
   Object.field_2.right_value := 66;
   Object.diamond_value := 77;
   Object.field_4.root_value := 88;
   if Bindings.cpp_diamond_left_value (Object) /= 55
     or else Bindings.cpp_diamond_right_value (Object) /= 66
     or else Bindings.cpp_diamond_value (Object) /= 77
     or else Bindings.cpp_diamond_root_value (Object) /= 88
   then
      raise Program_Error with "Ada writes use the wrong diamond layout";
   end if;

   Bindings.cpp_diamond_delete (Object);
   Ada.Text_IO.Put_Line ("MATCH C++ Ada virtual diamond layout");
end Virtual_Diamond_Layout_Consumer;
