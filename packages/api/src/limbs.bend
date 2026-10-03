# 64-bit two's complement over two U32 limbs
# ==========================================
#
# The 64-bit integer of an attribute value is two U32 limbs, high and low,
# read as a two's complement number: bit 31 of the high limb is the sign
# (local ADR 0006, decided in the G8 grilling). Base has no U64 and the
# checker computes Nat in unary, so this module does its little arithmetic
# with native U32 operations only: negation, the sign, the decimal text of a
# value and the value of a decimal text. The API's Int64 operations wrap
# these; this module is internal to the package and has no type of its own,
# so that the public type and its constructor stay in api.bend.
#
# Decimal text travels in both directions through base 2^16 pieces: a
# remainder below ten times 2^16 plus a 16-bit piece fits a U32, so the
# division of a 64-bit value by ten and its multiplication by ten both run on
# U32 values without a carry that overflows.

import Base

# The upper 16 bits of a word, as a value from 0 to 65535.
def Limbs.high16(word: U32) -> U32:
  U32.shrn(word, 16n)

# The lower 16 bits of a word.
def Limbs.low16(word: U32) -> U32:
  U32.and(word, 65535)

# Whether the value whose high limb this is reads as negative: its bit 31 is
# set.
def Limbs.is_negative(high: U32) -> Bool:
  U32.is_ge(high, 2147483648)

# The second step of a two's complement negation: the complemented high limb
# takes the carry out of the low limb's increment, which happens exactly when
# the low limb was zero.
def Limbs.negate.carry(high_not: U32, low_negated: U32, carry: Bool) -> U32 & U32:
  match carry:
    case True{}:
      (U32.add(high_not, 1), low_negated)
    case False{}:
      (high_not, low_negated)

# The two's complement negation of a value: complement both limbs and add
# one, carrying from the low limb into the high one. Negating the minimum
# value gives it back, as two's complement does.
def Limbs.negate(high: U32, +low: U32) -> U32 & U32:
  Limbs.negate.carry(U32.not(high), U32.add(U32.not(low), 1), U32.is_zero(low))

# The negation of a value given as a pair of limbs, high first.
def Limbs.negate_pair(limbs: U32 & U32) -> U32 & U32:
  match limbs:
    case (high, low):
      Limbs.negate(high, low)

# The quotient of an unsigned 64-bit value by ten, as two limbs, with the
# remainder from 0 to 9. The high limb divides directly; its remainder joins
# the low limb's 16-bit pieces one at a time, each step dividing a value
# below 655360.
def Limbs.divmod10(+high: U32, +low: U32) -> (U32 & U32) & U32:
  +quotient_high = U32.div(high, 10)
  +upper = U32.add(U32.shln(U32.mod(high, 10), 16n), Limbs.high16(low))
  +quotient_upper = U32.div(upper, 10)
  +lower = U32.add(U32.shln(U32.mod(upper, 10), 16n), Limbs.low16(low))
  ((quotient_high, U32.add(U32.shln(quotient_upper, 16n), U32.div(lower, 10))), U32.mod(lower, 10))

# The decimal digit of a remainder from 0 to 9.
def Limbs.digit(remainder: U32) -> Char:
  Char.from_u32(U32.add(48, remainder))

# The state of the digit loop after one division: the quotient's limbs, and
# the remainder's digit in front of the digits found so far.
def Limbs.show_unsigned.place(step: (U32 & U32) & U32, digits: String) -> (U32 & U32) & String:
  match step:
    case (quotients, remainder):
      (quotients, SCon{Limbs.digit(remainder), digits})

# One step of the digit loop: divide the value left by ten.
def Limbs.show_unsigned.step(state: (U32 & U32) & String) -> (U32 & U32) & String:
  match state:
    case ((high, low), digits):
      Limbs.show_unsigned.place(Limbs.divmod10(high, low), digits)

