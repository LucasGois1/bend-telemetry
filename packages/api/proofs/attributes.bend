# Proofs: the attribute collection
# ================================
#
# The list of attributes behind Attributes: setting a key, looking it up,
# the length and the keys after a set, and the distinctness of the keys.
# PROOF.bend proves the laws set_get, replace_keeps_count,
# replace_keeps_position, new_key_last and keys_unique of LAWS.bend with
# these lemmas, each applied to the list inside the collection;
# proofs/limits.bend uses set_length and absent_append to bound the count
# under span limits.
#
# Strategy. Attributes.set.go and Attributes.get.go compute the rest of the
# list before a step helper decides on the comparison of the first entry's
# key with the key sought, and `match` cannot inspect a computed value. So
# each induction has a step lemma that takes the comparison as a Bool `same`
# (with its equation `seen` where the proof needs it) and the claim for the
# tail as `rest`, and matches on `same`; the induction then passes the
# comparison itself, `{==}` for its equation, and the recursive call. The
# facts that depend on whether the key was present are stated first for
# every list, with the lookup's result as an argument of a small function
# (grown, keys_with), and read for the present and the absent case
# afterwards; the one fact that holds only for an absent key
# (absent_append) carries its hypothesis, which or_right_false passes to
# the tail.

import Base
import ../LAWS.bend as Laws
import ../api.bend as Api
import ./bools.bend as BoolsProof
import ./strings.bend as StringsProof

# Set then get
# ------------

# The step of set_get: getting the key after the step helper replaced the
# first entry (`same` True) answers the value put there, and after it kept
# the entry (`same` False) answers what the rest gives.
law set_get_step:
  for +head: Api.Attribute
  for +tail: List<&2, Api.Attribute>
  for +key: String
  for +value: Api.AttributeValue
  for same: Bool
  for seen: {String.eq(Api.Attribute.key(head), key) == same : Bool}
  for rest: {Api.Attributes.get.go(Api.Attributes.set.go(tail, key, value), key) == Some{value} : Maybe<&2, Api.AttributeValue>}
  {Api.Attributes.get.go(Api.Attributes.set.step(head, tail, Api.Attributes.set.go(tail, key, value), value, same), key) ==
    Some{value} : Maybe<&2, Api.AttributeValue>}

def set_get_step(head, tail, key, value, same, seen, rest):
  match same:
    case True{}:
      %Equal.sym(Bool, String.eq(Api.Attribute.key(head), key), True{}, seen) :
        {Api.Attributes.get.step(Api.Attribute{Api.Attribute.key(head), value}, Api.Attributes.get.go(tail, key), _) ==
          Some{value} : Maybe<&2, Api.AttributeValue>}
      {==}
    case False{}:
      %Equal.sym(Bool, String.eq(Api.Attribute.key(head), key), False{}, seen) :
        {Api.Attributes.get.step(head, Api.Attributes.get.go(Api.Attributes.set.go(tail, key, value), key), _) ==
          Some{value} : Maybe<&2, Api.AttributeValue>}
      rest

# Getting a key just set answers the value. Induction on the list: the empty
# list holds the one new entry, whose key equals itself (StringsProof.eq_refl).
law set_get:
  for entries: List<&2, Api.Attribute>
  for +key: String
  for +value: Api.AttributeValue
  {Api.Attributes.get.go(Api.Attributes.set.go(entries, key, value), key) == Some{value} : Maybe<&2, Api.AttributeValue>}

def set_get(entries, key, value):
  match entries:
    case Nil{}:
      %Equal.sym(Bool, String.eq(key, key), True{}, StringsProof.eq_refl(key)) :
        {Api.Attributes.get.step(Api.Attribute{key, value}, None{}, _) == Some{value} : Maybe<&2, Api.AttributeValue>}
      {==}
    case Con{+head, +tail}:
      set_get_step(head, tail, key, value, String.eq(Api.Attribute.key(head), key), {==}, set_get(tail, key, value))

# The length after a set
# ----------------------

# The length after a set, from the length before and whether the key was
# found: the same when it was, one more when it was not.
def grown(length: Nat, found: Bool) -> Nat:
  match found:
    case True{}:
      length
    case False{}:
      1n+length

# One more entry before the set is one more after it, whatever was found.
law grown_succ:
  for -length: Nat
  for found: Bool
  {grown(1n+length, found) == 1n+grown(length, found) : Nat}

def grown_succ(length, found):
  match found:
    case True{}:
      {==}
    case False{}:
      {==}

