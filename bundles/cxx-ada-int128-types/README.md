# C++ Ada unsigned `__int128` types

GCC 13 and 14 special-case the internal C++ type name `__int128`, but compare
the complete spelling. That recognizes the signed type and misses the internal
unsigned spelling, `__int128 unsigned`.

The offending C++ is:

```c++
using Signed_128 = __int128;
using Unsigned_128 = unsigned __int128;

Signed_128 signed_round_trip (Signed_128);
Unsigned_128 unsigned_round_trip (Unsigned_128);
```

The GCC 13/14 mapper currently produces one valid subtype and one reference to
an Ada identifier that does not exist:

```ada
subtype Signed_128 is Extensions.Signed_128;
subtype Unsigned_128 is uu_int128_unsigned;
```

It should recognize both internal names as 128-bit integer types and produce:

```ada
subtype Signed_128 is Extensions.Signed_128;
subtype Unsigned_128 is Extensions.Unsigned_128;
```

The correction uses the eight-character `__int128` prefix comparison already
present in GCC 15 and 16. Those releases are known-good controls and receive no
code patch. The executable regression passes negative signed and high-bit
unsigned values by value from C++ to Ada, back through C++, and into C++ value
checkers at `-O0` and `-O2`.

Run it against an unpatched or patched compiler root:

```sh
./bundles/cxx-ada-int128-types/run-test.sh \
  TOOLCHAIN_ROOT GCC_VERSION unpatched
./bundles/cxx-ada-int128-types/run-test.sh \
  TOOLCHAIN_ROOT GCC_VERSION patched
```
