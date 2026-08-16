with Interfaces.C; use Interfaces.C;
with interface_secondary_base_c;

procedure Interface_Secondary_Base_Consumer is
   package Bindings renames interface_secondary_base_c;

   function Dispatch
     (Object : access Bindings.Class_Callback.Callback'Class;
      Value : int) return int is
   begin
      return Bindings.Class_Callback.invoke (Object, Value);
   end Dispatch;

   Object : aliased Bindings.Class_Combined.Combined :=
     Bindings.Class_Combined.New_Combined (7);
begin
   if Bindings.Class_Combined.value (Object'Access) /= 14 then
      raise Program_Error with "primary-base dispatch failed";
   end if;

   if Dispatch (Object'Access, 5) /= 12 then
      raise Program_Error with "Ada interface dispatch failed";
   end if;

   if Bindings.fire (Object'Access, 8) /= 15 then
      raise Program_Error with "secondary-base pointer adjustment failed";
   end if;

   Bindings.destroy_combined (Object'Access);
end Interface_Secondary_Base_Consumer;
