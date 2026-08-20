template <typename T> struct Hidden
{
  T value;
  T get () const { return value; }
};

struct Visible
{
  int value;
};

extern "C" int visible_value (Visible *object)
{
  return object->value;
}
