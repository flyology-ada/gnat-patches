with Interfaces.C; use Interfaces.C;
with panel_api_c;
with System;

procedure panel_core_namespaced is
   package Bindings renames panel_api_c;

   function Dispatch
     (Object : access constant
        Bindings.bridge_panel.Class_Base.Base'Class) return int is
   begin
      return Bindings.bridge_panel.Class_Base.value_Const (Object);
   end Dispatch;

   Object : aliased
     Bindings.bridge_panel.Class_Derived.Derived :=
       Bindings.bridge_panel.Class_Derived.New_Derived (7, 3);
begin
   if int
     (Bindings.bridge_panel.Class_Base.Base'Object_Size /
        System.Storage_Unit) /= Bindings.bridge_panel.base_size
     or else int
       (Bindings.bridge_panel.Class_Derived.Derived'Object_Size /
          System.Storage_Unit) /= Bindings.bridge_panel.derived_size
   then
      raise Program_Error with "unexpected C++ object layout";
   end if;

   if Bindings.bridge_panel.Class_Base.live_objects /= 1 then
      raise Program_Error with "static method mapping failed";
   end if;

   if Dispatch (Object'Access) /= 21 then
      raise Program_Error with "Ada class-wide virtual dispatch failed";
   end if;

   if Bindings.bridge_panel.call_value (Object'Access) /= 21 then
      raise Program_Error with "C++ virtual dispatch failed";
   end if;

   Bindings.bridge_panel.Class_Base.add (Object'Access, 2);
   Bindings.bridge_panel.Class_Base.add (Object'Access, 3, 4);
   if Dispatch (Object'Access) /= 48
     or else Bindings.bridge_panel.Class_Derived.value_Const (Object'Access) /= 48
     or else Bindings.bridge_panel.Class_Derived.scale_Const (Object'Access) /= 3
   then
      raise Program_Error with "inheritance, overload, or field mapping failed";
   end if;

   Bindings.bridge_panel.destroy_derived (Object'Access);
   if Bindings.bridge_panel.Class_Base.live_objects /= 0 then
      raise Program_Error with "destructor mapping failed";
   end if;
end panel_core_namespaced;
