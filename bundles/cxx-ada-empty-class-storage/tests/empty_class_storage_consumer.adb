with Ada.Text_IO;
with Empty_Class_Storage_C;
with Interfaces.C; use Interfaces.C;
with System;

procedure Empty_Class_Storage_Consumer is
   package Bindings renames Empty_Class_Storage_C;
   With_Base : Bindings.With_Empty_Base;
   With_Member : Bindings.With_Empty_Member;
   With_Array : Bindings.With_Empty_Array;
   With_NUA : Bindings.With_No_Unique_Address;
   With_Repeated_NUA : Bindings.With_Repeated_No_Unique_Address;

   function Bytes (Bits : Natural) return unsigned_long is
     (unsigned_long (Bits / System.Storage_Unit));

   procedure Report (Label : String; Matches : Boolean) is
   begin
      Ada.Text_IO.Put_Line (Label & (if Matches then " MATCH" else " MISMATCH"));
   end Report;
begin
   Report
     ("EMPTY",
      Bindings.Empty'Size = 0
      and then Bytes (Bindings.Empty'Object_Size) = Bindings.cpp_empty_size
      and then unsigned_long (Bindings.Empty'Alignment) =
        Bindings.cpp_empty_align);

   Report
     ("METHOD_EMPTY",
      Bytes (Bindings.Class_Method_Empty.Method_Empty'Object_Size) =
        Bindings.cpp_method_empty_size);

   Report
     ("EBO",
      Bytes (Bindings.With_Empty_Base'Object_Size) =
        Bindings.cpp_with_empty_base_size
      and then unsigned_long (With_Base.value'Position) =
        Bindings.cpp_with_empty_base_value_offset);

   Report
     ("MEMBER",
      Bytes (Bindings.With_Empty_Member'Object_Size) =
        Bindings.cpp_with_empty_member_size
      and then unsigned_long (With_Member.member'Position) =
        Bindings.cpp_with_empty_member_member_offset
      and then unsigned_long (With_Member.value'Position) =
        Bindings.cpp_with_empty_member_value_offset);

   Report
     ("ARRAY",
      Bytes (Bindings.With_Empty_Array'Object_Size) =
        Bindings.cpp_with_empty_array_size
      and then unsigned_long (With_Array.values'Position) =
        Bindings.cpp_with_empty_array_values_offset);

   Report
     ("NO_UNIQUE_ADDRESS",
      Bytes (Bindings.With_No_Unique_Address'Object_Size) =
        Bindings.cpp_with_no_unique_address_size
      and then unsigned_long (With_NUA.value'Position) =
        Bindings.cpp_with_no_unique_address_value_offset);

   Report
     ("REPEATED_NO_UNIQUE_ADDRESS",
      Bytes (Bindings.With_Repeated_No_Unique_Address'Object_Size) =
        Bindings.cpp_with_repeated_no_unique_address_size
      and then unsigned_long (With_Repeated_NUA.first'Position) =
        Bindings.cpp_with_repeated_no_unique_address_first_offset
      and then unsigned_long (With_Repeated_NUA.second'Position) =
        Bindings.cpp_with_repeated_no_unique_address_second_offset);
end Empty_Class_Storage_Consumer;
