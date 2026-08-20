with Interfaces.C;
with Int128_Types_C;

procedure Int128_Types_Consumer is
   use type Interfaces.C.int;
   use Int128_Types_C;
begin
   if signed_matches (signed_round_trip (signed_seed)) /= 1 then
      raise Program_Error with "signed __int128 round trip failed";
   end if;

   if unsigned_matches (unsigned_round_trip (unsigned_seed)) /= 1 then
      raise Program_Error with "unsigned __int128 round trip failed";
   end if;
end Int128_Types_Consumer;
