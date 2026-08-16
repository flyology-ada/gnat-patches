/* { dg-do compile } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file vector_types_c.ads "type Int_Vector is array \(0 .. 3\) of int;" } } */
/* { dg-final { scan-file vector_types_c.ads "for Int_Vector'Alignment use 16;" } } */
/* { dg-final { scan-file vector_types_c.ads "pragma Machine_Attribute \(Int_Vector, \"vector_type\"\);" } } */
/* { dg-final { scan-file vector_types_c.ads "type Double_Vector is array \(0 .. 1\) of double;" } } */
/* { dg-final { scan-file-times vector_types_c.ads "Convention => Ada" 3 } } */
/* { dg-final { scan-file vector_types_c.ads "function cpp_transform_vector" } } */
/* { dg-final { scan-file vector_types_c.ads "function transform" } } */

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

class Vector_Object
{
public:
  virtual ~Vector_Object () = default;
  virtual Int_Vector transform (Int_Vector value) { return value; }
};

extern "C" Vector_Object *create_vector_object ()
{
  return new Vector_Object;
}

extern "C" void delete_vector_object (Vector_Object *object)
{
  delete object;
}

extern "C" Int_Vector
cpp_transform_vector (Vector_Object *object, Int_Vector value)
{
  return object->transform (value);
}

/* { dg-final { cleanup-ada-spec } } */
