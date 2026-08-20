with Interfaces.C; use Interfaces.C;
with Vector_Types_C;

procedure Vector_Types_Consumer is
   package Bindings renames Vector_Types_C;
   use type Bindings.Int_Vector;
   use type Bindings.Double_Vector;

   Int_Input : constant Bindings.Int_Vector := (1, -2, 3, -4);
   Double_Input : constant Bindings.Double_Vector := (1.25, -2.5);
   Object : access Bindings.Class_Vector_Object.Vector_Object :=
     Bindings.create_vector_object;
   Int_Free_Result : constant Bindings.Int_Vector :=
     Bindings.vector_identity (Int_Input);
   Double_Free_Result : constant Bindings.Double_Vector :=
     Bindings.double_vector_identity (Double_Input);
   Wrapper_Result : constant Bindings.Int_Vector :=
     Bindings.cpp_transform_vector (Object, Int_Input);
begin
   if Int_Free_Result /= Int_Input then
      raise Program_Error with "free integer vector ABI mismatch";
   elsif Double_Free_Result /= Double_Input then
      raise Program_Error with "free double vector ABI mismatch";
   elsif Wrapper_Result /= Int_Input then
      raise Program_Error with "C wrapper vector ABI mismatch";
   end if;

   Bindings.delete_vector_object (Object);
end Vector_Types_Consumer;
