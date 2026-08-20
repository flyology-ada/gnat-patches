struct Plain
{
  char character;
  int integer_value;
  double real_value;
};

union Overlay
{
  int integer_value;
  double real_value;
};

struct Bits
{
  unsigned first : 3;
  signed second : 5;
  bool flag : 1;
};

struct __attribute__((packed)) Packed
{
  char character;
  int integer_value;
};

struct Matrix
{
  short values[2][3];
};

extern "C" unsigned long cpp_size_plain() { return sizeof(Plain); }
extern "C" unsigned long cpp_align_plain() { return alignof(Plain); }
extern "C" unsigned long cpp_offset_plain_integer()
{
  return __builtin_offsetof(Plain, integer_value);
}
extern "C" unsigned long cpp_offset_plain_real()
{
  return __builtin_offsetof(Plain, real_value);
}
extern "C" unsigned long cpp_size_overlay() { return sizeof(Overlay); }
extern "C" unsigned long cpp_align_overlay() { return alignof(Overlay); }
extern "C" unsigned long cpp_size_bits() { return sizeof(Bits); }
extern "C" unsigned long cpp_align_bits() { return alignof(Bits); }
extern "C" unsigned long cpp_size_packed() { return sizeof(Packed); }
extern "C" unsigned long cpp_align_packed() { return alignof(Packed); }
extern "C" unsigned long cpp_offset_packed_integer()
{
  return __builtin_offsetof(Packed, integer_value);
}
extern "C" unsigned long cpp_size_matrix() { return sizeof(Matrix); }
extern "C" unsigned long cpp_align_matrix() { return alignof(Matrix); }
