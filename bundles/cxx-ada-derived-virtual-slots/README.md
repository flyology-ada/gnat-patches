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
protected:
  int base;
  int reserved;
};

class Derived : public Base
{
public:
  ~Derived () override = default;
  int inherited_slot () override;
  virtual int added_slot ();
private:
  int own;
};
```

The reserved field makes the base consume its complete-object storage, keeping
this regression focused on virtual-slot identity rather than the separate
tail-padding representation problem.

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
   procedure Delete (this : access Derived'Class);
   procedure Delete_And_Free (this : access Derived'Class);
   function inherited_slot (this : access Derived) return int;
   function added_slot (this : access Derived) return int;
end;
```

The class-wide derived destructor form deliberately keeps those direct imports
out of the derived type's primitive set. The two root destructor primitives
already reserve the C++ destructor slots; dispatch through those inherited
slots reaches the derived functions in the object's real C++ vtable. This
leaves `added_slot` at the next C++ slot on every target instead of relying on
Ada override recognition for compiler-generated destructor declarations.

A user method named `Delete` or `Delete_And_Free` would then collide with the
generated name. The patch gives only such a method a `_Method` suffix while
retaining its original C++ external symbol:

```ada
function Delete_Method (this : access Base'Class) return int
with Import => True,
     Convention => CPP,
     External_Name => "_ZN4Base6DeleteEv";
```

The executable regression reinterprets the C++ object pointer as an Ada
class-wide access value, then proves inherited and newly introduced dispatch
at `-O0` and `-O2`. The unchecked pointer view is intentional: C++ RTTI is not
an Ada tag descriptor and therefore cannot support Ada's checked class-membership
conversion. The dispatch itself still reads the C++ object's real vtable.

The feature panel separately nests a concrete
secondary base that itself has primary and secondary concrete bases. That
case demonstrates the representation strategy: primary bases use Ada
inheritance, secondary bases use nested exact-layout components, and an
access view at each nested component address supplies the appropriate C++
dispatch-table view.
