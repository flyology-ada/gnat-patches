with Ada.Text_IO;
with Ada.Unchecked_Conversion;
with Concrete_Multiple_Inheritance_C;
with Interfaces.C; use Interfaces.C;
with System;
with System.Storage_Elements; use System.Storage_Elements;

procedure Concrete_Multiple_Inheritance_Consumer is
   package Bindings renames Concrete_Multiple_Inheritance_C;
   Object : access Bindings.Class_Both.Both :=
     Bindings.cpp_create_both (10, 20, 3);

   type Right_Base_Access is
     access all Bindings.Class_Right.Right_As_Base;
   type Right_Class_Access is access all Bindings.Class_Right.Right'Class;
   function To_Right is new Ada.Unchecked_Conversion
     (Right_Base_Access, Right_Class_Access);

   Right_Object : constant Right_Class_Access :=
     To_Right (Object.field_2'Unchecked_Access);
   Ada_Right_Offset : constant Storage_Offset :=
     Object.field_2'Address - Object.all'Address;
begin
   if Object = null
     or else Bindings.Class_Both.Both'Object_Size / System.Storage_Unit
       /= Bindings.cpp_both_size
     or else unsigned_long (Ada_Right_Offset)
       /= Bindings.cpp_right_offset (Object)
     or else Bindings.Class_Both.left_value (Object) /= 13
     or else Bindings.Class_Both.right_value (Object) /= 23
     or else Bindings.Class_Right.right_value (Right_Object) /= 23
     or else Bindings.cpp_call_left (Object) /= 13
     or else Bindings.cpp_call_right (Right_Object) /= 23
     or else Bindings.cpp_call_right_from_both (Object) /= 23
   then
      raise Program_Error with "nested concrete base dispatch differs";
   end if;

   Object.l := 30;
   Object.field_2.r := 40;
   Object.both := 5;

   if Bindings.cpp_read_left (Object) /= 30
     or else Bindings.cpp_read_right (Object) /= 40
     or else Bindings.cpp_read_both (Object) /= 5
     or else Bindings.cpp_call_left (Object) /= 35
     or else Bindings.cpp_call_right (Right_Object) /= 45
   then
      raise Program_Error with "nested concrete base storage differs";
   end if;

   Bindings.cpp_delete_both (Object);
   Ada.Text_IO.Put_Line ("MATCH nested concrete multiple inheritance");
end Concrete_Multiple_Inheritance_Consumer;
