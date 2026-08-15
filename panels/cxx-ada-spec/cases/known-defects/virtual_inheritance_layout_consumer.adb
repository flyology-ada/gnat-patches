with Ada.Text_IO;
with Interfaces.C; use Interfaces.C;
with System;
with virtual_inheritance_layout_c;

procedure Virtual_Inheritance_Layout_Consumer is
   package Bindings renames virtual_inheritance_layout_c;
   Ada_Root_Size : constant unsigned_long :=
     unsigned_long (Bindings.Root'Object_Size / System.Storage_Unit);
   Ada_Virtual_Size : constant unsigned_long :=
     unsigned_long
       (Bindings.Class_Virtual.Virtual'Object_Size / System.Storage_Unit);
   Ada_Virtual_Alignment : constant unsigned_long :=
     unsigned_long (Bindings.Class_Virtual.Virtual'Alignment);
begin
   if Ada_Root_Size /= Bindings.cpp_root_size then
      raise Program_Error with "root layout already differs";
   end if;
   if Ada_Virtual_Size = Bindings.cpp_virtual_size
     and then Ada_Virtual_Alignment = Bindings.cpp_virtual_alignment
   then
      raise Program_Error with "virtual-inheritance defect did not reproduce";
   end if;
   Ada.Text_IO.Put_Line ("PASS expected virtual-inheritance mismatch");
end Virtual_Inheritance_Layout_Consumer;
