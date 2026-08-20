/* { dg-do compile } */
/* { dg-options "-std=gnu++20 -fdump-ada-spec-slim" } */
/* { dg-final { scan-file template_record_termination_c.ads "with Convention => C_Pass_By_Copy;" } } */

template <typename T>
struct Plain
{
  T value;
};

template struct Plain<int>;

template <typename T, bool Select>
struct Choice;

template <typename T>
struct Choice<T, false>
{
  T value;
};

template struct Choice<int, false>;

template <typename T>
struct Specialized
{
  T value;
};

template <>
struct Specialized<bool>
{
  unsigned value;
};

using Bool_Specialized = Specialized<bool>;

template <typename T>
struct Outer
{
  template <typename U>
  struct Inner
  {
    U value;
  };
};

template struct Outer<int>;

template <typename T>
concept Integral_Sized = sizeof (T) >= sizeof (int);

template <Integral_Sized T>
struct Constrained
{
  T value;
};

template struct Constrained<int>;

template <typename T>
struct Item
{
  T value;
};

template <template <typename> class Container, typename T>
struct Wrapper
{
  Container<T> item;
};

template struct Wrapper<Item, int>;

/* { dg-final { cleanup-ada-spec } } */
