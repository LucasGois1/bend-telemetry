# Proofs: general lemmas on Bool
# ==============================
#
# General lemmas on Base's Bool, after bend-telemetry-api's proofs/bools.bend.
# true_ne_false shows that True and False differ, and absurd closes a case
# whose hypothesis computes to {False{} == True{}}. or_left_false and
# or_right_false take apart a hypothesis saying a Bool.or returned False:
# the laws' has_percent is such a chain, so proofs/percent.bend uses them
# character by character.
#
# Bool.or inspects only its first argument, so each law is proved by cases on
# `a`, and the second argument `b` is erased (`-b`).

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

# When Bool.or(a, b) is False, `a` is False: the first character of a text
# is not a percent sign.
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

# When Bool.or(a, b) is False, `b` is False: the rest of the text has no
# percent sign either.
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
