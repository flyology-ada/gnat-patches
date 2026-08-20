with Ada.Text_IO;
with Ada.Unchecked_Conversion;
with Derived_Virtual_Slots_C;
with Interfaces.C; use Interfaces.C;

procedure Derived_Virtual_Slots_Consumer is
   package Bindings renames Derived_Virtual_Slots_C;
   type Derived_Access is access all Bindings.Class_Derived.Derived;
   type Derived_Class_Access is
     access all Bindings.Class_Derived.Derived'Class;
   function To_Class is new Ada.Unchecked_Conversion
     (Derived_Access, Derived_Class_Access);

   Object : constant Derived_Access :=
     Derived_Access (Bindings.create_derived);
   View : constant Derived_Class_Access := To_Class (Object);
begin
   if Object = null then
      raise Program_Error with "C++ factory returned null";
   end if;

   Ada.Text_IO.Put_Line ("CHECK Ada inherited slot");
   Ada.Text_IO.Flush (Ada.Text_IO.Standard_Output);
   if Bindings.Class_Derived.inherited_slot (View) /= 12 then
      raise Program_Error with "Ada inherited virtual dispatch differs";
   end if;

   Ada.Text_IO.Put_Line ("CHECK Ada added slot");
   Ada.Text_IO.Flush (Ada.Text_IO.Standard_Output);
   if Bindings.Class_Derived.added_slot (View) /= 17 then
      raise Program_Error with "Ada added virtual dispatch differs";
   end if;

   if Bindings.cpp_call_inherited (Object) /= 12
     or else Bindings.cpp_call_added (Object) /= 17
   then
      raise Program_Error with "C++ virtual dispatch differs";
   end if;

   Bindings.delete_derived (Object);
   Ada.Text_IO.Put_Line ("MATCH derived virtual slots");
end Derived_Virtual_Slots_Consumer;
