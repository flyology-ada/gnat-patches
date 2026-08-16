/* { dg-do compile } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file namespace_identity_c.ads "package first is" } } */
/* { dg-final { scan-file namespace_identity_c.ads "package inner is" } } */
/* { dg-final { scan-file namespace_identity_c.ads "function transform \(value : Item\) return Item" } } */
/* { dg-final { scan-file namespace_identity_c.ads "package Class_Object is" } } */
/* { dg-final { scan-file namespace_identity_c.ads "package a_b is" } } */
/* { dg-final { scan-file namespace_identity_c.ads "package a is" } } */
/* { dg-final { scan-file namespace_identity_c.ads "type Again is record" } } */
/* { dg-final { scan-file-not namespace_identity_c.ads "package :: is" } } */

namespace first::inner
{
  struct Item { int value; };
  Item transform (Item value) { value.value += 1; return value; }

  class Object
  {
  public:
    int get () const;
  private:
    int value_;
  };
}

namespace second::inner
{
  struct Item { double value; };
  Item transform (Item value) { value.value += 2.0; return value; }

  class Object
  {
  public:
    int get () const;
  private:
    double value_;
  };
}

namespace a_b
{
  struct Marker { int value; };
}

namespace a::b
{
  struct Marker { double value; };
}

namespace first::inner
{
  struct Again { long value; };
}

using First_Item = first::inner::Item;
using Second_Item = second::inner::Item;

extern "C" int namespace_identity_oracle () { return 73; }

/* { dg-final { cleanup-ada-spec } } */
