with Namespace_Identity_C;
with Interfaces.C; use Interfaces.C;

procedure Namespace_Identity_Consumer is
   package Bindings renames Namespace_Identity_C;
   First : Bindings.first.inner.Item := (value => 11);
   Second : Bindings.second.inner.Item := (value => 13.0);
   Flat : Bindings.a_b.Marker := (value => 17);
   Nested : Bindings.a.b.Marker := (value => 19.0);
   Reopened : Bindings.first.inner.Again := (value => 23);
begin
   if Bindings.namespace_identity_oracle /= 73
     or else First.value /= 11
     or else Second.value /= 13.0
     or else Flat.value /= 17
     or else Nested.value /= 19.0
     or else Reopened.value /= 23
   then
      raise Program_Error with "nested namespace package mapping failed";
   end if;
end Namespace_Identity_Consumer;