# The step of set_length: the first entry counts once on both sides, and the
# lookup's result for the whole list is `same` or the tail's.
law set_length_step:
  for +head: Api.Attribute
  for +tail: List<&2, Api.Attribute>
  for +key: String
  for +value: Api.AttributeValue
  for same: Bool
  for rest: {List.length(&2, Api.Attribute, Api.Attributes.set.go(tail, key, value)) ==
    grown(List.length(&2, Api.Attribute, tail), Api.Attributes.has.go(tail, key)) : Nat}
  {List.length(&2, Api.Attribute, Api.Attributes.set.step(head, tail, Api.Attributes.set.go(tail, key, value), value, same)) ==
    grown(1n+List.length(&2, Api.Attribute, tail), Bool.or(same, Api.Attributes.has.go(tail, key))) : Nat}

def set_length_step(head, tail, key, value, same, rest):
  match same:
    case True{}:
      {==}
    case False{}:
      %Equal.sym(Nat, List.length(&2, Api.Attribute, Api.Attributes.set.go(tail, key, value)),
        grown(List.length(&2, Api.Attribute, tail), Api.Attributes.has.go(tail, key)), rest) :
        {1n+_ == grown(1n+List.length(&2, Api.Attribute, tail), Api.Attributes.has.go(tail, key)) : Nat}
      Equal.sym(Nat, grown(1n+List.length(&2, Api.Attribute, tail), Api.Attributes.has.go(tail, key)),
        1n+grown(List.length(&2, Api.Attribute, tail), Api.Attributes.has.go(tail, key)),
        grown_succ(List.length(&2, Api.Attribute, tail), Api.Attributes.has.go(tail, key)))

# The length after a set is the length before, grown by whether the key was
# found. Induction on the list.
law set_length:
  for entries: List<&2, Api.Attribute>
  for +key: String
  for +value: Api.AttributeValue
  {List.length(&2, Api.Attribute, Api.Attributes.set.go(entries, key, value)) ==
    grown(List.length(&2, Api.Attribute, entries), Api.Attributes.has.go(entries, key)) : Nat}

def set_length(entries, key, value):
  match entries:
    case Nil{}:
      {==}
    case Con{+head, +tail}:
      set_length_step(head, tail, key, value, String.eq(Api.Attribute.key(head), key), set_length(tail, key, value))

# Setting a key the list has keeps the length: the lookup is True, and grown
# leaves the length alone.
law present_length:
  for +entries: List<&2, Api.Attribute>
  for +key: String
  for +value: Api.AttributeValue
  for present: {Api.Attributes.has.go(entries, key) == True{} : Bool}
  {List.length(&2, Api.Attribute, Api.Attributes.set.go(entries, key, value)) == List.length(&2, Api.Attribute, entries) : Nat}

def present_length(entries, key, value, present):
  %present : {List.length(&2, Api.Attribute, Api.Attributes.set.go(entries, key, value)) ==
    grown(List.length(&2, Api.Attribute, entries), _) : Nat}
  set_length(entries, key, value)

# The keys after a set
# --------------------

# The keys after a set, from the keys before and whether the key was found:
# the same when it was, the key appended when it was not.
def keys_with(keys: List<&2, String>, key: String, found: Bool) -> List<&2, String>:
  match found:
    case True{}:
      keys
    case False{}:
      List.append(&2, String, keys, [key])

# A first key stays in front, whatever was found.
law keys_with_cons:
  for -first: String
  for -keys: List<&2, String>
  for -key: String
  for found: Bool
  {keys_with(Con{first, keys}, key, found) == Con{first, keys_with(keys, key, found)} : List<&2, String>}

def keys_with_cons(first, keys, key, found):
  match found:
    case True{}:
      {==}
    case False{}:
      {==}

# The step of set_keys: a replaced first entry keeps its key, so both sides
# are the keys before; a kept first entry stays in front of the tail's keys.
law set_keys_step:
  for +head: Api.Attribute
  for +tail: List<&2, Api.Attribute>
  for +key: String
  for +value: Api.AttributeValue
  for same: Bool
  for rest: {Api.Attributes.keys.go(Api.Attributes.set.go(tail, key, value)) ==
    keys_with(Api.Attributes.keys.go(tail), key, Api.Attributes.has.go(tail, key)) : List<&2, String>}
  {Api.Attributes.keys.go(Api.Attributes.set.step(head, tail, Api.Attributes.set.go(tail, key, value), value, same)) ==
    keys_with(Con{Api.Attribute.key(head), Api.Attributes.keys.go(tail)}, key, Bool.or(same, Api.Attributes.has.go(tail, key))) : List<&2, String>}

