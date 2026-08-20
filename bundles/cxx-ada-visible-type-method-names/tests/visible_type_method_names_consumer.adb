with Ada.Text_IO;
with Interfaces.C; use Interfaces.C;
with Visible_Type_Method_Names_C;

procedure Visible_Type_Method_Names_Consumer is
   package Bindings renames Visible_Type_Method_Names_C;
   Widget_Object : access Bindings.Class_Widget.Widget :=
     Bindings.cpp_create_widget (41);
   Result_Object : access Bindings.Class_Result.Result :=
     Bindings.cpp_create_result (73);
begin
   if Widget_Object = null or else Result_Object = null
     or else Bindings.Class_Widget.result_Method (Widget_Object) /= 41
     or else Result_Object.value /= 73
   then
      raise Program_Error with "visible type/method collision changed values";
   end if;

   Bindings.cpp_delete_widget (Widget_Object);
   Bindings.cpp_delete_result (Result_Object);
   Ada.Text_IO.Put_Line ("MATCH visible type and method names");
end Visible_Type_Method_Names_Consumer;
