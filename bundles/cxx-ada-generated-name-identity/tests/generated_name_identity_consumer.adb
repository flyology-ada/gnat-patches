with Interfaces.C; use Interfaces.C;
with Generated_Name_Identity_C;

procedure Generated_Name_Identity_Consumer is
   package Bindings renames Generated_Name_Identity_C;
begin
   if Bindings.generated_name_identity_oracle /= 73 then
      raise Program_Error with "generated-name identity oracle mismatch";
   end if;
end Generated_Name_Identity_Consumer;
