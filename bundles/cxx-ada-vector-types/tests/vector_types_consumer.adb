with Interfaces.C; use Interfaces.C;
with Vector_Types_C;

procedure Vector_Types_Consumer is
   package Bindings renames Vector_Types_C;
   use type Bindings.Int_Vector;
   use type Bindings.Double_Vector;

   Int_Input : constant Bindings.Int_Vector := (1, -2, 3, -4);
   Double_Input : constant Bindings.Double_Vector := (1.25, -2.5);
begin
   if Bindings.vector_identity (Int_Input) /= Int_Input
     or else Bindings.double_vector_identity (Double_Input) /= Double_Input
   then
      raise Program_Error with "machine vector ABI mismatch";
   end if;
end Vector_Types_Consumer;
