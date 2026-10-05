import Base
import ./LAWS.bend as Laws
import ./api.bend as Api
import bend-trace-context@0.2.0.0/trace_context.bend as TC
import ./proofs/bools.bend as BoolsProof
import ./proofs/strings.bend as StringsProof
import ./proofs/nats.bend as NatsProof
import ./proofs/values.bend as ValuesProof
import ./proofs/attributes.bend as AttributesProof
import ./proofs/limits.bend as LimitsProof
import ./proofs/timestamps.bend as TimestampsProof
import ./proofs/spans.bend as SpansProof

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
#   proofs/spans.bend        events and links under span limits

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

# By computation: each variant reads the flags of the context it wraps.
def Laws.wrapped_flags(incoming, outgoing):
  ({==}, {==})

# By computation in each of the four combinations of sampled and random,
# once the outgoing context, its local context and its trace ID are opened:
# the flags compute to the literal number, and the second equation reads
# the flag byte of the emitted traceparent back to the same two Booleans.
def Laws.local_flags(outgoing):
  match outgoing:
    case TC.OutgoingContext{TC.LocalContext{TC.TraceId{trace_id, False{}}, TC.SpanId{span_id}, False{}}, state}:
      ({==}, {==})
    case TC.OutgoingContext{TC.LocalContext{TC.TraceId{trace_id, False{}}, TC.SpanId{span_id}, True{}}, state}:
      ({==}, {==})
    case TC.OutgoingContext{TC.LocalContext{TC.TraceId{trace_id, True{}}, TC.SpanId{span_id}, False{}}, state}:
      ({==}, {==})
    case TC.OutgoingContext{TC.LocalContext{TC.TraceId{trace_id, True{}}, TC.SpanId{span_id}, True{}}, state}:
      ({==}, {==})

# By computation in each of the four combinations, once the incoming
# context, its remote context and its trace ID are opened.
def Laws.remote_flags(incoming):
  match incoming:
    case TC.IncomingContext{TC.RemoteContext{TC.TraceId{trace_id, False{}}, span_id, False{}}, state, received}:
      {==}
    case TC.IncomingContext{TC.RemoteContext{TC.TraceId{trace_id, False{}}, span_id, True{}}, state, received}:
      {==}
    case TC.IncomingContext{TC.RemoteContext{TC.TraceId{trace_id, True{}}, span_id, False{}}, state, received}:
      {==}
    case TC.IncomingContext{TC.RemoteContext{TC.TraceId{trace_id, True{}}, span_id, True{}}, state, received}:
      {==}

# By computation in each variant and each of the four combinations: the
# flags compute to 0, 1, 2 or 3, and the comparison with 3 to True{}.
def Laws.flags_bounded(context):
  match context:
    case Api.RemoteSpanContext{TC.IncomingContext{TC.RemoteContext{TC.TraceId{trace_id, False{}}, span_id, False{}},
      state, received}}:
      {==}
    case Api.RemoteSpanContext{TC.IncomingContext{TC.RemoteContext{TC.TraceId{trace_id, False{}}, span_id, True{}},
      state, received}}:
      {==}
    case Api.RemoteSpanContext{TC.IncomingContext{TC.RemoteContext{TC.TraceId{trace_id, True{}}, span_id, False{}},
      state, received}}:
      {==}
    case Api.RemoteSpanContext{TC.IncomingContext{TC.RemoteContext{TC.TraceId{trace_id, True{}}, span_id, True{}},
      state, received}}:
      {==}
    case Api.LocalSpanContext{TC.OutgoingContext{TC.LocalContext{TC.TraceId{trace_id, False{}}, span_id, False{}}, state}}:
      {==}
    case Api.LocalSpanContext{TC.OutgoingContext{TC.LocalContext{TC.TraceId{trace_id, False{}}, span_id, True{}}, state}}:
      {==}
    case Api.LocalSpanContext{TC.OutgoingContext{TC.LocalContext{TC.TraceId{trace_id, True{}}, span_id, False{}}, state}}:
      {==}
    case Api.LocalSpanContext{TC.OutgoingContext{TC.LocalContext{TC.TraceId{trace_id, True{}}, span_id, True{}}, state}}:
      {==}

# By computation: each reader matches the constructors the parts were put
# in, and the wrapped incoming context is the one the constructor built.
def Laws.parts_readers(trace_id, span_id, sampled, state):
  ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))

# By computation in each of the four combinations, once the trace ID is
# opened for its randomness assertion.
def Laws.parts_flags(trace_id, span_id, sampled, state):
  match trace_id sampled:
    case TC.TraceId{digits, False{}} False{}:
      {==}
    case TC.TraceId{digits, False{}} True{}:
      {==}
    case TC.TraceId{digits, True{}} False{}:
      {==}
    case TC.TraceId{digits, True{}} True{}:
      {==}

# By computation: the incoming context built from parts keeps no received
# pair, which is what forwarding looks for first.
def Laws.parts_not_forwarded(trace_id, span_id, sampled, state, limits, carrier):
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

# 10. Instrumentation scope
# =========================

