/* { dg-do compile } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file explicit_alignment_c.ads "Alignment => 32" } } */

struct alignas(32) Aligned
{
  int value;
};

extern "C" unsigned long cpp_size () { return sizeof (Aligned); }
extern "C" unsigned long cpp_alignment () { return alignof (Aligned); }

/* { dg-final { cleanup-ada-spec } } */
