/* { dg-do compile } */
/* { dg-require-effective-target lp64 } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file virtual_diamond_layout_c.ads "type Diamond_Left_As_Base" } } */
/* { dg-final { scan-file virtual_diamond_layout_c.ads "for Diamond_Left_As_Base'Object_Size use 96;" } } */
/* { dg-final { scan-file virtual_diamond_layout_c.ads "type Diamond_Right_As_Base" } } */
/* { dg-final { scan-file virtual_diamond_layout_c.ads "for Diamond_Right_As_Base'Object_Size use 96;" } } */
/* { dg-final { scan-file virtual_diamond_layout_c.ads "parent : aliased Diamond_Left_As_Base;" } } */
/* { dg-final { scan-file virtual_diamond_layout_c.ads "field_2 : aliased Diamond_Right_As_Base;" } } */

struct Diamond_Root
{
  int root_value;
};

struct Diamond_Left : virtual Diamond_Root
{
  int left_value;
};

struct Diamond_Right : virtual Diamond_Root
{
  int right_value;
};

struct Diamond : Diamond_Left, Diamond_Right
{
  int diamond_value;
  Diamond (int root, int left, int right, int diamond_arg);
};

Diamond::Diamond (int root, int left, int right, int diamond_arg)
  : Diamond_Root {root}, Diamond_Left {}, Diamond_Right {},
    diamond_value {diamond_arg}
{
  left_value = left;
  right_value = right;
}

extern "C" unsigned long cpp_diamond_root_size ()
{
  return sizeof (Diamond_Root);
}

extern "C" unsigned long cpp_diamond_size ()
{
  return sizeof (Diamond);
}

extern "C" unsigned long cpp_diamond_alignment ()
{
  return alignof (Diamond);
}

extern "C" unsigned long cpp_diamond_left_offset ()
{
  Diamond object (0, 0, 0, 0);
  return reinterpret_cast<char *> (&object.left_value)
    - reinterpret_cast<char *> (&object);
}

extern "C" unsigned long cpp_diamond_right_offset ()
{
  Diamond object (0, 0, 0, 0);
  return reinterpret_cast<char *> (&object.right_value)
    - reinterpret_cast<char *> (&object);
}

extern "C" unsigned long cpp_diamond_value_offset ()
{
  Diamond object (0, 0, 0, 0);
  return reinterpret_cast<char *> (&object.diamond_value)
    - reinterpret_cast<char *> (&object);
}

extern "C" unsigned long cpp_diamond_root_offset ()
{
  Diamond object (0, 0, 0, 0);
  return reinterpret_cast<char *> (&object.root_value)
    - reinterpret_cast<char *> (&object);
}

extern "C" Diamond *cpp_diamond_create
  (int root, int left, int right, int diamond_arg)
{
  return new Diamond (root, left, right, diamond_arg);
}

extern "C" void cpp_diamond_delete (Diamond *object)
{
  delete object;
}

extern "C" int cpp_diamond_root_value (const Diamond *object)
{
  return object->root_value;
}

extern "C" int cpp_diamond_left_value (const Diamond *object)
{
  return object->left_value;
}

extern "C" int cpp_diamond_right_value (const Diamond *object)
{
  return object->right_value;
}

extern "C" int cpp_diamond_value (const Diamond *object)
{
  return object->diamond_value;
}

/* { dg-final { cleanup-ada-spec } } */
