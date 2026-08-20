with Interfaces.C; use Interfaces.C;
with Template_Nested_Types_C;

procedure Template_Nested_Types_Consumer is
   package Bindings renames Template_Nested_Types_C;

   Buffer_Value : aliased Bindings.Buffer_Int_4.Buffer :=
     (values => (1, 2, 3, 4));
   Defaults_Value : aliased Bindings.Defaults_Int_2.Defaults :=
     (values => (5, 6));
begin
   if Bindings.buffer_sum (Buffer_Value'Access) /= 10
     or else Bindings.defaults_sum (Defaults_Value'Access) /= 11
   then
      raise Program_Error with "template array layout or binding is wrong";
   end if;
end Template_Nested_Types_Consumer;