def set_keys_step(head, tail, key, value, same, rest):
  match same:
    case True{}:
      {==}
    case False{}:
      %Equal.sym(List<&2, String>, Api.Attributes.keys.go(Api.Attributes.set.go(tail, key, value)),
        keys_with(Api.Attributes.keys.go(tail), key, Api.Attributes.has.go(tail, key)), rest) :
        {Con{Api.Attribute.key(head), _} ==
          keys_with(Con{Api.Attribute.key(head), Api.Attributes.keys.go(tail)}, key, Api.Attributes.has.go(tail, key)) : List<&2, String>}
      Equal.sym(List<&2, String>,
        keys_with(Con{Api.Attribute.key(head), Api.Attributes.keys.go(tail)}, key, Api.Attributes.has.go(tail, key)),
        Con{Api.Attribute.key(head), keys_with(Api.Attributes.keys.go(tail), key, Api.Attributes.has.go(tail, key))},
        keys_with_cons(Api.Attribute.key(head), Api.Attributes.keys.go(tail), key, Api.Attributes.has.go(tail, key)))

# The keys after a set are the keys before, with the key appended when it was
# not found. Induction on the list.
law set_keys:
  for entries: List<&2, Api.Attribute>
  for +key: String
  for +value: Api.AttributeValue
  {Api.Attributes.keys.go(Api.Attributes.set.go(entries, key, value)) ==
    keys_with(Api.Attributes.keys.go(entries), key, Api.Attributes.has.go(entries, key)) : List<&2, String>}

def set_keys(entries, key, value):
  match entries:
    case Nil{}:
      {==}
    case Con{+head, +tail}:
      set_keys_step(head, tail, key, value, String.eq(Api.Attribute.key(head), key), set_keys(tail, key, value))

# Setting a key the list has keeps every key in its place.
law present_keys:
  for +entries: List<&2, Api.Attribute>
  for +key: String
  for +value: Api.AttributeValue
  for present: {Api.Attributes.has.go(entries, key) == True{} : Bool}
  {Api.Attributes.keys.go(Api.Attributes.set.go(entries, key, value)) == Api.Attributes.keys.go(entries) : List<&2, String>}

def present_keys(entries, key, value, present):
  %present : {Api.Attributes.keys.go(Api.Attributes.set.go(entries, key, value)) ==
    keys_with(Api.Attributes.keys.go(entries), key, _) : List<&2, String>}
  set_keys(entries, key, value)

# Setting a key the list lacks appends the key after the others.
law absent_keys:
  for +entries: List<&2, Api.Attribute>
  for +key: String
  for +value: Api.AttributeValue
  for absent: {Api.Attributes.has.go(entries, key) == False{} : Bool}
  {Api.Attributes.keys.go(Api.Attributes.set.go(entries, key, value)) ==
    List.append(&2, String, Api.Attributes.keys.go(entries), [key]) : List<&2, String>}

def absent_keys(entries, key, value, absent):
  %absent : {Api.Attributes.keys.go(Api.Attributes.set.go(entries, key, value)) ==
    keys_with(Api.Attributes.keys.go(entries), key, _) : List<&2, String>}
  set_keys(entries, key, value)

# A new key is appended
# ---------------------

# The step of absent_append: the first entry cannot be the key (`absent`
# refutes `same` True), so it stays in front of the tail with the key
# appended.
law absent_append_step:
  for +head: Api.Attribute
  for +tail: List<&2, Api.Attribute>
  for +key: String
  for +value: Api.AttributeValue
  for same: Bool
  for absent: {Bool.or(same, Api.Attributes.has.go(tail, key)) == False{} : Bool}
  for rest: {Api.Attributes.set.go(tail, key, value) ==
    List.append(&2, Api.Attribute, tail, [Api.Attribute{key, value}]) : List<&2, Api.Attribute>}
  {Api.Attributes.set.step(head, tail, Api.Attributes.set.go(tail, key, value), value, same) ==
    Con{head, List.append(&2, Api.Attribute, tail, [Api.Attribute{key, value}])} : List<&2, Api.Attribute>}

def absent_append_step(head, tail, key, value, same, absent, rest):
  match same:
    case True{}:
      Empty.absurd({Con{Api.Attribute{Api.Attribute.key(head), value}, tail} ==
        Con{head, List.append(&2, Api.Attribute, tail, [Api.Attribute{key, value}])} : List<&2, Api.Attribute>},
        BoolsProof.true_ne_false(absent))
    case False{}:
      %Equal.sym(List<&2, Api.Attribute>, Api.Attributes.set.go(tail, key, value),
        List.append(&2, Api.Attribute, tail, [Api.Attribute{key, value}]), rest) :
        {Con{head, _} == Con{head, List.append(&2, Api.Attribute, tail, [Api.Attribute{key, value}])} : List<&2, Api.Attribute>}
      {==}

