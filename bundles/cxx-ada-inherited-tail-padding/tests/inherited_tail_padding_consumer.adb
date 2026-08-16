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
   Plain : access Bindings.Class_Plain_Derived.Plain_Derived :=
     Bindings.cpp_plain_create;
   Both : access Bindings.Class_Plain_Both.Plain_Both :=
     Bindings.cpp_both_create;
begin
   Object.parent.value_u := 211;
   Object.extra_u := 307;

   if Ada_Base_Bytes = Bindings.cpp_base_size
     and then Ada_Derived_Bytes = Bindings.cpp_derived_size
     and then Bindings.cpp_value (Object'Access) = 211
     and then Bindings.cpp_extra (Object'Access) = 307
     and then unsigned_long
       (Bindings.Class_Plain_Derived.Plain_Derived'Object_Size /
        System.Storage_Unit) = Bindings.cpp_plain_size
     and then unsigned_long
       (Bindings.Class_Plain_Both.Plain_Both'Object_Size /
        System.Storage_Unit) = Bindings.cpp_both_plain_size
   then
      Plain.parent.base_short := 11;
      Plain.parent.base_char := Interfaces.C.char'Val (13);
      Plain.derived_char := Interfaces.C.char'Val (17);
      Both.parent.left_short := 19;
      Both.parent.left_char := Interfaces.C.char'Val (23);
      Both.field_2.right_short := 29;
      Both.field_2.right_char := Interfaces.C.char'Val (31);
      Both.extra := Interfaces.C.char'Val (37);

      if Bindings.cpp_plain_values (Plain) /= 41
        or else Bindings.cpp_both_values (Both) /= 139
      then
         raise Program_Error with "non-polymorphic tail padding mismatch";
      end if;

      Ada.Text_IO.Put_Line ("MATCH C++ Ada inherited tail padding");
   else
      Ada.Text_IO.Put_Line ("MISMATCH C++ Ada inherited tail padding");
   end if;

   Bindings.cpp_plain_delete (Plain);
   Bindings.cpp_both_delete (Both);
end Inherited_Tail_Padding_Consumer;
