# Proofs: events and links under span limits
# ==========================================
#
# SpanData.add_event and SpanData.add_link decide on a computed Bool,
# whether the count leaves room (Span.room), and `match` cannot inspect a
# computed value. So each lemma here takes the decision as a Bool `kept`
# with the equation that says what it is, matches on it, and PROOF.bend
# passes the check itself: room_limited and room_unlimited turn the laws'
# hypotheses on the span's limits into that equation. kept_added,
# kept_dropped and kept_bounded prove the laws event_added, event_dropped,
# event_unlimited, events_bounded and their link counterparts, with the
# length lemmas of proofs/nats.bend.

import Base
import ../api.bend as Api
import ./bools.bend as BoolsProof
import ./nats.bend as NatsProof

# Under a count known to be Some{limit}, the room check is the comparison of
# the length with the limit.
law room_limited:
  for count: Maybe<&2, Nat>
  for +limit: Nat
  for +length: Nat
  for limited: {count == Some{limit} : Maybe<&2, Nat>}
  {Api.Span.room(count, length) == Nat.is_lt(length, limit) : Bool}

def room_limited(count, limit, length, limited):
  %Equal.sym(Maybe<&2, Nat>, count, Some{limit}, limited) :
    {Api.Span.room(_, length) == Nat.is_lt(length, limit) : Bool}
  {==}

# Under a count known to be absent, there is always room.
law room_unlimited:
  for count: Maybe<&2, Nat>
  for length: Nat
  for unlimited: {count == None{} : Maybe<&2, Nat>}
  {Api.Span.room(count, length) == True{} : Bool}

def room_unlimited(count, length, unlimited):
  %Equal.sym(Maybe<&2, Nat>, count, None{}, unlimited) :
    {Api.Span.room(_, length) == True{} : Bool}
  {==}

# When the item is kept, it is appended and the dropped count stays.
law kept_added:
  for -A: Data
  for +items: List<&2, A>
  for +item: A
  for +dropped: Nat
  for kept: Bool
  for seen: {kept == True{} : Bool}
  {Api.Span.kept(A, items, item, kept) == List.append(&2, A, items, [item]) : List<&2, A>} &
  {Api.Span.counted(dropped, kept) == dropped : Nat}

def kept_added(A, items, item, dropped, kept, seen):
  match kept:
    case True{}:
      ({==}, {==})
    case False{}:
      BoolsProof.absurd({Api.Span.kept(A, items, item, False{}) == List.append(&2, A, items, [item]) : List<&2, A>} &
        {Api.Span.counted(dropped, False{}) == dropped : Nat}, seen)

# When the item is dropped, the items stay and the dropped count grows by
# one.
law kept_dropped:
  for -A: Data
  for +items: List<&2, A>
  for item: A
  for +dropped: Nat
  for kept: Bool
  for seen: {kept == False{} : Bool}
  {Api.Span.kept(A, items, item, kept) == items : List<&2, A>} &
  {Api.Span.counted(dropped, kept) == 1n+dropped : Nat}

def kept_dropped(A, items, item, dropped, kept, seen):
  match kept:
    case True{}:
      Empty.absurd({Api.Span.kept(A, items, item, True{}) == items : List<&2, A>} &
        {Api.Span.counted(dropped, True{}) == 1n+dropped : Nat}, BoolsProof.true_ne_false(seen))
    case False{}:
      ({==}, {==})

# Appending an item while the length is below the limit keeps the length at
# most the limit: one more item is still at most the limit
# (NatsProof.append_one_length, le_succ); dropping it keeps the length.
law kept_bounded:
  for -A: Data
  for +limit: Nat
  for +items: List<&2, A>
  for item: A
  for kept: Bool
  for seen: {Nat.is_lt(List.length(&2, A, items), limit) == kept : Bool}
  for bound: {Nat.is_le(List.length(&2, A, items), limit) == True{} : Bool}
  {Nat.is_le(List.length(&2, A, Api.Span.kept(A, items, item, kept)), limit) == True{} : Bool}

def kept_bounded(A, limit, items, item, kept, seen, bound):
  match kept:
    case True{}:
      %Equal.sym(Nat, List.length(&2, A, List.append(&2, A, items, [item])), 1n+List.length(&2, A, items),
        NatsProof.append_one_length(A, items, item)) :
        {Nat.is_le(_, limit) == True{} : Bool}
      %Equal.sym(Bool, Nat.is_le(1n+List.length(&2, A, items), limit), Nat.is_lt(List.length(&2, A, items), limit),
        NatsProof.le_succ(List.length(&2, A, items), limit)) :
        {_ == True{} : Bool}
      seen
    case False{}:
      bound