# Setting a key the list lacks appends the attribute after the others and
# changes nothing else. Induction on the list; the tail lacks the key too
# (BoolsProof.or_right_false).
law absent_append:
  for entries: List<&2, Api.Attribute>
  for +key: String
  for +value: Api.AttributeValue
  for +absent: {Api.Attributes.has.go(entries, key) == False{} : Bool}
  {Api.Attributes.set.go(entries, key, value) ==
    List.append(&2, Api.Attribute, entries, [Api.Attribute{key, value}]) : List<&2, Api.Attribute>}

def absent_append(entries, key, value, absent):
  match entries:
    case Nil{}:
      {==}
    case Con{+head, +tail}:
      absent_append_step(head, tail, key, value, String.eq(Api.Attribute.key(head), key), absent,
        absent_append(tail, key, value,
          BoolsProof.or_right_false(String.eq(Api.Attribute.key(head), key), Api.Attributes.has.go(tail, key), absent)))

# Distinct keys
# -------------

# Searching a key among keys with one appended: found among the first keys,
# or equal to the appended one. Induction on the keys, regrouping the chain
# of Bool.or.
law among_append:
  for +probe: String
  for keys: List<&2, String>
  for +key: String
  {Laws.key_among(probe, List.append(&2, String, keys, [key])) ==
    Bool.or(Laws.key_among(probe, keys), String.eq(probe, key)) : Bool}

def among_append(probe, keys, key):
  match keys:
    case Nil{}:
      BoolsProof.or_false(String.eq(probe, key))
    case Con{other, rest}:
      %Equal.sym(Bool, Laws.key_among(probe, List.append(&2, String, rest, [key])),
        Bool.or(Laws.key_among(probe, rest), String.eq(probe, key)), among_append(probe, rest, key)) :
        {Bool.or(String.eq(probe, other), _) ==
          Bool.or(Bool.or(String.eq(probe, other), Laws.key_among(probe, rest)), String.eq(probe, key)) : Bool}
      BoolsProof.or_assoc(String.eq(probe, other), Laws.key_among(probe, rest), String.eq(probe, key))

# The step of distinct_set, for a list whose first entry is not the key: the
# first key is not among the tail's keys with the key appended, because it
# is not among the tail's keys (`apart`) and differs from the key (`seen`);
# and the tail's keys with the key appended are distinct (`rest`).
law distinct_step:
  for +head: Api.Attribute
  for +tail: List<&2, Api.Attribute>
  for +key: String
  for +value: Api.AttributeValue
  for same: Bool
  for seen: {String.eq(Api.Attribute.key(head), key) == same : Bool}
  for absent: {Bool.or(same, Api.Attributes.has.go(tail, key)) == False{} : Bool}
  for apart: {Laws.key_among(Api.Attribute.key(head), Api.Attributes.keys.go(tail)) == False{} : Bool}
  for rest: {Laws.keys_distinct(Api.Attributes.keys.go(Api.Attributes.set.go(tail, key, value))) == True{} : Bool}
  {Laws.keys_distinct(Api.Attributes.keys.go(Api.Attributes.set.step(head, tail, Api.Attributes.set.go(tail, key, value), value, same))) ==
    True{} : Bool}

