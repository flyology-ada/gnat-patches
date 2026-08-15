enum Color : unsigned
{
  Red = 1,
  Green = 2,
  Blue = 3
};

struct Pair
{
  int first;
  int second;
};

union Number
{
  int integer_value;
  float real_value;
};

extern "C" bool invert_bool(bool value) { return !value; }
extern "C" signed char add_schar(signed char left, signed char right)
{
  return left + right;
}
extern "C" unsigned long long mix_ull(unsigned long long value)
{
  return value ^ 0x55aa55aa55aa55aaULL;
}
extern "C" float add_float(float left, float right) { return left + right; }
extern "C" double add_double(double left, double right) { return left + right; }
extern "C" long double add_long_double(long double left, long double right)
{
  return left + right;
}
extern "C" Color next_color(Color value)
{
  return value == Blue ? Red : static_cast<Color>(static_cast<unsigned>(value) + 1);
}
extern "C" Pair reverse_pair(Pair value)
{
  return Pair{value.second, value.first};
}
extern "C" Number integer_number(int value)
{
  Number result;
  result.integer_value = value;
  return result;
}
extern "C" int dereference(const int *value) { return *value; }
extern "C" void increment_reference(int &value) { ++value; }
extern "C" int invoke_callback(int (*callback)(int), int value)
{
  return callback(value);
}
