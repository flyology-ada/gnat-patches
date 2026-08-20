# C++ Ada namespace identity

The C++ front end recursively collects declarations from namespaces, but the
Ada dumper discards the namespace nodes. Distinct declarations consequently
collapse into the same Ada identifier.

For example:

```c++
namespace left  { struct Entry { int value; }; }
namespace right { struct Entry { double value; }; }
```

The unpatched output contains two declarations of the same Ada type:

```ada
type c_Entry is record
   value : aliased int;
end record;

type c_Entry is record
   value : aliased double;
end record;
```

The corrected output preserves the C++ hierarchy as nested Ada packages. The
`c_` prefix that keeps `entry` from colliding with the Ada reserved word is
unchanged; what the patch adds is the enclosing package, which is what makes
the two declarations distinct:

```ada
package left is
   type c_Entry is record
      value : aliased int;
   end record;
end left;

package right is
   type c_Entry is record
      value : aliased double;
   end record;
end right;
```

This also distinguishes an underscore from a namespace boundary without an
encoded flat name:

```c++
namespace a_b { struct Marker { int value; }; }
namespace a::b { struct Marker { double value; }; }
```

```ada
package a_b is
   type Marker is record ... end record;
end a_b;

package a is
   package b is
      type Marker is record ... end record;
   end b;
end a;
```

Functions, aliases, reopened namespaces, and generated `Class_` packages stay
inside the corresponding package. Anonymous namespaces remain transparent
because they have no source-level name and their declarations already have
translation-unit-local linkage.

The executable regression generates and compiles Ada for duplicate records,
functions, nontrivial classes, reopened namespaces, and the `a_b` versus `a::b`
boundary case at `-O0` and `-O2`.
