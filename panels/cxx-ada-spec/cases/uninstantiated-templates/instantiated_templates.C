template <typename T> struct Hidden
{
  T value;
  T get () const { return value; }
};

template struct Hidden<int>;
