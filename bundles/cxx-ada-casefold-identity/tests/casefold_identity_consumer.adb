with Interfaces.C; use Interfaces.C;
with Casefold_Identity_C;

procedure Casefold_Identity_Consumer is
   package Bindings renames Casefold_Identity_C;

   First : Bindings.Item := (value => 7);
   Second : Bindings.ITEM_Case_2 := (value => 8.0);
   Pair : Bindings.Fields :=
     (value => 11, VALUE_Case_2 => 13, VaLuE_Case_3 => 17);
begin
   if Bindings.measure (First) /= 7
     or else Bindings.MEASURE_Case_2 (Second) /= 8
     or else Bindings.combine (Pair) /= 41
   then
      raise Program_Error with "case-distinct C++ symbols were conflated";
   end if;
end Casefold_Identity_Consumer;
