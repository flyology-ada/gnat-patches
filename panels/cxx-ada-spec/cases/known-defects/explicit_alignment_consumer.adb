with Ada.Text_IO;
with explicit_alignment_c;
with Interfaces.C; use Interfaces.C;
with System;

procedure Explicit_Alignment_Consumer is
   package Bindings renames explicit_alignment_c;
   Ada_Size : constant unsigned_long :=
     unsigned_long (Bindings.Aligned'Object_Size / System.Storage_Unit);
   Ada_Alignment : constant unsigned_long :=
     unsigned_long (Bindings.Aligned'Alignment);
begin
   if Ada_Size = Bindings.cpp_size
     and then Ada_Alignment = Bindings.cpp_alignment
   then
      raise Program_Error with "explicit-alignment defect did not reproduce";
   end if;
   Ada.Text_IO.Put_Line ("PASS expected explicit-alignment mismatch");
end Explicit_Alignment_Consumer;
