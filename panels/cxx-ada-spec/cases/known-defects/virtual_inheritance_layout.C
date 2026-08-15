struct Root
{
  int root_value;
};

struct Virtual : virtual Root
{
  int derived_value;
};

extern "C" unsigned long cpp_root_size() { return sizeof(Root); }
extern "C" unsigned long cpp_virtual_size() { return sizeof(Virtual); }
extern "C" unsigned long cpp_virtual_alignment() { return alignof(Virtual); }
