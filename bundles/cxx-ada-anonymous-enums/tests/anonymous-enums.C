/* { dg-do compile } */
/* { dg-options "-std=gnu++20 -fdump-ada-spec-slim" } */
/* { dg-final { scan-file anonymous_enums_c.ads "Sequential_Zero" } } */
/* { dg-final { scan-file anonymous_enums_c.ads "Sequential_One" } } */
/* { dg-final { scan-file anonymous_enums_c.ads "Sparse_Minus : constant anon_enum[0-9]+ := -1;" } } */
/* { dg-final { scan-file anonymous_enums_c.ads "Sparse_Five : constant anon_enum[0-9]+ := 5;" } } */

enum { Sequential_Zero, Sequential_One };
enum { Sparse_Minus = -1, Sparse_Five = 5 };

extern "C" int
sequential_value (decltype (Sequential_Zero) value)
{
  return value;
}

extern "C" int
sparse_value (decltype (Sparse_Minus) value)
{
  return value;
}

/* { dg-final { cleanup-ada-spec } } */
