# C++ Ada enclosing-type method names

Ada identifiers are case-insensitive. A C++ method whose spelling differs from
its enclosing type only by case therefore collides with the generated Ada type.

```c++
struct Left
{
  virtual int left ();
};
```

The unpatched mapper produces invalid Ada:

```ada
package Class_Left is
   type Left is tagged limited record
      null;
   end record;

   function left (this : access Left) return int;
end Class_Left;
```

The corrected output gives only the colliding method a stable descriptive
suffix while preserving its C++ external symbol:

```ada
package Class_Left is
   type Left is tagged limited record
      null;
   end record;

   function left_Method (this : access Left) return int
   with Import => True,
        Convention => CPP,
        External_Name => "_ZN4Left4leftEv";
end Class_Left;
```

The executable regression covers two independent collisions inside concrete
base classes and also includes a multiply inherited class. At `-O0` and `-O2`,
the patched Ada compiles, calls both renamed C++ methods on C++-allocated base
objects, and verifies their return values.
