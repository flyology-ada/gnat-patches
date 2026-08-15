/* { dg-do compile } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file namespace_identity_c.ads "type first_inner_Item" } } */
/* { dg-final { scan-file namespace_identity_c.ads "type second_inner_Item" } } */
/* { dg-final { scan-file namespace_identity_c.ads "function first_inner_transform" } } */
/* { dg-final { scan-file namespace_identity_c.ads "function second_inner_transform" } } */
/* { dg-final { scan-file namespace_identity_c.ads "package Class_first_inner_Object" } } */
/* { dg-final { scan-file namespace_identity_c.ads "package Class_second_inner_Object" } } */

namespace first::inner
{
  struct Item { int value; };
  Item transform (Item value);

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
  Item transform (Item value);

  class Object
  {
  public:
    int get () const;
  private:
    double value_;
  };
}

using First_Item = first::inner::Item;
using Second_Item = second::inner::Item;

/* { dg-final { cleanup-ada-spec } } */
