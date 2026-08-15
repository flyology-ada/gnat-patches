# C++ Ada `char8_t` mapping

C++20 gives `char8_t` a distinct fundamental type with the size, alignment,
and unsigned representation of `unsigned char`. The Ada spec dumper prints the
C++ spelling directly, but GNAT's `Interfaces.C` has no `char8_t` declaration.

The offending C++ is a function with a `char8_t` parameter and result:

```c++
char8_t
char8_value (char8_t value)
{
  return value;
}
```

The unpatched mapper produces an Ada type name that does not exist:

```ada
function char8_value (value : char8_t) return char8_t
with Import => True,
     Convention => CPP,
     External_Name => "_Z11char8_valueDu";
```

The correct generated binding uses the ABI-equivalent type already provided by
`Interfaces.C` while retaining the C++ mangled name that identifies `char8_t`:

```ada
function char8_value (value : unsigned_char) return unsigned_char
with Import => True,
     Convention => CPP,
     External_Name => "_Z11char8_valueDu";
```

The executable regression compiles the generated Ada and round-trips a value
through the C++ function at `-O0` and `-O2`. The existing `wchar_t`, `char16_t`,
and `char32_t` mappings remain unchanged.

Run it against an unpatched or patched compiler root:

```sh
./bundles/cxx-ada-char8-type/run-test.sh \
  TOOLCHAIN_ROOT GCC_VERSION unpatched
./bundles/cxx-ada-char8-type/run-test.sh \
  TOOLCHAIN_ROOT GCC_VERSION patched
```
