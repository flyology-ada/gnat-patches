with Ada.Text_IO;
with Interfaces.C; use Interfaces.C;
with Interfaces.C.Strings;
with Stdlib_Facade_C;

procedure Stdlib_Facade_Consumer is
   Text : Interfaces.C.Strings.chars_ptr :=
     Interfaces.C.Strings.New_String ("Ada and C++");
begin
   if Stdlib_Facade_C.string_length (Text, 11) /= 11 then
      raise Program_Error with "std::string facade changed length";
   end if;
   Interfaces.C.Strings.Free (Text);
   Ada.Text_IO.Put_Line ("MATCH nontrivial standard-library facade");
end Stdlib_Facade_Consumer;
