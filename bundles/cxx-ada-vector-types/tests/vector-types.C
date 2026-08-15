/* { dg-do compile } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file vector_types_c.ads "type Int_Vector is array \(0 .. 3\) of int;" } } */
/* { dg-final { scan-file vector_types_c.ads "for Int_Vector'Alignment use 16;" } } */
/* { dg-final { scan-file vector_types_c.ads "pragma Machine_Attribute \(Int_Vector, \"vector_type\"\);" } } */
/* { dg-final { scan-file vector_types_c.ads "type Double_Vector is array \(0 .. 1\) of double;" } } */
/* { dg-final { scan-file vector_types_c.ads "Convention => Ada" } } */

typedef int Int_Vector __attribute__((vector_size(16)));
typedef double Double_Vector __attribute__((vector_size(16)));

Int_Vector
vector_identity (Int_Vector value)
{
  return value;
}

Double_Vector
double_vector_identity (Double_Vector value)
{
  return value;
}

/* { dg-final { cleanup-ada-spec } } */
