with Ada.Text_IO;
with Explicit_Alignment_C;
with Interfaces.C; use Interfaces.C;
with System;

procedure Explicit_Alignment_Consumer is
   package Bindings renames Explicit_Alignment_C;
   Ada_Size : constant unsigned_long :=
     unsigned_long (Bindings.Aligned'Object_Size / System.Storage_Unit);
   Ada_Alignment : constant unsigned_long :=
     unsigned_long (Bindings.Aligned'Alignment);
begin
   if Ada_Size = Bindings.cpp_size
     and then Ada_Alignment = Bindings.cpp_alignment
   then
      Ada.Text_IO.Put_Line ("MATCH C++ Ada explicit alignment");
   else
      Ada.Text_IO.Put_Line ("MISMATCH C++ Ada explicit alignment");
   end if;
end Explicit_Alignment_Consumer;
