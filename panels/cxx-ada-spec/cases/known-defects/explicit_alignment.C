struct alignas(32) Aligned
{
  int value;
};

extern "C" unsigned long cpp_size() { return sizeof(Aligned); }
extern "C" unsigned long cpp_alignment() { return alignof(Aligned); }
