/* { dg-do compile } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file qualified_method_names_c.ads "function inspect_Const" } } */
/* { dg-final { scan-file qualified_method_names_c.ads "function inspect_Volatile" } } */
/* { dg-final { scan-file qualified_method_names_c.ads "function category_Lvalue" } } */
/* { dg-final { scan-file qualified_method_names_c.ads "function category_Rvalue" } } */
/* { dg-final { scan-file qualified_method_names_c.ads "function Assign_Value_Move" } } */

class Accessor
{
public:
  explicit Accessor (int value);
  int inspect ();
  int inspect () const;
  int inspect () volatile;
  int category () &;
  int category () &&;

private:
  int value_;
};

Accessor::Accessor (int value) : value_ (value) {}
int Accessor::inspect () { return value_ + 1; }
int Accessor::inspect () const { return value_ + 2; }
int Accessor::inspect () volatile { return value_ + 3; }
int Accessor::category () & { return value_ + 4; }
int Accessor::category () && { return value_ + 5; }

class Value
{
public:
  explicit Value (int initial);
  Value &operator= (const Value &other);
  Value &operator= (Value &&other);
  int get () const;

private:
  int value_;
};

Value::Value (int initial) : value_ (initial) {}

Value &
Value::operator= (const Value &other)
{
  value_ = other.value_;
  return *this;
}

Value &
Value::operator= (Value &&other)
{
  value_ = other.value_;
  other.value_ = -1;
  return *this;
}

int Value::get () const { return value_; }

/* { dg-final { cleanup-ada-spec } } */
