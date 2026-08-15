class Primary
{
public:
  Primary(int value);
  virtual ~Primary();
  virtual int value() const;

protected:
  int value_;
};

class Callback
{
public:
  virtual int invoke(int value) = 0;
};

class Combined : public Primary, public Callback
{
public:
  Combined(int value);
  ~Combined() override;
  int value() const override;
  int invoke(int value) override;
};

int fire(Callback *callback, int value);

Primary::Primary(int value) : value_(value) {}
Primary::~Primary() = default;
int Primary::value() const { return value_; }

Combined::Combined(int value) : Primary(value) {}
Combined::~Combined() = default;
int Combined::value() const { return value_ * 2; }
int Combined::invoke(int value) { return value_ + value; }

int fire(Callback *callback, int value) { return callback->invoke(value); }
