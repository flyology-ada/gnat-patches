with Ada.Text_IO;
with Derived_Virtual_Slots_C;
with Interfaces.C; use Interfaces.C;

procedure Derived_Virtual_Slots_Consumer is
   package Bindings renames Derived_Virtual_Slots_C;
   Object : access Bindings.Class_Derived.Derived := Bindings.create_derived;
   View : access Bindings.Class_Derived.Derived'Class := Object;
begin
   if Object = null
     or else Bindings.Class_Derived.inherited_slot (View) /= 12
     or else Bindings.Class_Derived.added_slot (View) /= 17
     or else Bindings.cpp_call_inherited (Object) /= 12
     or else Bindings.cpp_call_added (Object) /= 17
   then
      raise Program_Error with "derived virtual dispatch differs";
   end if;

   Bindings.delete_derived (Object);
   Ada.Text_IO.Put_Line ("MATCH derived virtual slots");
end Derived_Virtual_Slots_Consumer;
