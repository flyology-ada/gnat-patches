/* { dg-do compile } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file enclosing_type_method_names_c.ads "function left_Method" } } */
/* { dg-final { scan-file enclosing_type_method_names_c.ads "function right_Method" } } */

struct Left
{
  virtual int left ();
  int l;
};

struct Right
{
  virtual int right ();
  int r;
};

struct Both : Left, Right
{
  int both;
};

int Left::left () { return l; }
int Right::right () { return r; }
extern "C" Left *cpp_create_left (int value)
{
  Left *object = new Left;
  object->l = value;
  return object;
}
extern "C" Right *cpp_create_right (int value)
{
  Right *object = new Right;
  object->r = value;
  return object;
}
extern "C" void cpp_delete_left (Left *object) { delete object; }
extern "C" void cpp_delete_right (Right *object) { delete object; }

/* { dg-final { cleanup-ada-spec } } */
