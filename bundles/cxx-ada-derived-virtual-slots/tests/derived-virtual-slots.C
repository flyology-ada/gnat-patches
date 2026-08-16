/* { dg-do compile } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file derived_virtual_slots_c.ads "procedure Delete \(this : access Derived'Class\)" } } */
/* { dg-final { scan-file derived_virtual_slots_c.ads "procedure Delete_And_Free \(this : access Derived'Class\)" } } */
/* { dg-final { scan-file derived_virtual_slots_c.ads "function Delete_Method \(this : access Base'Class\)" } } */

class Base
{
public:
  Base (int base_value);
  virtual ~Base () = default;
  virtual int inherited_slot () { return base; }
  int Delete () { return base; }
  int base;
  int reserved;
};

class Derived : public Base
{
public:
  Derived (int base_value, int own_value);
  ~Derived () override = default;
  int inherited_slot () override { return base + own; }
  virtual int added_slot () { return base + own + 5; }
  int own;
};

Base::Base (int base_value) : base (base_value), reserved (0) {}
Derived::Derived (int base_value, int own_value)
  : Base (base_value), own (own_value) {}

extern "C" Derived *create_derived () { return new Derived (10, 2); }
extern "C" void delete_derived (Derived *object) { delete object; }
extern "C" int cpp_call_inherited (Derived *object)
{
  return object->inherited_slot ();
}
extern "C" int cpp_call_added (Derived *object) { return object->added_slot (); }

/* { dg-final { cleanup-ada-spec } } */
