with Interfaces.C; use Interfaces.C;
with Anonymous_Enums_C;

procedure Anonymous_Enums_Consumer is
   package Bindings renames Anonymous_Enums_C;
begin
   if Bindings.sequential_value (Bindings.Sequential_One) /= 1
     or else Bindings.sparse_value (Bindings.Sparse_Minus) /= -1
     or else Bindings.sparse_value (Bindings.Sparse_Five) /= 5
   then
      raise Program_Error with "anonymous enumeration values were lost";
   end if;
end Anonymous_Enums_Consumer;
