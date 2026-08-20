with Interfaces.C; use Interfaces.C;
with Qualified_Method_Names_C;

procedure Qualified_Method_Names_Consumer is
   package Bindings renames Qualified_Method_Names_C;

   Object : aliased Bindings.Class_Accessor.Accessor :=
     Bindings.Class_Accessor.New_Accessor (10);
   Target : aliased Bindings.Class_Value.Value :=
     Bindings.Class_Value.New_Value (20);
   Copy_Source : aliased Bindings.Class_Value.Value :=
     Bindings.Class_Value.New_Value (30);
   Move_Source : aliased Bindings.Class_Value.Value :=
     Bindings.Class_Value.New_Value (40);
   Result : access Bindings.Class_Value.Value;
begin
   if Bindings.Class_Accessor.inspect (Object'Access) /= 11
     or else Bindings.Class_Accessor.inspect_Const (Object'Access) /= 12
     or else Bindings.Class_Accessor.inspect_Volatile (Object'Access) /= 13
     or else Bindings.Class_Accessor.category_Lvalue (Object'Access) /= 14
     or else Bindings.Class_Accessor.category_Rvalue (Object'Access) /= 15
   then
      raise Program_Error with "qualified methods called the wrong symbols";
   end if;

   Result := Bindings.Class_Value.Assign_Value
     (Target'Access, Copy_Source'Access);
   if Bindings.Class_Value.get_Const (Result) /= 30
     or else Bindings.Class_Value.get_Const (Target'Access) /= 30
     or else Bindings.Class_Value.get_Const (Copy_Source'Access) /= 30
   then
      raise Program_Error with "copy assignment mapping failed";
   end if;

   Result := Bindings.Class_Value.Assign_Value_Move
     (Target'Access, Move_Source'Access);
   if Bindings.Class_Value.get_Const (Result) /= 40
     or else Bindings.Class_Value.get_Const (Target'Access) /= 40
     or else Bindings.Class_Value.get_Const (Move_Source'Access) /= -1
   then
      raise Program_Error with "move assignment mapping failed";
   end if;
end Qualified_Method_Names_Consumer;
