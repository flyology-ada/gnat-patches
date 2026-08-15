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

The corrected output incorporates the complete named namespace path:

```ada
type left_c_Entry is record
   value : aliased int;
end record;

type right_c_Entry is record
   value : aliased double;
end record;
```

The same prefix is used for functions, type references, aliases, nested
namespaces, and generated `Class_` packages. Anonymous namespaces remain
unprefixed because their declarations already have translation-unit-local
linkage and no source-level namespace name.

The executable regression generates and compiles Ada for duplicate records,
functions, and nontrivial classes in two nested namespace paths at `-O0` and
`-O2`.
