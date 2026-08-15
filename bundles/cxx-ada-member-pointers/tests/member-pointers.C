/* { dg-do compile } */
/* { dg-options "-std=gnu++20 -fdump-ada-spec-slim" } */
/* { dg-final { scan-file member_pointers_c.ads "subtype Data_Member is ptrdiff_t;" } } */
/* { dg-final { scan-file member_pointers_c.ads "uu_pfn : System.Address;" } } */
/* { dg-final { scan-file member_pointers_c.ads "uu_delta : aliased long;" } } */

struct Data_Object
{
  int first;
  int field;
};

using Data_Member = int Data_Object::*;

struct Method_Object
{
  virtual int virtual_method (int value) const { return value + 20; }
  int nonvirtual_method (int value) const { return value + 10; }
};

using Method_Member = int (Method_Object::*) (int) const;

Data_Member get_data_member () { return &Data_Object::field; }
Data_Member get_null_data_member () { return nullptr; }
int apply_data_member (Data_Member member)
{
  Data_Object object { 1, 42 };
  return object.*member;
}
bool is_null_data_member (Data_Member member) { return member == nullptr; }

Method_Member get_nonvirtual_method ()
{
  return &Method_Object::nonvirtual_method;
}
Method_Member get_virtual_method () { return &Method_Object::virtual_method; }
Method_Member get_null_method () { return nullptr; }
int apply_method (Method_Member member, int value)
{
  Method_Object object;
  return (object.*member) (value);
}
bool is_null_method (Method_Member member) { return member == nullptr; }

/* { dg-final { cleanup-ada-spec } } */
