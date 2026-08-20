/* { dg-do compile } */
/* { dg-require-effective-target lp64 } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file inherited_tail_padding_c.ads "for Tail_Base'Size use 96;" } } */
/* { dg-final { scan-file inherited_tail_padding_c.ads "for Tail_Base'Object_Size use 128;" } } */
/* { dg-final { scan-file inherited_tail_padding_c.ads "value_u at 8 range 0 .. 31;" } } */
/* { dg-final { scan-file inherited_tail_padding_c.ads "extra_u at 12 range 0 .. 31;" } } */
/* { dg-final { scan-file inherited_tail_padding_c.ads "for Plain_Base'Size use 24;" } } */
/* { dg-final { scan-file inherited_tail_padding_c.ads "derived_char at 3 range 0 .. 7;" } } */
/* { dg-final { scan-file inherited_tail_padding_c.ads "extra at 7 range 0 .. 7;" } } */

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

struct Plain_Base
{
  short base_short;
  char base_char;
  Plain_Base () : base_short (1), base_char (2) {}
};

struct Plain_Derived : Plain_Base
{
  char derived_char;
  Plain_Derived () : derived_char (3) {}
};

struct Plain_Left
{
  short left_short;
  char left_char;
  Plain_Left () : left_short (4), left_char (5) {}
};

struct Plain_Right
{
  short right_short;
  char right_char;
  Plain_Right () : right_short (6), right_char (7) {}
};

struct Plain_Both : Plain_Left, Plain_Right
{
  char extra;
  Plain_Both () : extra (8) {}
};

extern "C" Plain_Derived *cpp_plain_create () { return new Plain_Derived; }
extern "C" void cpp_plain_delete (Plain_Derived *p) { delete p; }
extern "C" unsigned long cpp_plain_size () { return sizeof (Plain_Derived); }
extern "C" int cpp_plain_values (const Plain_Derived *p)
{
  return p->base_short + p->base_char + p->derived_char;
}

extern "C" Plain_Both *cpp_both_create () { return new Plain_Both; }
extern "C" void cpp_both_delete (Plain_Both *p) { delete p; }
extern "C" unsigned long cpp_both_plain_size () { return sizeof (Plain_Both); }
extern "C" int cpp_both_values (const Plain_Both *p)
{
  return p->left_short + p->left_char + p->right_short
    + p->right_char + p->extra;
}

/* { dg-final { cleanup-ada-spec } } */
