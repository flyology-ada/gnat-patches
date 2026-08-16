# C++ Ada derived virtual slots

A virtual introduced in a derived C++ class occupies the next primary-vtable
slot after inherited virtuals. The Ada declarations must assign the same slot
to make a class-wide call through the generated binding.

The offending case is ordinary single inheritance; multiple inheritance only
made the failure easier to expose:

```c++
class Base
{
public:
  virtual ~Base () = default;
  virtual int inherited_slot ();
};

class Derived : public Base
{
public:
  ~Derived () override = default;
  int inherited_slot () override;
  virtual int added_slot ();
};
```

The unpatched mapper produces class-specific Ada destructor names:

```ada
package Class_Base is
   procedure Delete_Base (this : access Base);
   procedure Delete_And_Free_Base (this : access Base);
   function inherited_slot (this : access Base) return int;
end;

package Class_Derived is
   procedure Delete_Derived (this : access Derived);
   procedure Delete_And_Free_Derived (this : access Derived);
   function inherited_slot (this : access Derived) return int;
   function added_slot (this : access Derived) return int;
end;
```

Ada treats both derived destructor declarations as new primitives, not
overrides. `added_slot` is assigned two entries later than its C++ slot. In
the regression, the generated class-wide call loads RTTI instead of a function
pointer and terminates abnormally.

The corrected mapper produces hierarchy-stable destructor names, so the
derived declarations override their inherited slots:

```ada
package Class_Base is
   procedure Delete (this : access Base);
   procedure Delete_And_Free (this : access Base);
   function inherited_slot (this : access Base) return int;
end;

package Class_Derived is
   procedure Delete (this : access Derived);
   procedure Delete_And_Free (this : access Derived);
   function inherited_slot (this : access Derived) return int;
   function added_slot (this : access Derived) return int;
end;
```

A user method named `Delete` or `Delete_And_Free` would then collide with the
generated name. The patch gives only such a method a `_Method` suffix while
retaining its original C++ external symbol:

```ada
function Delete_Method (this : access Base'Class) return int
with Import => True,
     Convention => CPP,
     External_Name => "_ZN4Base6DeleteEv";
```

The executable regression proves inherited and newly introduced class-wide
dispatch at `-O0` and `-O2`. The feature panel separately nests a concrete
secondary base that itself has primary and secondary concrete bases. That
case demonstrates the representation strategy: primary bases use Ada
inheritance, secondary bases use nested exact-layout components, and an
access view at each nested component address supplies the appropriate C++
dispatch-table view.
