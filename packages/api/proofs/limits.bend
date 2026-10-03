# Proofs: attributes under span limits
# ====================================
#
# Attributes.set_within decides twice on computed values: whether the key is
# present (Attributes.set_within.present) and, for a new key under a count
# limit, whether the count leaves room (Attributes.set_within.fits).
# `match` cannot inspect a computed value, so each lemma here takes the
# decision as a Bool with the equation that says what it is, matches on it,
# and PROOF.bend passes the check itself with `{==}`. unlimited_step proves
# the law within_unlimited_count; bounded_fits and bounded_present prove
# within_bounded, with the length lemmas of proofs/attributes.bend and
# le_succ of proofs/nats.bend. The other laws of span limits rewrite their
# hypotheses in PROOF.bend directly.

import Base
import ../api.bend as Api
import ./nats.bend as NatsProof
import ./attributes.bend as AttributesProof

# Without a count limit, a key is set whether or not it is present.
law unlimited_step:
  for +entries: List<&2, Api.Attribute>
  for +dropped: Nat
  for +key: String
  for +value: Api.AttributeValue
  for found: Bool
  {Api.Attributes.set_within.present(None{}, entries, dropped, key, value, found) ==
    Api.Attributes{Api.Attributes.set.go(entries, key, value), dropped} : Api.Attributes}

def unlimited_step(entries, dropped, key, value, found):
  match found:
    case True{}:
      {==}
    case False{}:
      {==}

# A new key under a count limit keeps the count within the limit: when the
# count is below the limit the key is appended, one more entry, which is
# still at most the limit (NatsProof.le_succ); otherwise nothing is added.
law bounded_fits:
  for +limit: Nat
  for +entries: List<&2, Api.Attribute>
  for dropped: Nat
  for +key: String
  for +value: Api.AttributeValue
  for fits: Bool
  for seen: {Nat.is_lt(List.length(&2, Api.Attribute, entries), limit) == fits : Bool}
  for +absent: {Api.Attributes.has.go(entries, key) == False{} : Bool}
  for bound: {Nat.is_le(List.length(&2, Api.Attribute, entries), limit) == True{} : Bool}
  {Nat.is_le(Api.Attributes.count(Api.Attributes.set_within.fits(entries, dropped, key, value, fits)), limit) == True{} : Bool}

def bounded_fits(limit, entries, dropped, key, value, fits, seen, absent, bound):
  match fits:
    case True{}:
      %Equal.sym(List<&2, Api.Attribute>, Api.Attributes.set.go(entries, key, value),
        List.append(&2, Api.Attribute, entries, [Api.Attribute{key, value}]),
        AttributesProof.absent_append(entries, key, value, absent)) :
        {Nat.is_le(List.length(&2, Api.Attribute, _), limit) == True{} : Bool}
      %Equal.sym(Nat, List.length(&2, Api.Attribute, List.append(&2, Api.Attribute, entries, [Api.Attribute{key, value}])),
        1n+List.length(&2, Api.Attribute, entries),
        NatsProof.append_one_length(Api.Attribute, entries, Api.Attribute{key, value})) :
        {Nat.is_le(_, limit) == True{} : Bool}
      %Equal.sym(Bool, Nat.is_le(1n+List.length(&2, Api.Attribute, entries), limit),
        Nat.is_lt(List.length(&2, Api.Attribute, entries), limit),
        NatsProof.le_succ(List.length(&2, Api.Attribute, entries), limit)) :
        {_ == True{} : Bool}
      seen
    case False{}:
      bound

# Any set under a count limit keeps the count within the limit: a present
# key keeps the length (AttributesProof.set_length with the lookup True); a
# new key is bounded_fits.
law bounded_present:
  for +limit: Nat
  for +entries: List<&2, Api.Attribute>
  for dropped: Nat
  for +key: String
  for +value: Api.AttributeValue
  for found: Bool
  for +seen: {Api.Attributes.has.go(entries, key) == found : Bool}
  for bound: {Nat.is_le(List.length(&2, Api.Attribute, entries), limit) == True{} : Bool}
  {Nat.is_le(Api.Attributes.count(Api.Attributes.set_within.present(Some{limit}, entries, dropped, key, value, found)), limit) ==
    True{} : Bool}

def bounded_present(limit, entries, dropped, key, value, found, seen, bound):
  match found:
    case True{}:
      %Equal.sym(Nat, List.length(&2, Api.Attribute, Api.Attributes.set.go(entries, key, value)),
        AttributesProof.grown(List.length(&2, Api.Attribute, entries), Api.Attributes.has.go(entries, key)),
        AttributesProof.set_length(entries, key, value)) :
        {Nat.is_le(_, limit) == True{} : Bool}
      %Equal.sym(Bool, Api.Attributes.has.go(entries, key), True{}, seen) :
        {Nat.is_le(AttributesProof.grown(List.length(&2, Api.Attribute, entries), _), limit) == True{} : Bool}
      bound
    case False{}:
      bounded_fits(limit, entries, dropped, key, value, Nat.is_lt(List.length(&2, Api.Attribute, entries), limit), {==}, seen, bound)
