# Proofs: words and strings compare equal with themselves
# ======================================================
#
# Base compares characters by their 32-bit codes and strings character by
# character: String.eq(a, b) is Cmp.is_eq of String.cmp's result, and each
# character's code is compared by Word.cmp. This module proves the
# reflexivity that the attribute laws need, after bend-trace-context's
# proofs/chars.bend and proofs/strings.bend: every word compares EQ with
# itself (word_cmp_refl), so every string equals itself by String.eq
# (eq_refl). proofs/attributes.bend uses eq_refl where a key just appended
# is looked up, and PROOF.bend uses word_cmp_refl for the nanoseconds of a
# timestamp compared with itself.

import Base

# Every word compares EQ with itself. Induction on the width n: the
# recursive call rewrites the tails' comparison to EQ, and Word.cmp.fin of
# two equal bits is then EQ.
law word_cmp_refl:
  for +n: Nat
  for w: Word(n)
  {Word.cmp(n, w, w) == EQ{} : Cmp}

def word_cmp_refl(n, w):
  match n:
    case 0n:
      {==}
    case 1n+p:
      match w:
        case WCon{False{}, +tail}:
          %Equal.sym(Cmp, Word.cmp(p, tail, tail), EQ{}, word_cmp_refl(p, tail)) :
            {Word.cmp.fin(False{}, False{}, _) == EQ{} : Cmp}
          {==}
        case WCon{True{}, +tail}:
          %Equal.sym(Cmp, Word.cmp(p, tail, tail), EQ{}, word_cmp_refl(p, tail)) :
            {Word.cmp.fin(True{}, True{}, _) == EQ{} : Cmp}
          {==}

# What String.eq reads of a comparison: whether its Cmp is EQ. Base defines
# String.eq(a, b) as Cmp.is_eq(String.order(a, b)), and String.order as the
# Cmp of String.cmp, so String.eq(a, b) is eq_of(String.cmp(a, b)) by
# computation.
def eq_of(r: (String & String) & Cmp) -> Bool:
  Cmp.is_eq(Pair.snd(String & String, Cmp, r))

# Putting two characters back in front of a comparison (String.cmp.rec)
# keeps the equality it reports: eq_of reads only the Cmp, which
# String.cmp.rec passes on. By computation, once `rest` is split into its
# parts.
law compare_rest:
  for -first: Char
  for -second: Char
  for rest: (String & String) & Cmp
  {eq_of(String.cmp.rec(first, second, rest)) == eq_of(rest) : Bool}

def compare_rest(first, second, rest):
  match rest:
    case ((left, right), result):
      {==}

# Every string is equal to itself by String.eq. Induction on the text: the
# first codes compare EQ (word_cmp_refl) and compare_rest moves to the tails.
law eq_refl:
  for +text: String
  {String.eq(text, text) == True{} : Bool}

def eq_refl(text):
  match text:
    case SNil{}:
      {==}
    case SCon{Chr{U32{+code}}, +tail}:
      %Equal.sym(Cmp, Word.cmp(32n, code, code), EQ{}, word_cmp_refl(32n, code)) :
        {eq_of(String.cmp.fin(tail, tail, ((Chr{U32{code}}, Chr{U32{code}}), _))) == True{} : Bool}
      Equal.trans(Bool,
        eq_of(String.cmp.rec(Chr{U32{code}}, Chr{U32{code}}, String.cmp(tail, tail))),
        eq_of(String.cmp(tail, tail)), True{},
        compare_rest(Chr{U32{code}}, Chr{U32{code}}, String.cmp(tail, tail)), eq_refl(tail))