# By computation: each reader opens the record the constructor built.
def Laws.scope_readers(name, version, schema_url, attributes):
  ({==}, ({==}, ({==}, {==})))

# 11. Span options
# ================

def Laws.default_options():
  ({==}, ({==}, ({==}, ({==}, {==}))))

# Opening the record shows that each with_ operation replaces its field,
# whatever it was.
def Laws.options_set_then_read(options, kind, attributes, links, timestamp, root):
  match options:
    case Api.SpanOptions{previous_kind, previous_attributes, previous_links, previous_timestamp, previous_root}:
      ({==}, ({==}, ({==}, ({==}, {==}))))

# 12. Status
# ==========

def Laws.status_description(description):
  ({==}, ({==}, {==}))

def Laws.status_after(status, description):
  ({==}, ({==}, {==}))

def Laws.status_set(data, status):
  match data:
    case Api.SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, current, limits}:
      {==}

# A non-recording span is unchanged by both sets. For a recording span the
# data is opened and its status examined: whatever it was, the first set
# leaves ok, and the second set over ok leaves ok.
def Laws.ok_final(P, span, status):
  match span:
    case Api.Recording{payload, Api.SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, current, limits}}:
      match current:
        case Api.Unset{}:
          {==}
        case Api.Ok{}:
          {==}
        case Api.Error{description}:
          {==}
    case Api.NonRecording{span_context}:
      {==}

# 13. Events and links
# ====================

def Laws.event_readers(name, attributes, timestamp, milliseconds):
  ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))

def Laws.link_readers(span_context, attributes):
  ({==}, {==})

# By computation: the two keys are literals, so the lookups compare them
# character by character.
def Laws.exception_event(type_name, message, timestamp):
  ({==}, ({==}, ({==}, {==})))

def Laws.exception_with_event(type_name, message, extras, timestamp):
  ({==}, {==})

def Laws.attributes_within(limits, attributes):
  match attributes:
    case Api.Attributes{entries, dropped}:
      {==}

def Laws.within_event_and_link(limits, name, attributes, time, span_context):
  ({==}, {==})

def Laws.event_limits_literal():
  ({==}, ({==}, ({==}, {==})))

# 14. Spans
# =========

# By computation: each reader opens the record SpanData.new built.
def Laws.new_data_readers(scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, limits):
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==}))))))))))))))

def Laws.recording_readers(P, payload, scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, limits):
  ({==}, ({==}, ({==}, {==})))

def Laws.non_recording_readers(P, span_context):
  ({==}, ({==}, ({==}, {==})))

# By computation: each operation matches the constructor it is applied to.
def Laws.recording_delegates(P, payload, data, key, value, entries, link, links, status, name, event, events):
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))))

def Laws.non_recording_identity(P, span_context, key, value, entries, link, links, status, name, event, events, event_name,
  attributes, timestamp, type_name, message, extras):
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==}))))))))))

# Opening the data shows the attributes set under the span's limits.
def Laws.span_attribute_rules(data, key, value, entries):
  match data:
    case Api.SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, limits}:
      ({==}, {==})

# The data is opened so that the fold of Attributes.set_all_within unfolds
# one step on both sides.
def Laws.set_attributes_fold(P, span, key, value, rest):
  match span:
    case Api.Recording{payload, Api.SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, limits}}:
      ({==}, {==})
    case Api.NonRecording{span_context}:
      ({==}, {==})

def Laws.update_name_replaces(P, payload, data, name):
  match data:
    case Api.SpanData{scope, span_context, parent, previous, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, limits}:
      ({==}, {==})

# The data is opened, and the span's room check is passed to the lemma as
# the Bool it decides on, with its value under the law's hypotheses
# (proofs/spans.bend).
def Laws.event_added(limit, data, event, limited, room):
  match data:
    case Api.SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      +events, +dropped_events, links, dropped_links, status, +limits}:
      SpansProof.kept_added(Api.SpanEvent, events, Api.SpanEvent.within(Api.SpanLimits.event_attributes(limits), event), dropped_events,
        Api.Span.room(Api.SpanLimits.event_count(limits), List.length(&2, Api.SpanEvent, events)),
        Equal.trans(Bool, Api.Span.room(Api.SpanLimits.event_count(limits), List.length(&2, Api.SpanEvent, events)),
          Nat.is_lt(List.length(&2, Api.SpanEvent, events), limit), True{},
          SpansProof.room_limited(Api.SpanLimits.event_count(limits), limit, List.length(&2, Api.SpanEvent, events), limited), room))

def Laws.event_dropped(limit, data, event, limited, full):
  match data:
    case Api.SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      +events, +dropped_events, links, dropped_links, status, +limits}:
      SpansProof.kept_dropped(Api.SpanEvent, events, Api.SpanEvent.within(Api.SpanLimits.event_attributes(limits), event), dropped_events,
        Api.Span.room(Api.SpanLimits.event_count(limits), List.length(&2, Api.SpanEvent, events)),
        Equal.trans(Bool, Api.Span.room(Api.SpanLimits.event_count(limits), List.length(&2, Api.SpanEvent, events)),
          Nat.is_lt(List.length(&2, Api.SpanEvent, events), limit), False{},
          SpansProof.room_limited(Api.SpanLimits.event_count(limits), limit, List.length(&2, Api.SpanEvent, events), limited), full))

