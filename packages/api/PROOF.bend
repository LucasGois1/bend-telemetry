import Base
import ./LAWS.bend as Laws
import ./api.bend as Api
import ./proofs/bools.bend as BoolsProof
import ./proofs/strings.bend as StringsProof
import ./proofs/nats.bend as NatsProof
import ./proofs/values.bend as ValuesProof
import ./proofs/attributes.bend as AttributesProof
import ./proofs/limits.bend as LimitsProof
import ./proofs/timestamps.bend as TimestampsProof

# Proofs of the laws of bend-telemetry-api
# ========================================
#
# Each `def Laws.<name>(...)` below proves `law <name>` of LAWS.bend. Its
# parameters are the law's `for` lines, in order, and its body is a term
# whose type is the law's conclusion. In Bend a proposition is a type and a
# proof is an ordinary definition of that type: there are no tactics, and
# the checker verifies every step. The checker accepts this file only when
# every law of LAWS.bend has a proof, so
#
#   ./bend packages/api/PROOF.bend --check-only
#
# is the proof gate of the package: it prints "ALL PROOFS CHECK", which Bend
# prints only when no definition this file imports relies on `@unsafe`,
# which would skip the termination check and void the proofs, or on foreign
# code. scripts/validate.sh runs it.
#
# The notation:
#
#   {==}              reflexivity: both sides compute to the same term. A law
#                     about literal values is proved this way: the checker
#                     computes both sides.
#   (p, q)            a proof of P & Q from proofs of P and of Q.
#   %e : P            rewrite with an equation e : {a == b : T}. P is the
#                     current goal with `_` where b appears, and the goal
#                     becomes P with a in that place. Equal.sym(T, a, b, e)
#                     turns an equation around.
#   match x: case     case analysis: each case refines the goal for that
#                     constructor. The laws quantify over collections, and
#                     the proofs open them to reach the list inside.
#
# Proof modules:
#
#   proofs/bools.bend        general lemmas on Bool
#   proofs/strings.bend      words and strings compare equal with themselves
#   proofs/nats.bend         Nat comparisons and lengths
#   proofs/values.bend       bytes and truncation
#   proofs/attributes.bend   the attribute collection
#   proofs/limits.bend       attributes under span limits
#   proofs/timestamps.bend   timestamps

# 1. Package
# ==========

def Laws.name():
  {==}

def Laws.context_fields():
  {==}

# 2. 64-bit integers
# ==================

# The readers open the record the constructor built.
def Laws.int64_limbs(high, low):
  ({==}, {==})

# The high limb is the literal 0, whose bit 31 is clear.
def Laws.int64_u32(word):
  ({==}, ({==}, {==}))

# By computation, in unary for the Nat and bit by bit for the limbs.
def Laws.int64_nat():
  ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))

def Laws.int64_negated():
  ({==}, ({==}, ({==}, ({==}, {==}))))

# By computation: twenty divisions by ten of the limbs, in 16-bit pieces.
def Laws.int64_show():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==}))))))

def Laws.int64_read():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==}))))))

def Laws.int64_read_refuses():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))))

def Laws.int64_text_roundtrip():
  ({==}, ({==}, ({==}, {==})))

# 3. Doubles
# ==========

def Laws.double_f32(value):
  {==}

def Laws.double_text(value, text):
  ({==}, {==})

# 4. Attribute values
# ===================

def Laws.standard_arrays():
  ({==}, ({==}, ({==}, ({==}, {==}))))

# The laws' check and the package's agree, and the constructor computes
# once its check is rewritten (proofs/values.bend).
def Laws.bytes_accepted(cells, fit):
  ValuesProof.accepted(cells, fit)

def Laws.bytes_refused(cells, over):
  ValuesProof.refused(cells, over)

def Laws.bytes_literal():
  ({==}, ({==}, ({==}, {==})))

# 5. Attributes
# =============

def Laws.empty_attributes(key):
  ({==}, ({==}, ({==}, {==})))

# Each law opens the collection and applies the lemma on its list
# (proofs/attributes.bend).
def Laws.set_get(attributes, key, value):
  match attributes:
    case Api.Attributes{entries, dropped}:
      AttributesProof.set_get(entries, key, value)

def Laws.replace_keeps_count(attributes, key, value, present):
  match attributes:
    case Api.Attributes{+entries, dropped}:
      AttributesProof.present_length(entries, key, value, present)

def Laws.replace_keeps_position(attributes, key, value, present):
  match attributes:
    case Api.Attributes{+entries, dropped}:
      AttributesProof.present_keys(entries, key, value, present)

def Laws.new_key_last(attributes, key, value, absent):
  match attributes:
    case Api.Attributes{+entries, dropped}:
      AttributesProof.absent_append(entries, key, value, absent)

# The lookup is passed as the Bool the step lemma matches on.
def Laws.keys_unique(attributes, key, value, distinct):
  match attributes:
    case Api.Attributes{+entries, dropped}:
      AttributesProof.unique_step(entries, key, value, Api.Attributes.has.go(entries, key), {==}, distinct)

def Laws.set_keeps_dropped(attributes, key, value):
  match attributes:
    case Api.Attributes{entries, dropped}:
      {==}

def Laws.set_all_fold(attributes, key, value, rest):
  ({==}, {==})

# 6. Span limits
# ==============

def Laws.default_limits():
  ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))

def Laws.unlimited_limits():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==}))))))

def Laws.derived_limits(limits):
  match limits:
    case Api.SpanLimits{attribute_count, attribute_value_length, event_count, link_count, attribute_per_event_count, attribute_per_link_count}:
      ({==}, ({==}, {==}))

