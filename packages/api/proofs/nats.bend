# Proofs: Nat comparisons and lengths
# ===================================
#
# General lemmas on Base's Nat and on list lengths, after
# bend-trace-context's proofs/nats.bend. le_succ says that the check
# a + 1 <= b gives the same Bool as a < b: proofs/limits.bend uses it where a
# collection below its count limit takes one more attribute. cmp_refl says
# that every number compares EQ with itself: PROOF.bend uses it for the
# seconds of a timestamp compared with itself. take_length says that taking
# fewer characters than a text has gives exactly that many:
# proofs/values.bend uses it for truncation. append_one_length counts a list
# with one element appended.
#
# Nat.is_le and Nat.is_lt both read Nat.cmp, which removes one from each side
# until one of them is zero, so the proofs are inductions on both numbers at
# once.

import Base
import ./bools.bend as BoolsProof

# Nat.is_le(1n+a, b) equals Nat.is_lt(a, b) for every a and b: a + 1 <= b
# exactly when a < b.
law le_succ:
  for a: Nat
  for b: Nat
  {Nat.is_le(1n+a, b) == Nat.is_lt(a, b) : Bool}

# With a = 0n, `more` is matched only so that Nat.cmp(0n, more) computes.
def le_succ(a, b):
  match a:
    case 0n:
      match b:
        case 0n:
          {==}
        case 1n+more:
          match more:
            case 0n:
              {==}
            case 1n+rest:
              {==}
    case 1n+less:
      match b:
        case 0n:
          {==}
        case 1n+more:
          le_succ(less, more)

# Every number compares EQ with itself. Induction on the number.
law cmp_refl:
  for n: Nat
  {Nat.cmp(n, n) == EQ{} : Cmp}

def cmp_refl(n):
  match n:
    case 0n:
      {==}
    case 1n+p:
      cmp_refl(p)

# Taking `n` characters of a text longer than `n` gives `n` characters.
# Induction on the text and `n` together: an empty text is longer than
# nothing, so `longer` is a clash there unless `n` is zero, where nothing is
# taken; a text and an `n` with a successor each take the first character
# and continue.
law take_length:
  for text: String
  for n: Nat
  for longer: {Nat.is_lt(n, String.length(text)) == True{} : Bool}
  {String.length(String.take(text, n)) == n : Nat}

def take_length(text, n, longer):
  match text:
    case SNil{}:
      match n:
        case 0n:
          {==}
        case 1n+p:
          BoolsProof.absurd({0n == 1n+p : Nat}, longer)
    case SCon{head, tail}:
      match n:
        case 0n:
          {==}
        case 1n+p:
          %Equal.sym(Nat, String.length(String.take(tail, p)), p, take_length(tail, p, longer)) : {1n+_ == 1n+p : Nat}
          {==}

# A list with one element appended has one more element. Induction on the
# list.
law append_one_length:
  for -A: Data
  for xs: List<&2, A>
  for -x: A
  {List.length(&2, A, List.append(&2, A, xs, [x])) == 1n+List.length(&2, A, xs) : Nat}

def append_one_length(A, xs, x):
  match xs:
    case Nil{}:
      {==}
    case Con{head, tail}:
      %Equal.sym(Nat, List.length(&2, A, List.append(&2, A, tail, [x])), 1n+List.length(&2, A, tail), append_one_length(A, tail, x)) :
        {1n+_ == 1n+(1n+List.length(&2, A, tail)) : Nat}
      {==}
