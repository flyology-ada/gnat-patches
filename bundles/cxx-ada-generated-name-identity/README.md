# C++ Ada generated-name identity

The mapper synthesizes readable Ada names for language distinctions and ABI
objects that have no direct Ada spelling. Those names previously shared no
collision policy with source identifiers. A valid C++ declaration could
therefore make the generated specification illegal.

For example, a `const` qualifier is appended to a method name:

```c++
class Methods {
public:
  int inspect() const;
  int inspect_Const();
};
```

The unpatched output contains two declarations named `inspect_Const`:

```ada
function inspect_Const (this : access constant Methods) return int;
function inspect_Const (this : access Methods) return int;
```

The corrected mapper reserves source spellings first and changes only the
generated collision:

```ada
function inspect_Const_2 (this : access constant Methods) return int;
function inspect_Const (this : access Methods) return int;
```

The same problem occurs between a template-instantiation package and its
source alias:

```c++
template<typename T> struct Box { T value; };
typedef Box<int> Box_int;
```

Previously both were `Box_int`; now the generated package is renamed while
the alias stays readable and its reference follows the allocation:

```ada
package Box_int_2 is
   type Box is limited record ... end record;
end Box_int_2;
subtype Box_int is Box_int_2.Box;
```

It also covers generated formal prefixes, base-storage types, unnamed base
components, class packages, constructors, destructors, and assignment
operators. Representative corrected declarations are:

```ada
function make_widget
  (the_Widget_2 : int; the_Widget : int) return access Widget;
type Tail_Derived_As_Base_2 is limited record ... end record;
parent_Base_2  : aliased Left;
field_2_Base_2 : aliased Right;
package Class_Gadget_2 is ... end Class_Gadget_2;
function New_Creator_2 return Creator;
procedure Delete_2 (this : access Destroyer);
function Assign_Assigner_2 (...) return access Assigner;
```

Names are allocated per Ada scope, compared case-insensitively, and keyed by
the C++ declaration and generated role. Unrelated scopes keep their original
names. The executable regression makes GNAT compile the complete generated
specification and calls a C++ oracle at `-O0` and `-O2`.
