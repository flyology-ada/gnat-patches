with Interfaces.C; use Interfaces.C;
with System;
with abi_layout_c;

procedure Abi_Layout_Consumer is
   package Bindings renames abi_layout_c;

   Plain_Object : Bindings.Plain;
   Packed_Object : Bindings.Packed;

   function Bytes (Bits : Natural) return unsigned_long is
     (unsigned_long (Bits / System.Storage_Unit));

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Check;
begin
   Check (Bytes (Bindings.Plain'Object_Size) = Bindings.cpp_size_plain,
          "Plain size differs");
   Check (unsigned_long (Bindings.Plain'Alignment) = Bindings.cpp_align_plain,
          "Plain alignment differs");
   Check (unsigned_long (Plain_Object.integer_value'Position) =
            Bindings.cpp_offset_plain_integer,
          "Plain integer offset differs");
   Check (unsigned_long (Plain_Object.real_value'Position) =
            Bindings.cpp_offset_plain_real,
          "Plain real offset differs");
   Check (Bytes (Bindings.Overlay'Object_Size) = Bindings.cpp_size_overlay,
          "Overlay size differs");
   Check (unsigned_long (Bindings.Overlay'Alignment) =
            Bindings.cpp_align_overlay,
          "Overlay alignment differs");
   Check (Bytes (Bindings.Bits'Object_Size) = Bindings.cpp_size_bits,
          "Bits size differs");
   Check (unsigned_long (Bindings.Bits'Alignment) = Bindings.cpp_align_bits,
          "Bits alignment differs");
   Check (Bytes (Bindings.Packed'Object_Size) = Bindings.cpp_size_packed,
          "Packed size differs");
   Check (unsigned_long (Bindings.Packed'Alignment) = Bindings.cpp_align_packed,
          "Packed alignment differs");
   Check (unsigned_long (Packed_Object.integer_value'Position) =
            Bindings.cpp_offset_packed_integer,
          "Packed integer offset differs");
   Check (Bytes (Bindings.Matrix'Object_Size) = Bindings.cpp_size_matrix,
          "Matrix size differs");
   Check (unsigned_long (Bindings.Matrix'Alignment) = Bindings.cpp_align_matrix,
          "Matrix alignment differs");
end Abi_Layout_Consumer;