def Laws.event_unlimited(data, event, unlimited):
  match data:
    case Api.SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      +events, +dropped_events, links, dropped_links, status, +limits}:
      SpansProof.kept_added(Api.SpanEvent, events, Api.SpanEvent.within(Api.SpanLimits.event_attributes(limits), event), dropped_events,
        Api.Span.room(Api.SpanLimits.event_count(limits), List.length(&2, Api.SpanEvent, events)),
        SpansProof.room_unlimited(Api.SpanLimits.event_count(limits), List.length(&2, Api.SpanEvent, events), unlimited))

def Laws.events_bounded(limit, data, event, limited, bound):
  match data:
    case Api.SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      +events, dropped_events, links, dropped_links, status, +limits}:
      SpansProof.kept_bounded(Api.SpanEvent, limit, events, Api.SpanEvent.within(Api.SpanLimits.event_attributes(limits), event),
        Api.Span.room(Api.SpanLimits.event_count(limits), List.length(&2, Api.SpanEvent, events)),
        Equal.sym(Bool, Api.Span.room(Api.SpanLimits.event_count(limits), List.length(&2, Api.SpanEvent, events)),
          Nat.is_lt(List.length(&2, Api.SpanEvent, events), limit),
          SpansProof.room_limited(Api.SpanLimits.event_count(limits), limit, List.length(&2, Api.SpanEvent, events), limited)),
        bound)

# By cases on the span: a non-recording span is unchanged on both sides, and
# on a recording span the fold unfolds one step.
def Laws.add_events_fold(P, span, event, rest):
  match span:
    case Api.Recording{payload, data}:
      ({==}, {==})
    case Api.NonRecording{span_context}:
      ({==}, {==})

def Laws.event_shorthands(P, span, name, attributes, timestamp, type_name, message, extras):
  ({==}, ({==}, {==}))

def Laws.link_added(limit, data, link, limited, room):
  match data:
    case Api.SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, +links, +dropped_links, status, +limits}:
      SpansProof.kept_added(Api.Link, links, Api.Link.within(Api.SpanLimits.link_attributes(limits), link), dropped_links,
        Api.Span.room(Api.SpanLimits.link_count(limits), List.length(&2, Api.Link, links)),
        Equal.trans(Bool, Api.Span.room(Api.SpanLimits.link_count(limits), List.length(&2, Api.Link, links)),
          Nat.is_lt(List.length(&2, Api.Link, links), limit), True{},
          SpansProof.room_limited(Api.SpanLimits.link_count(limits), limit, List.length(&2, Api.Link, links), limited), room))

def Laws.link_dropped(limit, data, link, limited, full):
  match data:
    case Api.SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, +links, +dropped_links, status, +limits}:
      SpansProof.kept_dropped(Api.Link, links, Api.Link.within(Api.SpanLimits.link_attributes(limits), link), dropped_links,
        Api.Span.room(Api.SpanLimits.link_count(limits), List.length(&2, Api.Link, links)),
        Equal.trans(Bool, Api.Span.room(Api.SpanLimits.link_count(limits), List.length(&2, Api.Link, links)),
          Nat.is_lt(List.length(&2, Api.Link, links), limit), False{},
          SpansProof.room_limited(Api.SpanLimits.link_count(limits), limit, List.length(&2, Api.Link, links), limited), full))

def Laws.link_unlimited(data, link, unlimited):
  match data:
    case Api.SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, +links, +dropped_links, status, +limits}:
      SpansProof.kept_added(Api.Link, links, Api.Link.within(Api.SpanLimits.link_attributes(limits), link), dropped_links,
        Api.Span.room(Api.SpanLimits.link_count(limits), List.length(&2, Api.Link, links)),
        SpansProof.room_unlimited(Api.SpanLimits.link_count(limits), List.length(&2, Api.Link, links), unlimited))

def Laws.add_links_fold(P, span, link, rest):
  match span:
    case Api.Recording{payload, data}:
      ({==}, {==})
    case Api.NonRecording{span_context}:
      ({==}, {==})

def Laws.links_bounded(limit, data, link, limited, bound):
  match data:
    case Api.SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, +links, dropped_links, status, +limits}:
      SpansProof.kept_bounded(Api.Link, limit, links, Api.Link.within(Api.SpanLimits.link_attributes(limits), link),
        Api.Span.room(Api.SpanLimits.link_count(limits), List.length(&2, Api.Link, links)),
        Equal.sym(Bool, Api.Span.room(Api.SpanLimits.link_count(limits), List.length(&2, Api.Link, links)),
          Nat.is_lt(List.length(&2, Api.Link, links), limit),
          SpansProof.room_limited(Api.SpanLimits.link_count(limits), limit, List.length(&2, Api.Link, links), limited)),
        bound)
