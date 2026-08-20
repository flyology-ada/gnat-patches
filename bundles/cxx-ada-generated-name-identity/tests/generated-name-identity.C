/* { dg-do compile } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file generated_name_identity_c.ads "function inspect_Const_2" } } */
/* { dg-final { scan-file generated_name_identity_c.ads "function inspect_Const " } } */
/* { dg-final { scan-file generated_name_identity_c.ads "package Box_int_2 is" } } */
/* { dg-final { scan-file generated_name_identity_c.ads "subtype Box_int is Box_int_2.Box" } } */
/* { dg-final { scan-file generated_name_identity_c.ads "the_Widget_2 : int; the_Widget : int" } } */
/* { dg-final { scan-file generated_name_identity_c.ads "type Tail_Derived_As_Base_2" } } */
/* { dg-final { scan-file generated_name_identity_c.ads "parent_Base_2 : aliased Left" } } */
/* { dg-final { scan-file generated_name_identity_c.ads "field_2_Base_2 : aliased Right" } } */
/* { dg-final { scan-file generated_name_identity_c.ads "package Class_Gadget_2 is" } } */
/* { dg-final { scan-file generated_name_identity_c.ads "function New_Creator_2" } } */
/* { dg-final { scan-file generated_name_identity_c.ads "procedure Delete_2" } } */
/* { dg-final { scan-file generated_name_identity_c.ads "function Assign_Assigner_2" } } */

class Methods
{
public:
  int inspect () const;
  int inspect_Const ();
};

template<typename T>
struct Box
{
  T value;
};

typedef Box<int> Box_int;

struct Widget
{
  int value;
};

Widget *make_widget (int Widget, int the_Widget);

struct Tail_Base
{
  char bytes[2];
};

struct Tail_Derived_As_Base
{
  int value;
};

struct alignas(2) Tail_Derived : Tail_Base
{
  char extra;
};

struct Left
{
  int left;
};

struct Right
{
  int right;
};

struct Both : Left, Right
{
  int parent;
  int field_2;
};

struct Class_Gadget
{
  int value;
};

class Gadget
{
public:
  int ping ();
};

class Creator
{
public:
  Creator ();
  int New_Creator ();
};

class Destroyer
{
public:
  ~Destroyer ();
  static int Delete;
};

class Assigner
{
public:
  Assigner &operator= (const Assigner &);
  int Assign_Assigner ();
};

extern "C" int
generated_name_identity_oracle ()
{
  return 73;
}

/* { dg-final { cleanup-ada-spec } } */
