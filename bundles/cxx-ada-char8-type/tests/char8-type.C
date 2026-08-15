/* { dg-do compile { target c++20 } } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file char8_type_c.ads "value : unsigned_char" } } */
/* { dg-final { scan-file char8_type_c.ads "return unsigned_char" } } */

char8_t
char8_value (char8_t value)
{
  return value;
}

/* { dg-final { cleanup-ada-spec } } */
