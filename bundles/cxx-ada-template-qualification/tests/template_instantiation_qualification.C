/* { dg-do compile } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file template_instantiation_qualification_c.ads "subtype Int_Box is Box_int.Box;" } } */
/* { dg-final { scan-file template_instantiation_qualification_c.ads "subtype Double_Box is Box_double.Box;" } } */
/* { dg-final { scan-file template_instantiation_qualification_c.ads "item : aliased Box_int.Box;" } } */
/* { dg-final { scan-file template_instantiation_qualification_c.ads "function identity \(value : Box_double.Box\) return Box_double.Box" } } */
/* { dg-final { scan-file template_instantiation_qualification_c.ads "subtype Alias_Int_Box is Box_int.Box;" } } */

template <typename T>
class Box
{
public:
  Box ();
  T value () const;

private:
  T value_;
};

extern template class Box<int>;
extern template class Box<double>;

using Int_Box = Box<int>;
using Double_Box = Box<double>;
template <typename T> using Alias_Box = Box<T>;
using Alias_Int_Box = Alias_Box<int>;

struct Holder
{
  Box<int> item;
};

Box<double> identity (Box<double> value);

/* { dg-final { cleanup-ada-spec } } */
