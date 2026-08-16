/* { dg-do compile } */
/* { dg-require-effective-target lp64 } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file concrete_multiple_inheritance_c.ads "type Both is limited new Left with record" } } */
/* { dg-final { scan-file concrete_multiple_inheritance_c.ads "field_2 : aliased Right_As_Base;" } } */
/* { dg-final { scan-file concrete_multiple_inheritance_c.ads "for Right_As_Base'Object_Size use 96;" } } */
/* { dg-final { scan-file concrete_multiple_inheritance_c.ads "field_2 at 16 range 0 .. 95;" } } */

class Left
{
public:
  virtual ~Left () = default;
  virtual int left_value () { return l; }
  int l;
};

class Right
{
public:
  virtual ~Right () = default;
  virtual int right_value () { return r; }
  int r;
};

class Both : public Left, public Right
{
public:
  Both (int l_value, int r_value, int both_value);
  ~Both () override = default;
  int left_value () override { return l + both; }
  int right_value () override { return r + both; }
  int both;
};

Both::Both (int l_value, int r_value, int both_value)
{
  l = l_value;
  r = r_value;
  both = both_value;
}

extern "C" Both *cpp_create_both (int l, int r, int both_value)
{
  return new Both (l, r, both_value);
}

extern "C" void cpp_delete_both (Both *object) { delete object; }
extern "C" unsigned long cpp_both_size () { return sizeof (Both); }
extern "C" unsigned long cpp_right_offset (Both *object)
{
  return reinterpret_cast<char *> (static_cast<Right *> (object))
    - reinterpret_cast<char *> (object);
}
extern "C" int cpp_call_left (Both *object) { return object->left_value (); }
extern "C" int cpp_call_right (Right *object) { return object->right_value (); }
extern "C" int cpp_call_right_from_both (Both *object)
{
  return static_cast<Right *> (object)->right_value ();
}
extern "C" int cpp_read_left (Both *object) { return object->l; }
extern "C" int cpp_read_right (Both *object) { return object->r; }
extern "C" int cpp_read_both (Both *object) { return object->both; }

/* { dg-final { cleanup-ada-spec } } */
