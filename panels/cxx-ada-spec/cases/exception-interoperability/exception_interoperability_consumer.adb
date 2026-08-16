with Ada.Text_IO;
with Exception_Interoperability_C;
with GNAT.Exception_Actions;
with Interfaces.C; use Interfaces.C;

procedure Exception_Interoperability_Consumer is
   package Bindings renames Exception_Interoperability_C;
   use type GNAT.Exception_Actions.Exception_Languages;
   Handled : Boolean := False;
begin
   if Bindings.caught_cpp (-1) /= -1
     or else Bindings.caught_cpp (17) /= 17
   then
      raise Program_Error with "C++ exception status facade differs";
   end if;

   begin
      Bindings.throw_cpp;
      raise Program_Error with "C++ exception did not propagate";
   exception
      when Occurrence : others =>
         if not GNAT.Exception_Actions.Is_Foreign_Exception (Occurrence)
           or else GNAT.Exception_Actions.Exception_Language (Occurrence)
             /= GNAT.Exception_Actions.EL_Cpp
         then
            raise Program_Error with "C++ exception lost foreign identity";
         end if;
         Handled := True;
   end;

   if not Handled then
      raise Program_Error with "C++ exception handler did not run";
   end if;

   Ada.Text_IO.Put_Line ("MATCH C++ exception interoperability");
end Exception_Interoperability_Consumer;
