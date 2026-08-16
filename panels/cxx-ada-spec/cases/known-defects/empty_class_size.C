struct Empty
{};

struct Empty_Base
{};

struct With_Empty_Base : Empty_Base
{
  int value;
};

extern "C" unsigned long cpp_empty_size () { return sizeof (Empty); }

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
