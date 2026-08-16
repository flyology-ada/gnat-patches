with Ada.Text_IO;
with Exception_Interoperability_C;
with Interfaces.C; use Interfaces.C;

procedure Exception_Interoperability_Consumer is
   package Bindings renames Exception_Interoperability_C;
   Handled : Boolean := False;
   Returned : Boolean := False;
begin
   if Bindings.caught_cpp (-1) /= -1
     or else Bindings.caught_cpp (17) /= 17
   then
      raise Program_Error with "C++ exception status facade differs";
   end if;

   begin
      Bindings.throw_cpp;
      Returned := True;
   exception
      when others =>
         Handled := True;
   end;

   if Returned or else not Handled then
      raise Program_Error with "C++ exception did not reach Ada handler";
   end if;

   Ada.Text_IO.Put_Line ("MATCH C++ exception interoperability");
end Exception_Interoperability_Consumer;
