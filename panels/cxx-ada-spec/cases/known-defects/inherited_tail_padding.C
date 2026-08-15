class Tail_Base
{
public:
  Tail_Base(int value);
  virtual ~Tail_Base();

protected:
  int value_;
};

class Tail_Derived : public Tail_Base
{
public:
  Tail_Derived(int value, int extra);
  ~Tail_Derived() override;

private:
  int extra_;
};

int cpp_base_size();
int cpp_derived_size();

Tail_Base::Tail_Base(int value) : value_(value) {}
Tail_Base::~Tail_Base() = default;
Tail_Derived::Tail_Derived(int value, int extra)
  : Tail_Base(value), extra_(extra) {}
Tail_Derived::~Tail_Derived() = default;

int cpp_base_size() { return sizeof(Tail_Base); }
int cpp_derived_size() { return sizeof(Tail_Derived); }
