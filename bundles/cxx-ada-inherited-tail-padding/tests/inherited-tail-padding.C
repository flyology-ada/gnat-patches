/* { dg-do compile } */
/* { dg-require-effective-target lp64 } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file inherited_tail_padding_c.ads "for Tail_Base'Size use 96;" } } */
/* { dg-final { scan-file inherited_tail_padding_c.ads "for Tail_Base'Object_Size use 128;" } } */
/* { dg-final { scan-file inherited_tail_padding_c.ads "value_u at 8 range 0 .. 31;" } } */
/* { dg-final { scan-file inherited_tail_padding_c.ads "extra_u at 12 range 0 .. 31;" } } */

class Tail_Base
{
public:
  Tail_Base (int value);
  virtual ~Tail_Base ();
  int value () const { return value_; }

protected:
  int value_;
};

class Tail_Derived : public Tail_Base
{
public:
  Tail_Derived (int value, int extra);
  ~Tail_Derived () override;
  int extra () const { return extra_; }

private:
  int extra_;
};

Tail_Base::Tail_Base (int value) : value_ (value) {}
Tail_Base::~Tail_Base () = default;
Tail_Derived::Tail_Derived (int value, int extra)
  : Tail_Base (value), extra_ (extra) {}
Tail_Derived::~Tail_Derived () = default;

extern "C" unsigned long
cpp_base_size ()
{
  return sizeof (Tail_Base);
}

extern "C" unsigned long
cpp_derived_size ()
{
  return sizeof (Tail_Derived);
}

extern "C" int
cpp_value (const Tail_Derived *object)
{
  return object->value ();
}

extern "C" int
cpp_extra (const Tail_Derived *object)
{
  return object->extra ();
}

/* { dg-final { cleanup-ada-spec } } */
