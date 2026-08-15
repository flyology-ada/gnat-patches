template <typename T>
struct Pod
{
  T value;
};

extern template struct Pod<int>;
