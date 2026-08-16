with Ada.Text_IO;
with Ada.Unchecked_Conversion;
with Interfaces.C; use Interfaces.C;
with Recursive_Secondary_Base_C;
with System;
with System.Storage_Elements; use System.Storage_Elements;

procedure Recursive_Secondary_Base_Consumer is
   package Bindings renames Recursive_Secondary_Base_C;
   Object : access Bindings.Class_Most.Most := Bindings.create_most;

   type Secondary_Storage_Access is
     access all Bindings.Class_Secondary.Secondary;
   type Secondary_Class_Access is
     access all Bindings.Class_Secondary.Secondary'Class;
   function To_Secondary is new Ada.Unchecked_Conversion
     (Secondary_Storage_Access, Secondary_Class_Access);

   type Extra_Base_Access is
     access all Bindings.Class_Extra.Extra_As_Base;
   type Extra_Class_Access is access all Bindings.Class_Extra.Extra'Class;
   function To_Extra is new Ada.Unchecked_Conversion
     (Extra_Base_Access, Extra_Class_Access);

   Secondary_Object : constant Secondary_Class_Access :=
     To_Secondary (Object.field_2'Unchecked_Access);
   Extra_Object : constant Extra_Class_Access :=
     To_Extra (Object.field_2.field_2'Unchecked_Access);
   Ada_Secondary_Offset : constant Storage_Offset :=
     Object.field_2'Address - Object.all'Address;
   Ada_Extra_Offset : constant Storage_Offset :=
     Object.field_2.field_2'Address - Object.all'Address;
begin
   if Object = null
     or else Bindings.Class_Most.Most'Object_Size / System.Storage_Unit
       /= Bindings.most_size
     or else unsigned_long (Ada_Secondary_Offset)
       /= Bindings.secondary_offset (Object)
     or else unsigned_long (Ada_Extra_Offset)
       /= Bindings.extra_offset (Object)
     or else Bindings.Class_Secondary.root_value (Secondary_Object) /= 25
     or else Bindings.Class_Secondary.extra_value (Secondary_Object) /= 35
     or else Bindings.Class_Extra.extra_value (Extra_Object) /= 35
     or else Bindings.call_root (Secondary_Object) /= 25
     or else Bindings.call_extra (Extra_Object) /= 35
   then
      raise Program_Error with "recursive secondary-base dispatch differs";
   end if;

   Object.primary := 11;
   Object.field_2.root := 21;
   Object.field_2.field_2.extra := 31;
   Object.field_2.own := 6;
   Object.final := 7;

   if Bindings.read_values (Object) /= 76
     or else Bindings.call_root (Secondary_Object) /= 28
     or else Bindings.call_extra (Extra_Object) /= 38
   then
      raise Program_Error with "recursive secondary-base storage differs";
   end if;

   Bindings.delete_most (Object);
   Ada.Text_IO.Put_Line ("MATCH recursive concrete secondary bases");
end Recursive_Secondary_Base_Consumer;
