/* { dg-do compile } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file casefold_identity_c.ads "type ITEM_Case_2" } } */
/* { dg-final { scan-file casefold_identity_c.ads "subtype ALIAS_Case_2" } } */
/* { dg-final { scan-file casefold_identity_c.ads "VALUE_Case_2" } } */
/* { dg-final { scan-file casefold_identity_c.ads "VaLuE_Case_3" } } */
/* { dg-final { scan-file casefold_identity_c.ads "function MEASURE_Case_2" } } */

struct Item
{
  int value;
};

struct ITEM
{
  double value;
};

using Alias = Item;
using ALIAS = ITEM;

struct Fields
{
  int value;
  int VALUE;
  int VaLuE;
};

int measure (Item item) { return item.value; }
int MEASURE (ITEM item) { return static_cast<int> (item.value); }
int combine (Fields fields)
{ return fields.value + fields.VALUE + fields.VaLuE; }

/* { dg-final { cleanup-ada-spec } } */
