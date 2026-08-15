namespace bridge_panel {

class Base {
public:
  Base(int value);
  virtual ~Base();
  virtual int value() const;
  void add(int amount);
  void add(int first, int second);
  static int live_objects();

protected:
  int value_;
  int layout_guard_;
};

class Derived : public Base {
public:
  Derived(int value, int scale);
  ~Derived() override;
  int value() const override;
  int scale() const;

private:
  int scale_;
};

int call_value(const Base *object);
int base_size();
int derived_size();

static int live_count;

Base::Base(int value) : value_(value), layout_guard_(0) { ++live_count; }
Base::~Base() { --live_count; }
int Base::value() const { return value_; }
void Base::add(int amount) { value_ += amount; }
void Base::add(int first, int second) { value_ += first + second; }
int Base::live_objects() { return live_count; }

Derived::Derived(int value, int scale) : Base(value), scale_(scale) {}
Derived::~Derived() = default;
int Derived::value() const { return value_ * scale_; }
int Derived::scale() const { return scale_; }

int call_value(const Base *object) { return object->value(); }
int base_size() { return sizeof(Base); }
int derived_size() { return sizeof(Derived); }

} // namespace bridge_panel
