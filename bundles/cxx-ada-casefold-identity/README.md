# C++ Ada casefold identity

Ada identifiers are case-insensitive, while C++ identifiers are
case-sensitive. The mapper previously copied C++ casing without detecting
collisions in the generated Ada scope.

For example:

```c++
struct Item { int value; };
struct ITEM { double value; };
int measure(Item);
int MEASURE(ITEM);
```

The unpatched output preserves spelling but loses identity in Ada:

```ada
type Item is record ... end record;
type ITEM is record ... end record;
function measure (arg1 : Item) return int;
function MEASURE (arg1 : ITEM) return int;
```

Both pairs are duplicate Ada identifiers. The corrected output assigns a
stable, scope-local suffix to the later case variant and uses it in every
reference:

```ada
type Item is record ... end record;
type ITEM_Case_2 is record ... end record;
function measure (arg1 : Item) return int;
function MEASURE_Case_2 (arg1 : ITEM_Case_2) return int;
```

The same rule covers records, functions, aliases, and fields. Identical names
in different C++ scopes remain unchanged. The executable regression compiles
the corrected Ada and calls both case-distinct C++ functions at `-O0` and
`-O2`.
