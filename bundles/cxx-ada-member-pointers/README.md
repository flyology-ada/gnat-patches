# C++ Ada pointers to members

The C++ front end uses two related internal representations for pointers to
members. A data-member pointer is an `OFFSET_TYPE`; a member-function pointer
is an ABI record containing a pointer-to-`METHOD_TYPE` and a `this` adjustment.
The Ada dumper handles neither internal type, so both forms produce malformed
declarations.

The offending C++ forms are:

```c++
struct Data_Object { int first; int field; };
using Data_Member = int Data_Object::*;

struct Method_Object {
  virtual int virtual_method (int) const;
  int nonvirtual_method (int) const;
};
using Method_Member = int (Method_Object::*) (int) const;
```

The unpatched mapper leaves both underlying types blank:

```ada
subtype Data_Member is ;

type Method_Member is record
   uu_pfn : access ;
   uu_delta : aliased long;
end record
with Convention => C_Pass_By_Copy;
```

On the Itanium C++ ABI used by every supported repository host, a data-member
pointer is a `ptrdiff_t` byte offset with `-1` reserved for null. A
member-function pointer is two words: the first is either a function address or
an encoded virtual-table offset, and the second adjusts `this`. The corrected
Ada preserves those ABI values without claiming that Ada can dereference them:

```ada
subtype Data_Member is ptrdiff_t;

type Method_Member is record
   uu_pfn : System.Address;
   uu_delta : aliased long;
end record
with Convention => C_Pass_By_Copy;
```

`System.Address` is deliberately opaque: a virtual member-function encoding is
not an Ada access-to-subprogram value. Invocation still belongs in C++, but the
generated Ada can safely store and pass the complete value. The executable
regression obtains data, nonvirtual-function, virtual-function, and null member
pointers from C++, round-trips them through Ada, and asks C++ to apply or
classify them at `-O0` and `-O2`.

Run it against an unpatched or patched compiler root:

```sh
./bundles/cxx-ada-member-pointers/run-test.sh \
  TOOLCHAIN_ROOT GCC_VERSION unpatched
./bundles/cxx-ada-member-pointers/run-test.sh \
  TOOLCHAIN_ROOT GCC_VERSION patched
```
