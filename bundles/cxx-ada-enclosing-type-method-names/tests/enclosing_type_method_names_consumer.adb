with Ada.Text_IO;
with Enclosing_Type_Method_Names_C;
with Interfaces.C; use Interfaces.C;

procedure Enclosing_Type_Method_Names_Consumer is
   package Bindings renames Enclosing_Type_Method_Names_C;
   Left_Object : access Bindings.Class_Left.Left :=
     Bindings.cpp_create_left (41);
   Right_Object : access Bindings.Class_Right.Right :=
     Bindings.cpp_create_right (73);
begin
   if Left_Object = null or else Right_Object = null
     or else Bindings.Class_Left.left_Method (Left_Object) /= 41
     or else Bindings.Class_Right.right_Method (Right_Object) /= 73
   then
      raise Program_Error with "renamed C++ method call differs";
   end if;

   Bindings.cpp_delete_left (Left_Object);
   Bindings.cpp_delete_right (Right_Object);
   Ada.Text_IO.Put_Line ("MATCH enclosing type and method names");
end Enclosing_Type_Method_Names_Consumer;
