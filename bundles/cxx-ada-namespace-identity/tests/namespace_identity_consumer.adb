with Namespace_Identity_C;

procedure Namespace_Identity_Consumer is
   package Bindings renames Namespace_Identity_C;
   First : Bindings.First_Item;
   Second : Bindings.Second_Item;
begin
   if Bindings.First_Item'Object_Size = Bindings.Second_Item'Object_Size then
      null;
   end if;
end Namespace_Identity_Consumer;
