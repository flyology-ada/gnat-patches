--  { dg-do compile }
--  { dg-require-effective-target lp64 }

procedure Cpp_Tail_Padding is
   pragma Warnings (Off);

   type Tail_Base is tagged limited record
      Value : Integer;
   end record
   with Import => True,
        Convention => CPP;

   for Tail_Base'Size use 96;
   for Tail_Base'Object_Size use 128;
   for Tail_Base use record
      Value at 8 range 0 .. 31;
   end record;

   type Tail_Derived is limited new Tail_Base with record
      Extra : Integer;
   end record
   with Import => True,
        Convention => CPP;

   for Tail_Derived'Size use 128;
   for Tail_Derived'Object_Size use 128;
   for Tail_Derived use record
      Extra at 12 range 0 .. 31;
   end record;
begin
   null;
end Cpp_Tail_Padding;
