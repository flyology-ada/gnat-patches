# C++ Ada profile formal/type names

Ada formal parameters are visible throughout the rest of their subprogram
profile. A parameter therefore cannot have the same case-insensitive name as
a type used by a later parameter or by the result subtype.

This C++ uses all three affected forms: a constructor result, a function
result, and a later formal parameter type:

```c++
struct Result { int value; };
struct Widget
{
  Widget (int widget);
  int value;
};

extern "C" Result *make_result (int result);
extern "C" int inspect (int result, Result *item);
```

The unpatched mapper checks a formal only against that formal's own type and
produces illegal Ada profiles:

```ada
function New_Widget (widget : int) return Widget;
function make_result (result : int) return access Result;
function inspect (result : int; item : access Result) return int;
```

GNAT rejects these because `widget` hides `Widget` and `result` hides
`Result`. The corrected mapper compares each formal's converted Ada name with
every type from that point to the end of the profile, including the result,
and prefixes only a colliding formal:

```ada
function New_Widget (the_widget : int) return Widget;
function make_result (the_result : int) return access Result;
function inspect (the_result : int; item : access Result) return int;
```

The executable regression runs at `-O0` and `-O2`. Stock GCC must generate a
binding that GNAT rejects with the profile visibility error. With the patch,
Ada creates a C++ result object, passes it through the later-type profile,
checks the computed value, and releases it through C++.
