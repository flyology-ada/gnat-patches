/* { dg-do compile } */
/* { dg-require-effective-target lp64 } */
/* { dg-options "-std=c++20 -fdump-ada-spec-slim" } */
/* { dg-final { scan-file empty_class_storage_c.ads "for Empty'Size use 0;" } } */
/* { dg-final { scan-file empty_class_storage_c.ads "for Empty'Object_Size use 8;" } } */
/* { dg-final { scan-file-not empty_class_storage_c.ads "parent : aliased Empty_Base;" } } */
/* { dg-final { scan-file-not empty_class_storage_c.ads "ignored : aliased Empty;" } } */

struct Empty
{};

struct Empty_Base
{};

struct With_Empty_Base : Empty_Base
{
  int value;
};

struct With_Empty_Member
{
  Empty member;
  int value;
};

struct With_Empty_Array
{
  Empty values[3];
};

struct With_No_Unique_Address
{
  [[no_unique_address]] Empty ignored;
  int value;
};

struct Method_Empty
{
  Method_Empty ();
  void ping ();
};

Method_Empty::Method_Empty () {}
void Method_Empty::ping () {}

extern "C" unsigned long cpp_empty_size () { return sizeof (Empty); }
extern "C" unsigned long cpp_empty_align () { return alignof (Empty); }
extern "C" unsigned long cpp_method_empty_size ()
{
  return sizeof (Method_Empty);
}

extern "C" unsigned long
cpp_with_empty_base_size ()
{
  return sizeof (With_Empty_Base);
}

extern "C" unsigned long
cpp_with_empty_base_value_offset ()
{
  return __builtin_offsetof (With_Empty_Base, value);
}

extern "C" unsigned long
cpp_with_empty_member_size ()
{
  return sizeof (With_Empty_Member);
}

extern "C" unsigned long
cpp_with_empty_member_member_offset ()
{
  return __builtin_offsetof (With_Empty_Member, member);
}

extern "C" unsigned long
cpp_with_empty_member_value_offset ()
{
  return __builtin_offsetof (With_Empty_Member, value);
}

extern "C" unsigned long
cpp_with_empty_array_size ()
{
  return sizeof (With_Empty_Array);
}

extern "C" unsigned long
cpp_with_empty_array_values_offset ()
{
  return __builtin_offsetof (With_Empty_Array, values);
}

extern "C" unsigned long
cpp_with_no_unique_address_size ()
{
  return sizeof (With_No_Unique_Address);
}

extern "C" unsigned long
cpp_with_no_unique_address_value_offset ()
{
  return __builtin_offsetof (With_No_Unique_Address, value);
}

/* { dg-final { cleanup-ada-spec } } */
