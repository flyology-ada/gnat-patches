with Interfaces.C; use Interfaces.C;
with panel_api_c;
with System;

procedure panel_core_namespaced is
   package Bindings renames panel_api_c;

   function Dispatch
     (Object : access constant
        Bindings.Class_bridge_panel_Base.bridge_panel_Base'Class) return int is
   begin
      return Bindings.Class_bridge_panel_Base.value_Const (Object);
   end Dispatch;

   Object : aliased
     Bindings.Class_bridge_panel_Derived.bridge_panel_Derived :=
       Bindings.Class_bridge_panel_Derived.New_Derived (7, 3);
begin
   if int
     (Bindings.Class_bridge_panel_Base.bridge_panel_Base'Object_Size /
        System.Storage_Unit) /= Bindings.bridge_panel_base_size
     or else int
       (Bindings.Class_bridge_panel_Derived.bridge_panel_Derived'Object_Size /
          System.Storage_Unit) /= Bindings.bridge_panel_derived_size
   then
      raise Program_Error with "unexpected C++ object layout";
   end if;

   if Bindings.Class_bridge_panel_Base.live_objects /= 1 then
      raise Program_Error with "static method mapping failed";
   end if;

   if Dispatch (Object'Access) /= 21 then
      raise Program_Error with "Ada class-wide virtual dispatch failed";
   end if;

   if Bindings.bridge_panel_call_value (Object'Access) /= 21 then
      raise Program_Error with "C++ virtual dispatch failed";
   end if;

   Bindings.Class_bridge_panel_Base.add (Object'Access, 2);
   Bindings.Class_bridge_panel_Base.add (Object'Access, 3, 4);
   if Dispatch (Object'Access) /= 48
     or else Bindings.Class_bridge_panel_Derived.value_Const (Object'Access) /= 48
     or else Bindings.Class_bridge_panel_Derived.scale_Const (Object'Access) /= 3
   then
      raise Program_Error with "inheritance, overload, or field mapping failed";
   end if;

   Bindings.bridge_panel_destroy_derived (Object'Access);
   if Bindings.Class_bridge_panel_Base.live_objects /= 0 then
      raise Program_Error with "destructor mapping failed";
   end if;
end panel_core_namespaced;
