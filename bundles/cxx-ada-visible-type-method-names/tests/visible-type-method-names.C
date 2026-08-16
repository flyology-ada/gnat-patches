/* { dg-do compile } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file visible_type_method_names_c.ads "function result_Method" } } */

struct Result
{
  int get ();
  int value;
};

class Widget
{
public:
  int result ();
  int value;
};

int Result::get () { return value; }
int Widget::result () { return value; }

extern "C" Widget *cpp_create_widget (int value)
{
  Widget *object = new Widget;
  object->value = value;
  return object;
}

extern "C" Result *cpp_create_result (int value)
{
  return new Result { value };
}

extern "C" void cpp_delete_widget (Widget *object) { delete object; }
extern "C" void cpp_delete_result (Result *object) { delete object; }

/* { dg-final { cleanup-ada-spec } } */
