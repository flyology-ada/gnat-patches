with template_instantiation_qualification_c;
with Ada.Text_IO;

procedure Template_Instantiation_Qualification is
   package Bindings renames template_instantiation_qualification_c;
begin
   if Bindings.Int_Box'Object_Size = 0
     or else Bindings.Alias_Int_Box'Object_Size = 0
   then
      raise Program_Error;
   end if;
   Ada.Text_IO.Put_Line ("PASS C++ Ada template qualification");
end Template_Instantiation_Qualification;
