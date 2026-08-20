# C++ Ada explicit alignment

The mapper preserves packed/bit-field alignment because those paths already
emit Ada representation aspects, but it drops an otherwise ordinary C++
type's explicit `alignas` requirement.

For example:

```c++
struct alignas(32) Aligned
{
  int value;
};
```

The unpatched output keeps only the convention, so GNAT gives the record its
natural alignment:

```ada
type Aligned is record
   value : aliased int;
end record
with Convention => C_Pass_By_Copy;
```

The corrected output carries the C++ alignment into the Ada view:

```ada
type Aligned is record
   value : aliased int;
end record
with Convention => C_Pass_By_Copy,
     Alignment => 32;
```

The patch keeps `Pack` limited to packed or bit-field layouts and emits
`Alignment` independently when GCC records a user-specified type alignment.
The executable regression links C++ and Ada at `-O0` and `-O2` and compares
`sizeof`, `alignof`, Ada `Object_Size`, and Ada `Alignment`.
