# C++ Ada visible type/method names

Every generated C++ class is placed in a nested Ada package followed by a
`use` clause. A method in one class can therefore collide case-insensitively
with a type imported from another class package, even though the C++ names
belong to unrelated scopes.

For example, `Result` becomes directly visible through `use Class_Result`,
then `result` becomes directly visible through `use Class_Widget`:

```c++
struct Result
{
  int get ();
  int value;
};

struct Widget
{
  int result ();
  int value;
};

extern "C" Result *cpp_create_result (int value);
```

The unpatched mapper emits both identifiers unchanged. GNAT cannot resolve
the result type in the later function profile because both use-visible names
are homographs:

```ada
package Class_Result is
   type Result is limited record ... end record;
end;
use Class_Result;

package Class_Widget is
   function result (this : access Widget) return int;
end;
use Class_Widget;

function cpp_create_result (value : int) return access Result;
```

The corrected mapper compares every method name with all types collected for
the generated unit. Only a colliding method receives the same stable suffix
used for an enclosing-type collision:

```ada
package Class_Widget is
   function result_Method (this : access Widget) return int
   with Import => True,
        Convention => CPP,
        External_Name => "_ZN6Widget6resultEv";
end;

function cpp_create_result (value : int) return access Result;
```

The executable regression runs at `-O0` and `-O2`. Stock GCC must produce a
specification GNAT rejects for the two use-visible names. With the patch, Ada
calls the renamed C++ method, reads the unrelated result object, and releases
both objects through C++.
