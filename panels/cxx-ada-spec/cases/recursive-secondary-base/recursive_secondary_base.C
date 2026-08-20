class Root
{
public:
  virtual ~Root () = default;
  virtual int root_value () { return root; }
  int root;
};

class Extra
{
public:
  virtual ~Extra () = default;
  virtual int extra_value () { return extra; }
  int extra;
};

class Secondary : public Root, public Extra
{
public:
  virtual ~Secondary () = default;
  int root_value () override { return root + own; }
  int extra_value () override { return extra + own; }
  int own;
};

class Primary
{
public:
  virtual ~Primary () = default;
  virtual int primary_value () { return primary; }
  int primary;
};

class Most : public Primary, public Secondary
{
public:
  Most (int primary_value, int root_value, int extra_value,
        int own_value, int final_value);
  ~Most () override = default;
  int primary_value () override { return primary + final; }
  int root_value () override { return root + final; }
  int extra_value () override { return extra + final; }
  int final;
};

Most::Most (int primary_value, int root_value, int extra_value,
            int own_value, int final_value)
{
  primary = primary_value;
  root = root_value;
  extra = extra_value;
  own = own_value;
  final = final_value;
}

extern "C" Most *create_most () { return new Most (10, 20, 30, 4, 5); }
extern "C" void delete_most (Most *object) { delete object; }
extern "C" unsigned long most_size () { return sizeof (Most); }
extern "C" unsigned long secondary_offset (Most *object)
{
  return reinterpret_cast<char *> (static_cast<Secondary *> (object))
    - reinterpret_cast<char *> (object);
}
extern "C" unsigned long extra_offset (Most *object)
{
  return reinterpret_cast<char *> (static_cast<Extra *> (object))
    - reinterpret_cast<char *> (object);
}
extern "C" int call_root (Root *object) { return object->root_value (); }
extern "C" int call_extra (Extra *object) { return object->extra_value (); }
extern "C" int read_values (Most *object)
{
  return object->primary + object->root + object->extra
    + object->own + object->final;
}
