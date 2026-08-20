/* { dg-do compile } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file profile_formal_type_names_c.ads "function New_Widget \(the_widget : int\)" } } */
/* { dg-final { scan-file profile_formal_type_names_c.ads "function make_result \(the_result : int\)" } } */
/* { dg-final { scan-file profile_formal_type_names_c.ads "function inspect \(the_result : int; item : access Result\)" } } */

struct Result
{
  int value;
};

struct Widget
{
  Widget (int widget);
  int value;
};

Widget::Widget (int widget) : value (widget) {}

extern "C" Result *make_result (int result)
{
  return new Result { result };
}

extern "C" int inspect (int result, Result *item)
{
  return result + item->value;
}

extern "C" void delete_result (Result *item)
{
  delete item;
}

/* { dg-final { cleanup-ada-spec } } */