# The `fuel` least significant decimal digits of the value in `state`, in
# front of its digits, least significant last: every step divides by ten and
# puts the remainder's digit in front. A fixed count of steps, whatever the
# value, keeps the recursion structural; Limbs.strip_zeros removes the
# leading zeros afterwards.
def Limbs.show_unsigned.go(fuel: Nat, state: (U32 & U32) & String) -> String:
  match fuel:
    case 0n:
      Pair.snd(U32 & U32, String, state)
    case 1n+less:
      Limbs.show_unsigned.go(less, Limbs.show_unsigned.step(state))

# A digit kept in front of the digits after it, or dropped: a leading zero.
def Limbs.strip_zeros.emit(char: Char, after: String, keep: Bool) -> String:
  match keep:
    case True{}:
      SCon{char, after}
    case False{}:
      after

# The digits from the first nonzero one on; `keep` says whether one was
# already seen.
def Limbs.strip_zeros.go(digits: String, keep: Bool) -> String:
  match digits:
    case SNil{}:
      SNil{}
    case SCon{Chr{+code}, rest}:
      +keep_now = Bool.or(keep, Bool.not(U32.is_eq(code, 48)))
      Limbs.strip_zeros.emit(Chr{code}, Limbs.strip_zeros.go(rest, keep_now), keep_now)

# Zero itself keeps one digit.
def Limbs.strip_zeros.zero(digits: String) -> String:
  match digits:
    case SNil{}:
      "0"
    case SCon{char, rest}:
      SCon{char, rest}

# The digits without their leading zeros, keeping one digit for zero itself.
def Limbs.strip_zeros(digits: String) -> String:
  Limbs.strip_zeros.zero(Limbs.strip_zeros.go(digits, False{}))

# The decimal text of an unsigned 64-bit value: at most 20 digits, since
# 2^64 - 1 has 20.
def Limbs.show_unsigned(high: U32, low: U32) -> String:
  Limbs.strip_zeros(Limbs.show_unsigned.go(20n, ((high, low), "")))

# The decimal text of a magnitude given as a pair of limbs.
def Limbs.show_magnitude(magnitude: U32 & U32) -> String:
  match magnitude:
    case (high, low):
      Limbs.show_unsigned(high, low)

# The signed decimal text: a minus sign and the magnitude for a negative
# value, the unsigned text otherwise.
def Limbs.show.sign(high: U32, low: U32, negative: Bool) -> String:
  match negative:
    case True{}:
      "-" ++ Limbs.show_magnitude(Limbs.negate(high, low))
    case False{}:
      Limbs.show_unsigned(high, low)

# The decimal text of a two's complement value: an optional minus sign and
# digits without leading zeros, as `Int64.show` answers it.
def Limbs.show(+high: U32, low: U32) -> String:
  Limbs.show.sign(high, low, Limbs.is_negative(high))

# The new magnitude when its high limb did not overflow.
def Limbs.read.push.fits(high: U32, low: U32, fits: Bool) -> Maybe<&1, U32 & U32>:
  match fits:
    case True{}:
      Some{(high, low)}
    case False{}:
      None{}

# The accumulated magnitude times ten plus a digit, or None when the result
# would not fit 64 bits. The low limb is multiplied in two 16-bit pieces, and
# the carry into the high limb is at most 9, so the high limb overflowed
# exactly when dividing the new high limb by ten does not give the old one
# back, the check that Base's U32.read makes.
def Limbs.read.push.digit(+high: U32, +low: U32, digit: U32) -> Maybe<&1, U32 & U32>:
  +lower = U32.add(U32.mul(Limbs.low16(low), 10), digit)
  +upper = U32.add(U32.mul(Limbs.high16(low), 10), Limbs.high16(lower))
  +new_low = U32.or(U32.shln(Limbs.low16(upper), 16n), Limbs.low16(lower))
  +new_high = U32.add(U32.mul(high, 10), Limbs.high16(upper))
  Limbs.read.push.fits(new_high, new_low, U32.is_eq(U32.div(new_high, 10), high))

