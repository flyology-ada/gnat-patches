with Interfaces.C; use Interfaces.C;
with Interfaces.C.Extensions;
with Member_Pointers_C;

procedure Member_Pointers_Consumer is
   package Bindings renames Member_Pointers_C;
   use type Interfaces.C.Extensions.bool;

   Data : constant Bindings.Data_Member := Bindings.get_data_member;
   Null_Data : constant Bindings.Data_Member := Bindings.get_null_data_member;
   Nonvirtual : constant Bindings.Method_Member :=
     Bindings.get_nonvirtual_method;
   Virtual : constant Bindings.Method_Member := Bindings.get_virtual_method;
   Null_Method : constant Bindings.Method_Member := Bindings.get_null_method;
begin
   if Bindings.apply_data_member (Data) /= 42
     or else Bindings.is_null_data_member (Data)
       /= Interfaces.C.Extensions.bool'(False)
     or else Bindings.is_null_data_member (Null_Data)
       /= Interfaces.C.Extensions.bool'(True)
     or else Bindings.apply_method (Nonvirtual, 5) /= 15
     or else Bindings.apply_method (Virtual, 5) /= 25
     or else Bindings.is_null_method (Null_Method)
       /= Interfaces.C.Extensions.bool'(True)
   then
      raise Program_Error with "pointer-to-member ABI mismatch";
   end if;
end Member_Pointers_Consumer;
