with Interfaces.C; use Interfaces.C;
with Char8_Type_C;

procedure Char8_Type_Consumer is
   package Bindings renames Char8_Type_C;
   Value : constant unsigned_char := 16#A5#;
begin
   if Bindings.char8_value (Value) /= Value then
      raise Program_Error with "char8_t value did not round-trip";
   end if;
end Char8_Type_Consumer;
