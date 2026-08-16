/* { dg-do compile } */
/* { dg-require-effective-target lp64 } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file virtual_inheritance_layout_c.ads "for Virtual'Size use 128;" } } */
/* { dg-final { scan-file virtual_inheritance_layout_c.ads "for Virtual'Object_Size use 128;" } } */
/* { dg-final { scan-file virtual_inheritance_layout_c.ads "for Virtual'Alignment use 8;" } } */
/* { dg-final { scan-file virtual_inheritance_layout_c.ads "derived_value at 8 range 0 .. 31;" } } */
/* { dg-final { scan-file virtual_inheritance_layout_c.ads "field_2 at 12 range 0 .. 31;" } } */

struct Root
{
  int root_value;
};

struct Virtual : virtual Root
{
  int derived_value;
  Virtual (int root, int derived);
};

Virtual::Virtual (int root, int derived)
  : Root {root}, derived_value {derived}
{}

extern "C" unsigned long cpp_root_size () { return sizeof (Root); }
extern "C" unsigned long cpp_virtual_size () { return sizeof (Virtual); }
extern "C" unsigned long cpp_virtual_alignment () { return alignof (Virtual); }
extern "C" unsigned long cpp_derived_offset ()
{
  Virtual object (0, 0);
  return reinterpret_cast<char *> (&object.derived_value)
    - reinterpret_cast<char *> (&object);
}
extern "C" unsigned long cpp_root_offset ()
{
  Virtual object (0, 0);
  return reinterpret_cast<char *> (&object.root_value)
    - reinterpret_cast<char *> (&object);
}
extern "C" Virtual *cpp_create (int root, int derived)
{
  return new Virtual (root, derived);
}
extern "C" void cpp_delete (Virtual *object) { delete object; }
extern "C" int cpp_root_value (const Virtual *object)
{
  return object->root_value;
}
extern "C" int cpp_derived_value (const Virtual *object)
{
  return object->derived_value;
}

/* { dg-final { cleanup-ada-spec } } */