# Add one character to the magnitude: a decimal digit extends it, anything
# else ends the reading with None.
def Limbs.read.push.char(high: U32, low: U32, code: U32, is_digit: Bool) -> Maybe<&1, U32 & U32>:
  match is_digit:
    case True{}:
      Limbs.read.push.digit(high, low, U32.sub(code, 48))
    case False{}:
      None{}

# Feed one character to the reading so far: None stays None.
def Limbs.read.push(state: Maybe<&1, U32 & U32>, char: Char) -> Maybe<&1, U32 & U32>:
  match state char:
    case None{} _:
      None{}
    case Some{(high, low)} Chr{+code}:
      Limbs.read.push.char(high, low, code, Bool.and(U32.is_ge(code, 48), U32.is_le(code, 57)))

# The unsigned value of a run of digits, fed one character at a time to the
# state. The recursion is on the text, so the reading is total.
def Limbs.read.digits(text: String, state: Maybe<&1, U32 & U32>) -> Maybe<&1, U32 & U32>:
  match text:
    case SNil{}:
      state
    case SCon{char, rest}:
      Limbs.read.digits(rest, Limbs.read.push(state, char))

# The unsigned value of a text of at least one decimal digit, or None.
def Limbs.read.magnitude(text: String) -> Maybe<&1, U32 & U32>:
  match text:
    case SNil{}:
      None{}
    case SCon{char, rest}:
      Limbs.read.digits(SCon{char, rest}, Some{(0, 0)})

# A magnitude as a positive value, when it is at most 2^63 - 1: the high limb
# is below 2^31.
def Limbs.read.positive(high: U32, low: U32, fits: Bool) -> Maybe<&1, U32 & U32>:
  match fits:
    case True{}:
      Some{(high, low)}
    case False{}:
      None{}

# A magnitude negated, when it is at most 2^63: the high limb is below 2^31,
# or it is exactly 2^31 with a zero low limb, the minimum value.
def Limbs.read.negative(high: U32, low: U32, fits: Bool) -> Maybe<&1, U32 & U32>:
  match fits:
    case True{}:
      Some{Limbs.negate(high, low)}
    case False{}:
      None{}

# Apply the sign to a magnitude that was read, checking its range.
def Limbs.read.signed(negative: Bool, magnitude: Maybe<&1, U32 & U32>) -> Maybe<&1, U32 & U32>:
  match negative magnitude:
    case _ None{}:
      None{}
    case True{} Some{(+high, +low)}:
      Limbs.read.negative(high, low, Bool.or(U32.is_lt(high, 2147483648),
        Bool.and(U32.is_eq(high, 2147483648), U32.is_zero(low))))
    case False{} Some{(+high, low)}:
      Limbs.read.positive(high, low, U32.is_lt(high, 2147483648))

# A text that starts with `first`: a minus sign followed by the magnitude's
# digits, or the digits themselves.
def Limbs.read.start(first: Char, rest: String, minus: Bool) -> Maybe<&1, U32 & U32>:
  match minus:
    case True{}:
      Limbs.read.signed(True{}, Limbs.read.magnitude(rest))
    case False{}:
      Limbs.read.signed(False{}, Limbs.read.magnitude(SCon{first, rest}))

# The value of a decimal text: an optional minus sign and at least one digit,
# from -9223372036854775808 to 9223372036854775807. Leading zeros are
# accepted, as Base's U32.read accepts them; anything else answers None.
def Limbs.read(text: String) -> Maybe<&1, U32 & U32>:
  match text:
    case SNil{}:
      None{}
    case SCon{+first, rest}:
      Limbs.read.start(first, rest, Char.is_eq(first, '-'))

# The limbs of a natural number, which Base keeps below 2^48: the high limb
# is the quotient by 2^32 and the low limb the remainder. Dividing by 2^16
# twice keeps the divisor small enough for the checker, which computes Nat in
# unary, to evaluate literal cases; at run time Nat is native.
def Limbs.of_nat(+value: Nat) -> U32 & U32:
  +upper = U32.from_nat(Nat.div(value, 65536n))
  (U32.shrn(upper, 16n), U32.or(U32.shln(upper, 16n), U32.from_nat(Nat.mod(value, 65536n))))
