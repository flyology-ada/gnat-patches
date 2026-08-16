with call_abi_c;
with Interfaces.C; use Interfaces.C;
with Interfaces.C.Extensions;

procedure Call_Abi_Consumer is
   package Bindings renames call_abi_c;

   Value : aliased int := 8;
   Original : constant unsigned_long_long := 16#0123_4567_89ab_cdef#;
   Pair_Value : Bindings.Pair := (first => 4, second => 9);
   Number_Value : Bindings.Number;

   function Triple (Argument : int) return int is (Argument * 3)
   with Convention => C;
begin
   if Bindings.invert_bool (Interfaces.C.Extensions.bool'(False)) /=
        Interfaces.C.Extensions.bool'(True)
   then
      raise Program_Error with "bool calling convention mismatch";
   end if;

   if Bindings.add_schar (-5, 8) /= 3 then
      raise Program_Error with "signed char calling convention mismatch";
   end if;

   if Bindings.mix_ull (Original) /=
        (Original xor 16#55aa_55aa_55aa_55aa#)
   then
      raise Program_Error with "unsigned long long calling convention mismatch";
   end if;

   if Bindings.add_float (1.25, 2.5) /= 3.75 then
      raise Program_Error with "float calling convention mismatch";
   end if;

   if Bindings.add_double (1.25, 2.5) /= 3.75 then
      raise Program_Error with "double calling convention mismatch";
   end if;

   if Bindings.add_long_double (1.25, 2.5) /= 3.75 then
      raise Program_Error with "long double calling convention mismatch";
   end if;

   if Bindings.next_color (Bindings.Color_Green) /= Bindings.Color_Blue then
      raise Program_Error with "enum calling convention mismatch";
   end if;

   Pair_Value := Bindings.reverse_pair (Pair_Value);
   if Pair_Value.first /= 9 or else Pair_Value.second /= 4 then
      raise Program_Error with "record-by-value mismatch";
   end if;

   Number_Value := Bindings.integer_number (37);
   if Number_Value.integer_value /= 37 then
      raise Program_Error with "union-by-value mismatch";
   end if;

   if Bindings.dereference (Value'Access) /= 8 then
      raise Program_Error with "const pointer mismatch";
   end if;
   Bindings.increment_reference (Value'Access);
   if Value /= 9 then
      raise Program_Error with "reference mismatch";
   end if;

   if Bindings.invoke_callback (Triple'Access, 7) /= 21 then
      raise Program_Error with "function-pointer callback mismatch";
   end if;
end Call_Abi_Consumer;
