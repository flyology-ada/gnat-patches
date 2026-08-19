--  { dg-do run }
--  { dg-options "-O2 -gnat2022" }

pragma Assertion_Policy (Dynamic_Predicate => Check);

with Ada.Assertions; use Ada.Assertions;
with Ada.Text_IO;    use Ada.Text_IO;

procedure Predicate_Conditional_Aggregate_Box is

   type Policy is record
      Low  : Natural := 1;
      High : Natural := 25;
   end record
     with Dynamic_Predicate => Policy.High >= Policy.Low;

   type Config is record
      Watch : Policy;
   end record;

   Static_Flag : constant Boolean := True;

   Enforced : Natural := 0;
   --  Number of predicate violations reported at run time

   function Ident (Value : Boolean) return Boolean;
   --  Identity function, used to keep the condition of a conditional
   --  expression from being known at compile time.

   procedure Check (Label : String; Actual, Expected : Natural);
   --  Report a mismatch between an observed and an expected component value

   procedure Verify (C : Config; Label : String; Low, High : Natural);
   --  Check both components of the inner record of C

   -----------
   -- Check --
   -----------

   procedure Check (Label : String; Actual, Expected : Natural) is
   begin
      if Actual /= Expected then
         raise Program_Error with
           Label & " is" & Natural'Image (Actual)
             & " instead of" & Natural'Image (Expected);
      end if;
   end Check;

   -----------
   -- Ident --
   -----------

   function Ident (Value : Boolean) return Boolean is
   begin
      return Value;
   end Ident;

   ------------
   -- Verify --
   ------------

   procedure Verify (C : Config; Label : String; Low, High : Natural) is
   begin
      Check (Label & " low", C.Watch.Low, Low);
      Check (Label & " high", C.Watch.High, High);
   end Verify;

begin
   --  A box in a branch of a conditional expression that is a component
   --  association of an enclosing aggregate must supply the component
   --  defaults of the inner record type, here High => 25.

   --  Static condition, others box, object declaration

   declare
      C : constant Config :=
        (Watch => (if Static_Flag then (Low => 1, others => <>)
                                  else (Low => 2, others => <>)));
   begin
      Verify (C, "static others box", Low => 1, High => 25);
   end;

   --  Dynamic condition, named component box, object declaration

   declare
      C : constant Config :=
        (Watch => (if Ident (True) then (Low => 3, High => <>)
                                   else (Low => 4, High => <>)));
   begin
      Verify (C, "dynamic named box", Low => 3, High => 25);
   end;

   --  Dynamic condition, others box, assignment statement

   declare
      C : Config;
   begin
      C := (Watch => (if Ident (False) then (Low => 5, others => <>)
                                       else (Low => 6, others => <>)));
      Verify (C, "assigned others box", Low => 6, High => 25);
   end;

   --  Dynamic condition, named component box, assignment statement

   declare
      C : Config;
   begin
      C := (Watch => (if Ident (True) then (Low => 7, High => <>)
                                      else (Low => 8, High => <>)));
      Verify (C, "assigned named box", Low => 7, High => 25);
   end;

   --  Case expression, others box, object declaration

   declare
      C : constant Config :=
        (Watch => (case Ident (True) is
                      when True  => (Low => 9, others => <>),
                      when False => (Low => 10, others => <>)));
   begin
      Verify (C, "case others box", Low => 9, High => 25);
   end;

   --  The predicate must still be enforced on the selected branch, in an
   --  object declaration and in an assignment statement alike. The defaulted
   --  High is 25, so a Low above it violates Policy.High >= Policy.Low.

   begin
      declare
         C : constant Config :=
           (Watch => (if Ident (True) then (Low => 30, others => <>)
                                      else (Low => 2, others => <>)));
      begin
         Verify (C, "unenforced declaration", Low => 30, High => 25);
      end;
   exception
      when Assertion_Error =>
         Enforced := Enforced + 1;
   end;

   begin
      declare
         C : Config;
      begin
         C := (Watch => (if Ident (False) then (Low => 1, others => <>)
                                          else (Low => 40, High => <>)));
         Verify (C, "unenforced assignment", Low => 40, High => 25);
      end;
   exception
      when Assertion_Error =>
         Enforced := Enforced + 1;
   end;

   Check ("enforced predicate violations", Enforced, 2);

   Put_Line ("PASS predicate conditional aggregate box");
end Predicate_Conditional_Aggregate_Box;
