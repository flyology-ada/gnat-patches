# C++ Ada qualified method names

Ada profiles cannot overload methods solely by the C++ cv/ref qualification of
their implicit object parameter, and the mapper also gives copy and move
assignment the same synthetic name.

For example:

```c++
struct Accessor {
  int inspect();
  int inspect() const;
  int inspect() volatile;
  int category() &;
  int category() &&;
};

struct Value {
  Value& operator=(const Value&);
  Value& operator=(Value&&);
};
```

The unpatched mapper emits colliding Ada declarations:

```ada
function inspect (this : access Accessor) return int;
function inspect (this : access constant Accessor) return int;
function inspect (this : access Accessor) return int;

function category (this : access Accessor) return int;
function category (this : access Accessor) return int;

function Assign_Value (...) return access Value;
function Assign_Value (...) return access Value;
```

The corrected output preserves the otherwise-lost C++ identity in stable Ada
suffixes:

```ada
function inspect (this : access Accessor) return int;
function inspect_Const (this : access constant Accessor) return int;
function inspect_Volatile (this : access Accessor) return int;

function category_Lvalue (this : access Accessor) return int;
function category_Rvalue (this : access Accessor) return int;

function Assign_Value (...) return access Value;
function Assign_Value_Move (...) return access Value;
```

Const, volatile, lvalue-ref, and rvalue-ref suffixes are combined in that
order. The names expose distinctions that Ada cannot encode in the profiles;
callers remain responsible for satisfying the C++ object-category semantics.
The executable regression calls every corrected binding and checks copy/move
assignment effects at `-O0` and `-O2`.
