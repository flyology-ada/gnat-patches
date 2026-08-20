with Ada.Text_IO;
with Profile_Formal_Type_Names_C;
with Interfaces.C; use Interfaces.C;

procedure Profile_Formal_Type_Names_Consumer is
   package Bindings renames Profile_Formal_Type_Names_C;
   Object : access Bindings.Result := Bindings.make_result (41);
begin
   if Object = null or else Bindings.inspect (7, Object) /= 48 then
      raise Program_Error with "profile formal/type collision changed result";
   end if;

   Bindings.delete_result (Object);
   Ada.Text_IO.Put_Line ("MATCH profile formal and type names");
end Profile_Formal_Type_Names_Consumer;