def distinct_step(head, tail, key, value, same, seen, absent, apart, rest):
  match same:
    case True{}:
      Empty.absurd({Laws.keys_distinct(Api.Attributes.keys.go(Con{Api.Attribute{Api.Attribute.key(head), value}, tail})) == True{} : Bool},
        BoolsProof.true_ne_false(absent))
    case False{}:
      %Equal.sym(Bool, Laws.keys_distinct(Api.Attributes.keys.go(Api.Attributes.set.go(tail, key, value))), True{}, rest) :
        {Bool.and(Bool.not(Laws.key_among(Api.Attribute.key(head), Api.Attributes.keys.go(Api.Attributes.set.go(tail, key, value)))), _) ==
          True{} : Bool}
      %Equal.sym(List<&2, String>, Api.Attributes.keys.go(Api.Attributes.set.go(tail, key, value)),
        List.append(&2, String, Api.Attributes.keys.go(tail), [key]), absent_keys(tail, key, value, absent)) :
        {Bool.and(Bool.not(Laws.key_among(Api.Attribute.key(head), _)), True{}) == True{} : Bool}
      %Equal.sym(Bool, Laws.key_among(Api.Attribute.key(head), List.append(&2, String, Api.Attributes.keys.go(tail), [key])),
        Bool.or(Laws.key_among(Api.Attribute.key(head), Api.Attributes.keys.go(tail)), String.eq(Api.Attribute.key(head), key)),
        among_append(Api.Attribute.key(head), Api.Attributes.keys.go(tail), key)) :
        {Bool.and(Bool.not(_), True{}) == True{} : Bool}
      %Equal.sym(Bool, String.eq(Api.Attribute.key(head), key), False{}, seen) :
        {Bool.and(Bool.not(Bool.or(Laws.key_among(Api.Attribute.key(head), Api.Attributes.keys.go(tail)), _)), True{}) == True{} : Bool}
      %Equal.sym(Bool, Bool.or(Laws.key_among(Api.Attribute.key(head), Api.Attributes.keys.go(tail)), False{}),
        Laws.key_among(Api.Attribute.key(head), Api.Attributes.keys.go(tail)),
        BoolsProof.or_false(Laws.key_among(Api.Attribute.key(head), Api.Attributes.keys.go(tail)))) :
        {Bool.and(Bool.not(_), True{}) == True{} : Bool}
      %Equal.sym(Bool, Laws.key_among(Api.Attribute.key(head), Api.Attributes.keys.go(tail)), False{}, apart) :
        {Bool.and(Bool.not(_), True{}) == True{} : Bool}
      {==}

# Setting a key the list lacks keeps the keys distinct. Induction on the
# list: the tail lacks the key (BoolsProof.or_right_false), its keys are
# distinct and the first key is not among them (the two halves of
# keys_distinct, through and_left, not_true and and_right).
law distinct_set:
  for entries: List<&2, Api.Attribute>
  for +key: String
  for +value: Api.AttributeValue
  for +absent: {Api.Attributes.has.go(entries, key) == False{} : Bool}
  for +distinct: {Laws.keys_distinct(Api.Attributes.keys.go(entries)) == True{} : Bool}
  {Laws.keys_distinct(Api.Attributes.keys.go(Api.Attributes.set.go(entries, key, value))) == True{} : Bool}

def distinct_set(entries, key, value, absent, distinct):
  match entries:
    case Nil{}:
      {==}
    case Con{+head, +tail}:
      distinct_step(head, tail, key, value, String.eq(Api.Attribute.key(head), key), {==}, absent,
        BoolsProof.not_true(Laws.key_among(Api.Attribute.key(head), Api.Attributes.keys.go(tail)),
          BoolsProof.and_left(Bool.not(Laws.key_among(Api.Attribute.key(head), Api.Attributes.keys.go(tail))),
            Laws.keys_distinct(Api.Attributes.keys.go(tail)), distinct)),
        distinct_set(tail, key, value,
          BoolsProof.or_right_false(String.eq(Api.Attribute.key(head), key), Api.Attributes.has.go(tail, key), absent),
          BoolsProof.and_right(Bool.not(Laws.key_among(Api.Attribute.key(head), Api.Attributes.keys.go(tail))),
            Laws.keys_distinct(Api.Attributes.keys.go(tail)), distinct)))

# Setting any key keeps the keys distinct: for a key the list has, the keys
# do not change (present_keys); for a new key, distinct_set. Stated for any
# Bool `found` given with the equation `seen` so that the proof can match on
# it; PROOF.bend passes the lookup itself.
law unique_step:
  for +entries: List<&2, Api.Attribute>
  for +key: String
  for +value: Api.AttributeValue
  for found: Bool
  for seen: {Api.Attributes.has.go(entries, key) == found : Bool}
  for +distinct: {Laws.keys_distinct(Api.Attributes.keys.go(entries)) == True{} : Bool}
  {Laws.keys_distinct(Api.Attributes.keys.go(Api.Attributes.set.go(entries, key, value))) == True{} : Bool}

def unique_step(entries, key, value, found, seen, distinct):
  match found:
    case True{}:
      %Equal.sym(List<&2, String>, Api.Attributes.keys.go(Api.Attributes.set.go(entries, key, value)),
        Api.Attributes.keys.go(entries), present_keys(entries, key, value, seen)) :
        {Laws.keys_distinct(_) == True{} : Bool}
      distinct
    case False{}:
      distinct_set(entries, key, value, seen, distinct)
