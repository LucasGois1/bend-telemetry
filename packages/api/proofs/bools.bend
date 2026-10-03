# Proofs: general lemmas on Bool
# ==============================
#
# General lemmas on Base's Bool, after bend-trace-context's proofs/bools.bend.
# true_ne_false shows that True and False differ, and absurd closes a case
# whose hypothesis computes to {False{} == True{}}. The others take apart a
# hypothesis saying a check returned True or False: each half of a true
# Bool.and, each half of a false Bool.or and the argument of a true Bool.not;
# or_false and or_assoc settle and regroup a chain of Bool.or. The package's
# lookups (Attributes.has.go) and the laws' keys_distinct are such chains,
# so proofs/attributes.bend and proofs/limits.bend use these lemmas
# throughout.
#
# Bool.and, Bool.or and Bool.not inspect only their first argument, so each
# law is proved by cases on `a`, and a second argument `b` is erased (`-b`).

import Base

# The motive that refutes {True{} == False{}}: Empty for False and Unit for
# True. Rewriting with the clash turns the goal Empty, which is
# BoolClash(False{}), into BoolClash(True{}), which is Unit.
def BoolClash(value: Bool) -> Type:
  match value:
    case False{}:
      Empty
    case True{}:
      Unit

# True and False are different: an equation {True{} == False{}} yields
# Empty, the type without values, so a case that assumes it cannot happen.
law true_ne_false:
  for clash: {True{} == False{} : Bool}
  Empty

def true_ne_false(clash):
  %clash : BoolClash(_)
  Unit{}

# From the impossible equation {False{} == True{}}, anything follows: absurd
# proves any goal `A`, which the caller passes and which is erased.
def absurd(-A: Type, clash: {False{} == True{} : Bool}) -> A:
  Empty.absurd(A, true_ne_false(Equal.sym(Bool, False{}, True{}, clash)))

# When Bool.not(a) is True, `a` is False: the first check of keys_distinct,
# that a key is not among the keys after it.
law not_true:
  for a: Bool
  for holds: {Bool.not(a) == True{} : Bool}
  {a == False{} : Bool}

def not_true(a, holds):
  match a:
    case False{}:
      {==}
    case True{}:
      absurd({True{} == False{} : Bool}, holds)

# When Bool.and(a, b) is True, `a` is True: the first check of a chain.
law and_left:
  for a: Bool
  for -b: Bool
  for both: {Bool.and(a, b) == True{} : Bool}
  {a == True{} : Bool}

# In the False case the goal {False{} == True{}} is the hypothesis itself.
def and_left(a, b, both):
  match a:
    case False{}:
      both
    case True{}:
      {==}

# When Bool.and(a, b) is True, `b` is True: the rest of a chain after its
# first check.
law and_right:
  for a: Bool
  for -b: Bool
  for both: {Bool.and(a, b) == True{} : Bool}
  {b == True{} : Bool}

def and_right(a, b, both):
  match a:
    case False{}:
      absurd({b == True{} : Bool}, both)
    case True{}:
      both

# When Bool.or(a, b) is False, `a` is False: the comparison with the first
# entry of a lookup that found nothing.
law or_left_false:
  for a: Bool
  for -b: Bool
  for both: {Bool.or(a, b) == False{} : Bool}
  {a == False{} : Bool}

# In the True case the goal {True{} == False{}} is the hypothesis itself.
def or_left_false(a, b, both):
  match a:
    case False{}:
      {==}
    case True{}:
      both

# When Bool.or(a, b) is False, `b` is False: the lookup in the rest of the
# list found nothing either.
law or_right_false:
  for a: Bool
  for -b: Bool
  for both: {Bool.or(a, b) == False{} : Bool}
  {b == False{} : Bool}

def or_right_false(a, b, both):
  match a:
    case False{}:
      both
    case True{}:
      Empty.absurd({b == False{} : Bool}, true_ne_false(both))

# False is a right identity of Bool.or: Bool.or(a, False{}) is `a`, by cases
# on `a`. proofs/attributes.bend uses it once the comparison with an appended
# key is known to be False.
law or_false:
  for a: Bool
  {Bool.or(a, False{}) == a : Bool}

def or_false(a):
  match a:
    case False{}:
      {==}
    case True{}:
      {==}

# Bool.or is associative. Bool.or inspects only its first argument, so the
# proof matches on `a` alone, and `b` and `c` are erased.
# proofs/attributes.bend uses it to regroup a lookup over an appended key.
law or_assoc:
  for a: Bool
  for -b: Bool
  for -c: Bool
  {Bool.or(a, Bool.or(b, c)) == Bool.or(Bool.or(a, b), c) : Bool}

def or_assoc(a, b, c):
  match a:
    case False{}:
      {==}
    case True{}:
      {==}