# The lookup is rewritten to True{}: set_within.present then computes the
# plain set.
def Laws.within_replaces(limits, attributes, key, value, present):
  match limits attributes:
    case Api.AttributeLimits{count, length} Api.Attributes{+entries, dropped}:
      %Equal.sym(Bool, Api.Attributes.has.go(entries, key), True{}, present) :
        {Api.Attributes.set_within.present(count, entries, dropped, key, Api.AttributeValue.truncate(length, value), _) ==
          Api.Attributes{Api.Attributes.set.go(entries, key, Api.AttributeValue.truncate(length, value)), dropped} : Api.Attributes}
      {==}

def Laws.within_unlimited_count(length, attributes, key, value):
  match attributes:
    case Api.Attributes{+entries, dropped}:
      LimitsProof.unlimited_step(entries, dropped, key, Api.AttributeValue.truncate(length, value), Api.Attributes.has.go(entries, key))

# The lookup is rewritten to False{} and the room check to True{}: the key
# is appended.
def Laws.within_adds(limit, length, attributes, key, value, absent, room):
  match attributes:
    case Api.Attributes{+entries, dropped}:
      %Equal.sym(Bool, Api.Attributes.has.go(entries, key), False{}, absent) :
        {Api.Attributes.set_within.present(Some{limit}, entries, dropped, key, Api.AttributeValue.truncate(length, value), _) ==
          Api.Attributes{Api.Attributes.set.go(entries, key, Api.AttributeValue.truncate(length, value)), dropped} : Api.Attributes}
      %Equal.sym(Bool, Nat.is_lt(List.length(&2, Api.Attribute, entries), limit), True{}, room) :
        {Api.Attributes.set_within.fits(entries, dropped, key, Api.AttributeValue.truncate(length, value), _) ==
          Api.Attributes{Api.Attributes.set.go(entries, key, Api.AttributeValue.truncate(length, value)), dropped} : Api.Attributes}
      {==}

# The lookup is rewritten to False{} and the room check to False{}: the
# entries stay and the dropped count grows by one.
def Laws.within_drops(limit, length, attributes, key, value, absent, full):
  match attributes:
    case Api.Attributes{+entries, +dropped}:
      %Equal.sym(Bool, Api.Attributes.has.go(entries, key), False{}, absent) :
        {Api.Attributes.to_list(Api.Attributes.set_within.present(Some{limit}, entries, dropped, key, Api.AttributeValue.truncate(length, value), _)) ==
          entries : List<&2, Api.Attribute>} &
        {Api.Attributes.dropped(Api.Attributes.set_within.present(Some{limit}, entries, dropped, key, Api.AttributeValue.truncate(length, value), _)) ==
          1n+dropped : Nat}
      %Equal.sym(Bool, Nat.is_lt(List.length(&2, Api.Attribute, entries), limit), False{}, full) :
        {Api.Attributes.to_list(Api.Attributes.set_within.fits(entries, dropped, key, Api.AttributeValue.truncate(length, value), _)) ==
          entries : List<&2, Api.Attribute>} &
        {Api.Attributes.dropped(Api.Attributes.set_within.fits(entries, dropped, key, Api.AttributeValue.truncate(length, value), _)) ==
          1n+dropped : Nat}
      ({==}, {==})

def Laws.within_bounded(limit, length, attributes, key, value, bound):
  match attributes:
    case Api.Attributes{+entries, dropped}:
      LimitsProof.bounded_present(limit, entries, dropped, key, Api.AttributeValue.truncate(length, value),
        Api.Attributes.has.go(entries, key), {==}, bound)

def Laws.within_literal():
  ({==}, {==})

def Laws.set_all_within_fold(limits, attributes, key, value, rest):
  ({==}, {==})

def Laws.truncate_none(value):
  {==}

def Laws.truncate_string(limit, text, longer):
  (ValuesProof.cut_value(limit, text, longer), ValuesProof.cut_length(limit, text, longer))

def Laws.truncate_keeps_short(limit, text, fits):
  ValuesProof.kept_value(limit, text, fits)

def Laws.truncate_literal():
  ({==}, ({==}, ({==}, {==})))

# 7. Timestamps
# =============

def Laws.timestamp_readers(seconds, nanoseconds, below):
  (TimestampsProof.seconds_kept(seconds, nanoseconds, below), TimestampsProof.nanoseconds_kept(seconds, nanoseconds, below))

# Both sides unfold to the same normalization of the split.
def Laws.timestamp_milliseconds(milliseconds):
  {==}

# By computation: the nanoseconds divide bit by bit.
def Laws.timestamp_normalized():
  ({==}, ({==}, ({==}, ({==}, {==}))))

def Laws.timestamp_milliseconds_literal():
  ({==}, ({==}, ({==}, {==})))

def Laws.timestamp_self(timestamp):
  (TimestampsProof.cmp_self(timestamp), TimestampsProof.is_eq_self(timestamp))

def Laws.timestamp_order():
  ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))

# 8. Span context
# ===============

# By computation: each reader matches the constructor it is applied to.
def Laws.span_context_remote(incoming):
  ({==}, ({==}, {==}))

def Laws.span_context_local(outgoing):
  ({==}, ({==}, {==}))

def Laws.remote_readers(incoming):
  ({==}, ({==}, ({==}, {==})))

def Laws.local_readers(outgoing):
  ({==}, ({==}, ({==}, {==})))

# By computation: each hexadecimal reader is defined as the digits of the
# value reader.
def Laws.hex_readers(context):
  ({==}, {==})

# 9. Context
# ==========

# Opening the record shows that setting replaces its span context, whatever
# it was.
def Laws.context_set_then_read(context, span_context):
  match context:
    case Api.Context{previous}:
      {==}

def Laws.context_empty():
  {==}

# Opening the record shows that clearing removes its span context, whatever
# it was.
def Laws.context_cleared(context):
  match context:
    case Api.Context{previous}:
      {==}
