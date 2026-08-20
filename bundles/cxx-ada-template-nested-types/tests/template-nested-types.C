/* { dg-do compile } */
/* { dg-options "-std=gnu++20 -fdump-ada-spec-slim" } */
/* { dg-final { scan-file template_nested_types_c.ads "package Buffer_int_4 is" } } */
/* { dg-final { scan-file template_nested_types_c.ads "package Defaults_int_2 is" } } */
/* { dg-final { scan-file template_nested_types_c.ads "type anon_array[0-9]+ is array \(0 \.\. 3\) of aliased int;" } } */
/* { dg-final { scan-file template_nested_types_c.ads "type anon_array[0-9]+ is array \(0 \.\. 1\) of aliased int;" } } */

template <typename T, unsigned N>
struct Buffer
{
  T values[N];
};

template struct Buffer<int, 4>;

template <typename T = int, unsigned N = 2>
struct Defaults
{
  T values[N];
};

template struct Defaults<>;

extern "C" int
buffer_sum (const Buffer<int, 4> *value)
{
  return value->values[0] + value->values[1]
    + value->values[2] + value->values[3];
}

extern "C" int
defaults_sum (const Defaults<> *value)
{
  return value->values[0] + value->values[1];
}

/* { dg-final { cleanup-ada-spec } } */
