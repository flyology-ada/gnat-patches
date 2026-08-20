with Ada.Text_IO;
with Interfaces.C; use Interfaces.C;
with Uninstantiated_Templates_C;

procedure Uninstantiated_Templates_Consumer is
   package Bindings renames Uninstantiated_Templates_C;
   Object : aliased Bindings.Visible := (value => 37);
begin
   if Bindings.visible_value (Object'Access) /= 37 then
      raise Program_Error with "visible declaration changed value";
   end if;
   Ada.Text_IO.Put_Line ("MATCH uninstantiated template boundary");
end Uninstantiated_Templates_Consumer;
