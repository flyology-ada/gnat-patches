/* { dg-do compile } */
/* { dg-options "-fdump-ada-spec-slim" } */
/* { dg-final { scan-file int128_types_c.ads "subtype Signed_128 is Extensions.Signed_128" } } */
/* { dg-final { scan-file int128_types_c.ads "subtype Unsigned_128 is Extensions.Unsigned_128" } } */

using Signed_128 = __int128;
using Unsigned_128 = unsigned __int128;

static const Signed_128 signed_expected
  = -((static_cast<Signed_128> (1) << 100) + 12345);
static const Unsigned_128 unsigned_expected
  = (static_cast<Unsigned_128> (1) << 127)
    | (static_cast<Unsigned_128> (1) << 80) | 67890;

Signed_128 signed_seed () { return signed_expected; }
Unsigned_128 unsigned_seed () { return unsigned_expected; }

Signed_128 signed_round_trip (Signed_128 value) { return value; }
Unsigned_128 unsigned_round_trip (Unsigned_128 value) { return value; }

int signed_matches (Signed_128 value) { return value == signed_expected; }
int unsigned_matches (Unsigned_128 value) { return value == unsigned_expected; }
