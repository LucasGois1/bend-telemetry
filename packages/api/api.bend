# bend-telemetry-api: the OpenTelemetry tracing API for Bend. Source: https://github.com/LucasGois1/bend-telemetry
import Base
import bend-trace-context@0.2.0.0/trace_context.bend as TC
import ./src/limbs.bend as Limbs

# The tracing API package
# =======================
#
# The OpenTelemetry tracing API for Bend: the package that instrumented code
# depends on. Its contract is the specification in
# https://github.com/LucasGois1/bend-telemetry/issues/2 ("spec #2" below).
# This file is the package's entry module: it holds the public types and
# operations, a section per ticket of the specification. Today those are the
# pure values of the API (#4): attribute values with their 64-bit integers
# and doubles, attributes and the attribute collection, span limits and
# their enforcement, and timestamps; the span context and the explicit
# context (#5); and the span with its two states, recording and
# non-recording, its pure operations, its events, links, status, kinds,
# start options and instrumentation scope (#6). Tracers, span start and end
# and the SDK slots follow in later tickets. The package imports no foreign
# code, so that every library that depends on it stays provable; the claims
# this code must satisfy are stated in LAWS.bend and proved in PROOF.bend,
# beside this file. README.md beside this file is the reference.
#
# W3C Trace Context comes from bend-trace-context, imported by its BendHub
# name and version, never by a relative path (#1). The glossary of the
# repository's CONTEXT.md supplies the terms: attribute, attribute value,
# span limits, timestamp, span context, context, recording span,
# non-recording span, event, link, status, instrumentation scope, span owner.
#
# Three types are opaque: Int64, Double and Timestamp. Their constructors are
# their representation, which later Base releases may change (U64, F64), not
# their contract: callers build them with the constructors below and read
# them with the readers, and nothing else of them is promised.
#
# Contents
#
#   Package                Package.name, TraceContext.fields
#   Types                  every public type, declared first
#   64-bit integers        Int64.*
#   Doubles                Double.*
#   Attribute values       AttributeValue.*
#   Attributes             Attribute.*, Attributes.*
#   Span limits            AttributeLimits.*, SpanLimits.*, Attributes.set_within, Attributes.within
#   Timestamps             Timestamp.*
#   Span context           SpanContext.*
#   Context                Context.*
#   Instrumentation scope  InstrumentationScope.*
#   Span options           SpanOptions.*
#   Status                 Status.*
#   Events and links       SpanEvent.*, Link.*
#   Spans                  SpanData.*, Span.*

# Package
# =======

# The package's BendHub name.
def Package.name() -> String:
  "bend-telemetry-api"

# The names of the context fields that the W3C Trace Context propagator
# writes, in injection order: traceparent, then tracestate.
def TraceContext.fields() -> List<&2, String>:
  TC.Context.field_names()

# Types
# =====

# A 64-bit integer, the integer of an attribute value: two U32 limbs read as
# one two's complement number, bit 31 of the high limb being the sign (local
# ADR 0006, G8). Opaque: build it with Int64.from_u32, from_nat,
# from_negated_nat, from_limbs or read, and read it with Int64.high, low,
# is_negative and show. When Base ships U64, constructors and readers for it
# are added beside these.
type Int64 is Data:
  Int64{high: U32, low: U32}

# A double, the floating-point number of an attribute value, held as an F32
# until Base ships F64: a value that F32 cannot hold exactly loses precision,
# the one hard gap of attribute values (ADR 0006). Opaque: build it with
# Double.from_f32 or read, and read it with to_f32 and show.
type Double is Data:
  Double{value: F32}

# An attribute value: any value that OTLP's AnyValue carries. The standard
# values of the specification are the four primitives and homogeneous arrays
# of them, which backends reliably accept and which AttributeValue.strings,
# bools, ints and doubles build; bytes, arrays of other shapes, key-value
# lists and the empty value complete OTLP's shape, so that an exporter needs
# no second conversion layer. Arrays and key-value lists nest.
type AttributeValue is Data:
  StringValue{value: String}
  BoolValue{value: Bool}
  IntValue{value: Int64}
  DoubleValue{value: Double}
  BytesValue{cells: List<&2, U32>}
  ArrayValue{items: List<&2, AttributeValue>}
  KvlistValue{entries: List<&2, Attribute>}
  EmptyValue{}

# An attribute: a key with a value.
type Attribute is Data:
  Attribute{key: String, value: AttributeValue}

# An attribute collection: attributes in insertion order with unique keys,
# and the count of attributes that span limits dropped. Build it with
# Attributes.empty, set and set_within, or from_list; the constructor is the
# representation.
type Attributes is Data:
  Attributes{entries: List<&2, Attribute>, dropped: Nat}

# The limits one attribute collection enforces: the most attributes it keeps
# and the longest string it keeps whole, each absent when unlimited.
# SpanLimits derives one for a span's attributes, an event's and a link's.
type AttributeLimits is Data:
  AttributeLimits{count: Maybe<&2, Nat>, length: Maybe<&2, Nat>}

# Span limits (spec #2): the most attributes, events and links a span keeps,
# the longest attribute value length, and the most attributes per event and
# per link. A count or length that is absent is unlimited.
type SpanLimits is Data:
  SpanLimits{
    attribute_count: Maybe<&2, Nat>,
    attribute_value_length: Maybe<&2, Nat>,
    event_count: Maybe<&2, Nat>,
    link_count: Maybe<&2, Nat>,
    attribute_per_event_count: Maybe<&2, Nat>,
    attribute_per_link_count: Maybe<&2, Nat>
  }

# A timestamp: an instant as nanoseconds since the Unix epoch, held as whole
# seconds and a nanosecond remainder below one second. Opaque: build it with
# Timestamp.from_unix or from_milliseconds, and read it with seconds,
# nanoseconds and milliseconds; a later move to a 64-bit integer changes no
# caller.
type Timestamp is Data:
  Timestamp{seconds: Nat, nanoseconds: U32}

# The identity of a span: a remote span context, received from another
# participant, or a local span context, an operation of this participant,
# each with its tracestate. The variants wrap bend-trace-context's incoming
# and outgoing contexts; see "Span context" below.
type SpanContext is Data:
  RemoteSpanContext{incoming: TC.IncomingContext}
  LocalSpanContext{outgoing: TC.OutgoingContext}

# The explicit context: the value that code passes to carry the current span
# context across calls and into forked computations. Closed: build it with
# Context.empty and use the operations of "Context" below, never the
# constructor.
type Context is Data:
  Context{span_context: Maybe<&2, SpanContext>}

# The kind of a span: how it relates to its parent and its children in the
# trace. Internal is the default; a server and a client span frame a remote
# request, a producer and a consumer span frame a message.
type SpanKind is Data:
  Internal{}
  Server{}
  Client{}
  Producer{}
  Consumer{}

# The status of a span: unset, ok, or error with a description. The
# description exists only in the error variant, and ok is final; see
# "Status" below.
type Status is Data:
  Unset{}
  Ok{}
  Error{description: String}

# When an event happened: at an explicit timestamp, or at an offset in
# milliseconds from the span's start reading, which the SDK resolves to wall
# time at the end from the start timestamp.
type EventTime is Data:
  AtTimestamp{timestamp: Timestamp}
  AtOffset{milliseconds: Nat}

# An event: a named, timed record with attributes on a span, the attributes
# carrying their own dropped count. Named SpanEvent because Base's Event is
# the window event. Build it with SpanEvent.at, at_offset, exception and
# exception_with; a span re-enforces its limits on it when it adds it.
type SpanEvent is Data:
  SpanEvent{name: String, attributes: Attributes, time: EventTime}

# A link: a reference from a span to another span context, with attributes
# that carry their own dropped count. Build it with Link.to.
type Link is Data:
  Link{span_context: SpanContext, attributes: Attributes}

# The instrumentation scope: the name, optional version, optional schema URL
# and attributes that identify the instrumentation that created a span. The
# constructor builds it, and an empty name is kept as given.
type InstrumentationScope is Data:
  InstrumentationScope{name: String, version: Maybe<&2, String>, schema_url: Maybe<&2, String>, attributes: Attributes}

# The start options of a span: its kind, internal by default, its initial
# attributes and links, an optional start timestamp, and whether it is a
# root, which ignores the parent in the context. Closed: build it with
# SpanOptions.default and the with_ operations of "Span options" below,
# never the constructor.
type SpanOptions is Data:
  SpanOptions{
    kind: SpanKind,
    attributes: List<&2, Attribute>,
    links: List<&2, Link>,
    start_timestamp: Maybe<&2, Timestamp>,
    root: Bool
  }

# The data of a recording span: everything the SDK's end slot receives, that
# is, everything but the payload. The span context is the span's own; the
# parent is the span context it was started from, if any; the start reading
# is the monotonic count of milliseconds taken at start, from which event
# offsets are measured; the dropped counts say how many events and links
# the span limits dropped. Build it with SpanData.new and change it through
# the operations of "Spans" below; an SDK and an exporter read it with the
# readers or by matching the constructor.
type SpanData is Data:
  SpanData{
    scope: InstrumentationScope,
    span_context: SpanContext,
    parent: Maybe<&2, SpanContext>,
    name: String,
    kind: SpanKind,
    start_timestamp: Timestamp,
    start_reading: Nat,
    sampled: Bool,
    attributes: Attributes,
    events: List<&2, SpanEvent>,
    dropped_events: Nat,
    links: List<&2, Link>,
    dropped_links: Nat,
    status: Status,
    limits: SpanLimits
  }

# A span, with the SDK's payload type as its parameter: a recording span
# holds the SDK's payload and its data, a non-recording span holds only an
# optional span context, its parent's, so that propagation continues. It is
# an affine Data value that its owner threads through the code (local ADR
# 0003): the operations of "Spans" below are pure functions from a span to
# a span. Build it with Span.recording and Span.non_recording.
type Span<-P: Data> is Data:
  Recording{payload: P, data: SpanData}
  NonRecording{span_context: Maybe<&2, SpanContext>}

# 64-bit integers
# ===============
#
# The arithmetic on limbs lives in src/limbs.bend; these operations are its
# public face. There is no general arithmetic: an attribute value carries a
# number, it does not compute with it (ADR 0006).

# The value whose two's complement limbs are these, high first: the bridge
# for a caller that holds a 64-bit value in another form.
def Int64.from_limbs(high: U32, low: U32) -> Int64:
  Int64{high, low}

# The non-negative value of a U32.
def Int64.from_u32(value: U32) -> Int64:
  Int64{0, value}

# The value of a pair of limbs, high first, as src/limbs.bend hands it.
def Int64.of_pair(limbs: U32 & U32) -> Int64:
  match limbs:
    case (high, low):
      Int64{high, low}

# The non-negative value of a natural number, which Base keeps below 2^48.
def Int64.from_nat(value: Nat) -> Int64:
  Int64.of_pair(Limbs.Limbs.of_nat(value))

# The negation of a natural number: minus `value`; zero stays zero.
def Int64.from_negated_nat(value: Nat) -> Int64:
  Int64.of_pair(Limbs.Limbs.negate_pair(Limbs.Limbs.of_nat(value)))

# The value a decimal reading gave, when it gave one.
def Int64.read.of(limbs: Maybe<&1, U32 & U32>) -> Maybe<&2, Int64>:
  match limbs:
    case None{}:
      None{}
    case Some{pair}:
      Some{Int64.of_pair(pair)}

# The value of a decimal text: an optional minus sign and at least one digit,
# from -9223372036854775808 to 9223372036854775807, leading zeros accepted as
# Base's U32.read accepts them; None for any other text.
def Int64.read(text: String) -> Maybe<&2, Int64>:
  Int64.read.of(Limbs.Limbs.read(text))

# The high limb: bits 63 to 32 of the two's complement value.
def Int64.high(value: Int64) -> U32:
  match value:
    case Int64{high, low}:
      high

# The low limb: bits 31 to 0.
def Int64.low(value: Int64) -> U32:
  match value:
    case Int64{high, low}:
      low

# Whether the value is below zero: bit 31 of the high limb is set.
def Int64.is_negative(value: Int64) -> Bool:
  Limbs.Limbs.is_negative(Int64.high(value))

# The decimal text of the value: an optional minus sign and digits without
# leading zeros. Int64.read reads it back.
def Int64.show(value: Int64) -> String:
  match value:
    case Int64{high, low}:
      Limbs.Limbs.show(high, low)

# Doubles
# =======

# The double holding an F32.
def Double.from_f32(value: F32) -> Double:
  Double{value}

# The double of a decimal text, as Base's F32.read reads it: None when the
# text is not a number.
def Double.read(text: String) -> Maybe<&2, Double>:
  Maybe.map(&2, F32, Double, Double.from_f32, F32.read(text))

# The F32 the double holds.
def Double.to_f32(double: Double) -> F32:
  match double:
    case Double{value}:
      value

# The shortest decimal text that reads back as the same F32, as Base's
# F32.show writes it.
def Double.show(double: Double) -> String:
  F32.show(Double.to_f32(double))

# Attribute values
# ================
#
# The standard constructors build the homogeneous arrays of the
# specification; the primitives are their constructors, StringValue{text},
# BoolValue{flag}, IntValue{integer} and DoubleValue{double}.

# Each string as a string value.
def AttributeValue.strings.go(values: List<&2, String>) -> List<&2, AttributeValue>:
  match values:
    case Nil{}:
      Nil{}
    case Con{head, tail}:
      Con{StringValue{head}, AttributeValue.strings.go(tail)}

# The array of strings: a standard value.
def AttributeValue.strings(values: List<&2, String>) -> AttributeValue:
  ArrayValue{AttributeValue.strings.go(values)}

# Each Boolean as a Boolean value.
def AttributeValue.bools.go(values: List<&2, Bool>) -> List<&2, AttributeValue>:
  match values:
    case Nil{}:
      Nil{}
    case Con{head, tail}:
      Con{BoolValue{head}, AttributeValue.bools.go(tail)}

# The array of Booleans: a standard value.
def AttributeValue.bools(values: List<&2, Bool>) -> AttributeValue:
  ArrayValue{AttributeValue.bools.go(values)}

# Each integer as an integer value.
def AttributeValue.ints.go(values: List<&2, Int64>) -> List<&2, AttributeValue>:
  match values:
    case Nil{}:
      Nil{}
    case Con{head, tail}:
      Con{IntValue{head}, AttributeValue.ints.go(tail)}

# The array of 64-bit integers: a standard value.
def AttributeValue.ints(values: List<&2, Int64>) -> AttributeValue:
  ArrayValue{AttributeValue.ints.go(values)}

# Each double as a double value.
def AttributeValue.doubles.go(values: List<&2, Double>) -> List<&2, AttributeValue>:
  match values:
    case Nil{}:
      Nil{}
    case Con{head, tail}:
      Con{DoubleValue{head}, AttributeValue.doubles.go(tail)}

# The array of doubles: a standard value.
def AttributeValue.doubles(values: List<&2, Double>) -> AttributeValue:
  ArrayValue{AttributeValue.doubles.go(values)}

# Whether every cell of a list is a byte, from 0 to 255.
def AttributeValue.bytes.fit(cells: List<&2, U32>) -> Bool:
  match cells:
    case Nil{}:
      True{}
    case Con{head, tail}:
      Bool.and(U32.is_le(head, 255), AttributeValue.bytes.fit(tail))

# The bytes value of cells that are all bytes.
def AttributeValue.bytes.checked(cells: List<&2, U32>, fit: Bool) -> Maybe<&2, AttributeValue>:
  match fit:
    case True{}:
      Some{BytesValue{cells}}
    case False{}:
      None{}

# The bytes value of a list of cells from 0 to 255, Base's byte convention,
# as bend-trace-context's byte forms use it; None when a cell is larger.
def AttributeValue.bytes(+cells: List<&2, U32>) -> Maybe<&2, AttributeValue>:
  AttributeValue.bytes.checked(cells, AttributeValue.bytes.fit(cells))

# A text within a length limit: its first `limit` characters when it is
# longer than the limit, itself otherwise.
def AttributeValue.truncate.text(limit: Nat, text: String, longer: Bool) -> String:
  match longer:
    case True{}:
      String.take(text, limit)
    case False{}:
      text

# A text cut to a limit of characters when it is longer.
def AttributeValue.truncate.string(+limit: Nat, +text: String) -> String:
  AttributeValue.truncate.text(limit, text, Nat.is_lt(limit, String.length(text)))

# An item of an array within the limit: a string is cut, any other item is
# kept as it is.
def AttributeValue.truncate.item(limit: Nat, item: AttributeValue) -> AttributeValue:
  match item:
    case StringValue{text}:
      StringValue{AttributeValue.truncate.string(limit, text)}
    case other:
      other

# The items of an array within the limit.
def AttributeValue.truncate.items(+limit: Nat, items: List<&2, AttributeValue>) -> List<&2, AttributeValue>:
  match items:
    case Nil{}:
      Nil{}
    case Con{head, tail}:
      Con{AttributeValue.truncate.item(limit, head), AttributeValue.truncate.items(limit, tail)}

# A value within a length limit: a string longer than the limit is cut to
# the limit's length, and so is each string of an array; every other value
# is kept as it is, since the specification defines the limit for strings
# and the strings of arrays.
def AttributeValue.truncate.go(limit: Nat, value: AttributeValue) -> AttributeValue:
  match value:
    case StringValue{text}:
      StringValue{AttributeValue.truncate.string(limit, text)}
    case ArrayValue{items}:
      ArrayValue{AttributeValue.truncate.items(limit, items)}
    case other:
      other

# The value within an optional length limit: itself when there is no limit.
# Attributes.set_within applies it to every value it stores.
def AttributeValue.truncate(limit: Maybe<&2, Nat>, value: AttributeValue) -> AttributeValue:
  match limit:
    case None{}:
      value
    case Some{length}:
      AttributeValue.truncate.go(length, value)

# Attributes
# ==========
#
# The collection is a list of attributes in insertion order, searched from
# the front. Every lookup compares an entry's key with the key sought, in
# that order. The recursions compute the rest of the list before the
# comparison decides, since a decision helper cannot call back into a
# recursion defined after it.

# The key of an attribute.
def Attribute.key(attribute: Attribute) -> String:
  match attribute:
    case Attribute{key, value}:
      key

# The value of an attribute.
def Attribute.value(attribute: Attribute) -> AttributeValue:
  match attribute:
    case Attribute{key, value}:
      value

# The empty collection: no attributes, nothing dropped.
def Attributes.empty() -> Attributes:
  Attributes{Nil{}, 0n}

# Whether an entry of the list has the key.
def Attributes.has.go(entries: List<&2, Attribute>, +key: String) -> Bool:
  match entries:
    case Nil{}:
      False{}
    case Con{head, tail}:
      Bool.or(String.eq(Attribute.key(head), key), Attributes.has.go(tail, key))

# The value of an entry whose key compared equal, or what the rest gave.
def Attributes.get.step(entry: Attribute, rest: Maybe<&2, AttributeValue>, same: Bool) -> Maybe<&2, AttributeValue>:
  match same:
    case True{}:
      Some{Attribute.value(entry)}
    case False{}:
      rest

# The value of the first entry with the key, if any.
def Attributes.get.go(entries: List<&2, Attribute>, +key: String) -> Maybe<&2, AttributeValue>:
  match entries:
    case Nil{}:
      None{}
    case Con{+head, tail}:
      Attributes.get.step(head, Attributes.get.go(tail, key), String.eq(Attribute.key(head), key))

# The entry whose key compared equal takes the new value and keeps its own
# key and its place; any other entry stays, followed by the rest with the
# key set.
def Attributes.set.step(head: Attribute, tail: List<&2, Attribute>, rest: List<&2, Attribute>,
  value: AttributeValue, same: Bool) -> List<&2, Attribute>:
  match same:
    case True{}:
      Con{Attribute{Attribute.key(head), value}, tail}
    case False{}:
      Con{head, rest}

# The list with the key set to the value: replaced in place when the key is
# there, appended at the end otherwise.
def Attributes.set.go(entries: List<&2, Attribute>, +key: String, +value: AttributeValue) -> List<&2, Attribute>:
  match entries:
    case Nil{}:
      [Attribute{key, value}]
    case Con{+head, +tail}:
      Attributes.set.step(head, tail, Attributes.set.go(tail, key, value), value, String.eq(Attribute.key(head), key))

# The keys of the entries, in order.
def Attributes.keys.go(entries: List<&2, Attribute>) -> List<&2, String>:
  match entries:
    case Nil{}:
      Nil{}
    case Con{head, tail}:
      Con{Attribute.key(head), Attributes.keys.go(tail)}

# Set a key to a value, with no limit: an existing key takes the value in
# place and keeps its position; a new key is appended last.
def Attributes.set(attributes: Attributes, key: String, value: AttributeValue) -> Attributes:
  match attributes:
    case Attributes{entries, dropped}:
      Attributes{Attributes.set.go(entries, key, value), dropped}

# Each attribute set in turn, the list first so that the recursion is on it.
def Attributes.set_all.go(entries: List<&2, Attribute>, attributes: Attributes) -> Attributes:
  match entries:
    case Nil{}:
      attributes
    case Con{Attribute{key, value}, rest}:
      Attributes.set_all.go(rest, Attributes.set(attributes, key, value))

# Set several attributes, in order: a fold of Attributes.set.
def Attributes.set_all(attributes: Attributes, entries: List<&2, Attribute>) -> Attributes:
  Attributes.set_all.go(entries, attributes)

# The collection of a list of attributes set in order: a repeated key keeps
# its first position and its last value.
def Attributes.from_list(entries: List<&2, Attribute>) -> Attributes:
  Attributes.set_all(Attributes.empty(), entries)

# The value of a key, if the collection has it.
def Attributes.get(attributes: Attributes, key: String) -> Maybe<&2, AttributeValue>:
  match attributes:
    case Attributes{entries, dropped}:
      Attributes.get.go(entries, key)

# Whether the collection has a key.
def Attributes.has(attributes: Attributes, key: String) -> Bool:
  match attributes:
    case Attributes{entries, dropped}:
      Attributes.has.go(entries, key)

# How many attributes the collection keeps.
def Attributes.count(attributes: Attributes) -> Nat:
  match attributes:
    case Attributes{entries, dropped}:
      List.length(&2, Attribute, entries)

# The attributes in insertion order.
def Attributes.to_list(attributes: Attributes) -> List<&2, Attribute>:
  match attributes:
    case Attributes{entries, dropped}:
      entries

# The keys in insertion order.
def Attributes.keys(attributes: Attributes) -> List<&2, String>:
  match attributes:
    case Attributes{entries, dropped}:
      Attributes.keys.go(entries)

# How many attributes span limits dropped from the collection.
def Attributes.dropped(attributes: Attributes) -> Nat:
  match attributes:
    case Attributes{entries, dropped}:
      dropped

# Span limits
# ===========
#
# The SDK sets a span's limits when it starts the span, and every operation
# enforces them as it runs (spec #2): Attributes.set_within is the
# enforcement for attributes, which the span, its events and its links share
# through the AttributeLimits that SpanLimits derives for each.

# No limit on the count or the length.
def AttributeLimits.unlimited() -> AttributeLimits:
  AttributeLimits{None{}, None{}}

# The most attributes a collection keeps, if limited.
def AttributeLimits.count(limits: AttributeLimits) -> Maybe<&2, Nat>:
  match limits:
    case AttributeLimits{count, length}:
      count

# The longest string a collection keeps whole, if limited.
def AttributeLimits.length(limits: AttributeLimits) -> Maybe<&2, Nat>:
  match limits:
    case AttributeLimits{count, length}:
      length

# The defaults of the specification: 128 attributes, events and links, 128
# attributes per event and per link, and no length limit.
def SpanLimits.default() -> SpanLimits:
  SpanLimits{Some{128n}, None{}, Some{128n}, Some{128n}, Some{128n}, Some{128n}}

# No limit at all: a span keeps everything.
def SpanLimits.unlimited() -> SpanLimits:
  SpanLimits{None{}, None{}, None{}, None{}, None{}, None{}}

# The most attributes a span keeps.
def SpanLimits.attribute_count(limits: SpanLimits) -> Maybe<&2, Nat>:
  match limits:
    case SpanLimits{attribute_count, attribute_value_length, event_count, link_count, attribute_per_event_count, attribute_per_link_count}:
      attribute_count

# The longest attribute value length: the most characters of a string, or of
# each string of an array, that a span keeps.
def SpanLimits.attribute_value_length(limits: SpanLimits) -> Maybe<&2, Nat>:
  match limits:
    case SpanLimits{attribute_count, attribute_value_length, event_count, link_count, attribute_per_event_count, attribute_per_link_count}:
      attribute_value_length

# The most events a span keeps.
def SpanLimits.event_count(limits: SpanLimits) -> Maybe<&2, Nat>:
  match limits:
    case SpanLimits{attribute_count, attribute_value_length, event_count, link_count, attribute_per_event_count, attribute_per_link_count}:
      event_count

# The most links a span keeps.
def SpanLimits.link_count(limits: SpanLimits) -> Maybe<&2, Nat>:
  match limits:
    case SpanLimits{attribute_count, attribute_value_length, event_count, link_count, attribute_per_event_count, attribute_per_link_count}:
      link_count

# The most attributes an event keeps.
def SpanLimits.attribute_per_event_count(limits: SpanLimits) -> Maybe<&2, Nat>:
  match limits:
    case SpanLimits{attribute_count, attribute_value_length, event_count, link_count, attribute_per_event_count, attribute_per_link_count}:
      attribute_per_event_count

# The most attributes a link keeps.
def SpanLimits.attribute_per_link_count(limits: SpanLimits) -> Maybe<&2, Nat>:
  match limits:
    case SpanLimits{attribute_count, attribute_value_length, event_count, link_count, attribute_per_event_count, attribute_per_link_count}:
      attribute_per_link_count

# The limits of a span's own attributes: the attribute count and the value
# length.
def SpanLimits.span_attributes(limits: SpanLimits) -> AttributeLimits:
  match limits:
    case SpanLimits{attribute_count, attribute_value_length, event_count, link_count, attribute_per_event_count, attribute_per_link_count}:
      AttributeLimits{attribute_count, attribute_value_length}

# The limits of an event's attributes: the count per event and the value
# length.
def SpanLimits.event_attributes(limits: SpanLimits) -> AttributeLimits:
  match limits:
    case SpanLimits{attribute_count, attribute_value_length, event_count, link_count, attribute_per_event_count, attribute_per_link_count}:
      AttributeLimits{attribute_per_event_count, attribute_value_length}

# The limits of a link's attributes: the count per link and the value length.
def SpanLimits.link_attributes(limits: SpanLimits) -> AttributeLimits:
  match limits:
    case SpanLimits{attribute_count, attribute_value_length, event_count, link_count, attribute_per_event_count, attribute_per_link_count}:
      AttributeLimits{attribute_per_link_count, attribute_value_length}

# A new key under a count limit: appended while the count leaves room,
# dropped and counted once it is reached.
def Attributes.set_within.fits(entries: List<&2, Attribute>, dropped: Nat, key: String, value: AttributeValue,
  fits: Bool) -> Attributes:
  match fits:
    case True{}:
      Attributes{Attributes.set.go(entries, key, value), dropped}
    case False{}:
      Attributes{entries, 1n+dropped}

# A new key under an optional count limit: always appended without one.
def Attributes.set_within.room(count: Maybe<&2, Nat>, +entries: List<&2, Attribute>, dropped: Nat, key: String,
  value: AttributeValue) -> Attributes:
  match count:
    case None{}:
      Attributes{Attributes.set.go(entries, key, value), dropped}
    case Some{limit}:
      Attributes.set_within.fits(entries, dropped, key, value, Nat.is_lt(List.length(&2, Attribute, entries), limit))

# An existing key is always replaced; a new key is subject to the count.
def Attributes.set_within.present(count: Maybe<&2, Nat>, entries: List<&2, Attribute>, dropped: Nat, key: String,
  value: AttributeValue, present: Bool) -> Attributes:
  match present:
    case True{}:
      Attributes{Attributes.set.go(entries, key, value), dropped}
    case False{}:
      Attributes.set_within.room(count, entries, dropped, key, value)

# Set a key to a value under limits: the value is cut to the length limit;
# an existing key takes it in place; a new key is appended while the count
# is below the limit and dropped and counted once the limit is reached.
def Attributes.set_within(limits: AttributeLimits, attributes: Attributes, +key: String, value: AttributeValue) -> Attributes:
  match limits attributes:
    case AttributeLimits{count, length} Attributes{+entries, dropped}:
      Attributes.set_within.present(count, entries, dropped, key, AttributeValue.truncate(length, value),
        Attributes.has.go(entries, key))

# Each attribute set in turn under the limits, the list first.
def Attributes.set_all_within.go(entries: List<&2, Attribute>, +limits: AttributeLimits, attributes: Attributes) -> Attributes:
  match entries:
    case Nil{}:
      attributes
    case Con{Attribute{key, value}, rest}:
      Attributes.set_all_within.go(rest, limits, Attributes.set_within(limits, attributes, key, value))

# Set several attributes under limits, in order: a fold of
# Attributes.set_within.
def Attributes.set_all_within(limits: AttributeLimits, attributes: Attributes, entries: List<&2, Attribute>) -> Attributes:
  Attributes.set_all_within.go(entries, limits, attributes)

# A collection re-enforced under limits: its attributes set again, in order,
# under the limits, starting from no attributes and the count it had already
# dropped, so that what the limits drop now adds to it. A span applies it to
# the attributes of an event and of a link it adds (#6), which their authors
# built with no limits in sight (law attributes_within).
def Attributes.within(limits: AttributeLimits, attributes: Attributes) -> Attributes:
  match attributes:
    case Attributes{entries, dropped}:
      Attributes.set_all_within(limits, Attributes{Nil{}, dropped}, entries)

# Timestamps
# ==========
#
# The nanosecond arithmetic runs on U32, which the checker computes bit by
# bit; the seconds are a Nat, native at run time.

# The timestamp of seconds and a nanosecond remainder known to be below one
# second, or normalized when it is not: the whole seconds of the remainder
# move into the seconds.
def Timestamp.from_unix.checked(seconds: Nat, +nanoseconds: U32, below: Bool) -> Timestamp:
  match below:
    case True{}:
      Timestamp{seconds, nanoseconds}
    case False{}:
      Timestamp{Nat.add(seconds, U32.to_nat(U32.div(nanoseconds, 1000000000))), U32.mod(nanoseconds, 1000000000)}

# The timestamp of whole seconds since the Unix epoch and nanoseconds within
# them; nanoseconds of a second or more are carried into the seconds.
def Timestamp.from_unix(seconds: Nat, +nanoseconds: U32) -> Timestamp:
  Timestamp.from_unix.checked(seconds, nanoseconds, U32.is_lt(nanoseconds, 1000000000))

# The timestamp of milliseconds since the Unix epoch: the whole seconds and
# the remainder as nanoseconds.
def Timestamp.from_milliseconds(+milliseconds: Nat) -> Timestamp:
  Timestamp.from_unix(Nat.div(milliseconds, 1000n), U32.mul(U32.from_nat(Nat.mod(milliseconds, 1000n)), 1000000))

# The whole seconds since the Unix epoch.
def Timestamp.seconds(timestamp: Timestamp) -> Nat:
  match timestamp:
    case Timestamp{seconds, nanoseconds}:
      seconds

# The nanoseconds within the second, below 1000000000.
def Timestamp.nanoseconds(timestamp: Timestamp) -> U32:
  match timestamp:
    case Timestamp{seconds, nanoseconds}:
      nanoseconds

# The milliseconds since the Unix epoch, the nanoseconds below a
# millisecond dropped.
def Timestamp.milliseconds(timestamp: Timestamp) -> Nat:
  match timestamp:
    case Timestamp{seconds, nanoseconds}:
      Nat.add(Nat.mul(seconds, 1000n), U32.to_nat(U32.div(nanoseconds, 1000000)))

# The order of two timestamps: by seconds, then by nanoseconds.
def Timestamp.cmp.fin(seconds: Cmp, nanoseconds: Cmp) -> Cmp:
  match seconds:
    case LT{}:
      LT{}
    case EQ{}:
      nanoseconds
    case GT{}:
      GT{}

# Compare two timestamps: LT when the first is earlier, EQ when they are the
# same instant, GT when it is later.
def Timestamp.cmp(a: Timestamp, b: Timestamp) -> Cmp:
  match a b:
    case Timestamp{seconds_a, nanoseconds_a} Timestamp{seconds_b, nanoseconds_b}:
      Timestamp.cmp.fin(Nat.cmp(seconds_a, seconds_b), U32.cmp(nanoseconds_a, nanoseconds_b))

# Whether two timestamps are the same instant.
def Timestamp.is_eq(a: Timestamp, b: Timestamp) -> Bool:
  Cmp.is_eq(Timestamp.cmp(a, b))

# Whether two timestamps are different instants.
def Timestamp.is_ne(a: Timestamp, b: Timestamp) -> Bool:
  Bool.not(Cmp.is_eq(Timestamp.cmp(a, b)))

# Whether the first timestamp is earlier than the second.
def Timestamp.is_lt(a: Timestamp, b: Timestamp) -> Bool:
  Cmp.is_lt(Timestamp.cmp(a, b))

# Whether the first timestamp is not later than the second.
def Timestamp.is_le(a: Timestamp, b: Timestamp) -> Bool:
  Cmp.is_le(Timestamp.cmp(a, b))

# Whether the first timestamp is later than the second.
def Timestamp.is_gt(a: Timestamp, b: Timestamp) -> Bool:
  Cmp.is_gt(Timestamp.cmp(a, b))

# Whether the first timestamp is not earlier than the second.
def Timestamp.is_ge(a: Timestamp, b: Timestamp) -> Bool:
  Cmp.is_ge(Timestamp.cmp(a, b))

# Span context
# ============
#
# The identity of a span (#5): a remote span context, received from another
# participant, or a local span context, an operation of this participant,
# each with its tracestate. The variants wrap bend-trace-context's incoming
# and outgoing contexts, so that its type rule holds here too: a received
# context is continued or forwarded, never sent as this participant's own
# operation. Whether a span context is remote is the variant: an SDK or a
# propagator matches RemoteSpanContext and LocalSpanContext, and
# SpanContext.is_remote answers it as a Boolean.
#
# There is no invalid span context, and no all-zero identity. Where the
# OpenTelemetry specification has one, this API has an absence: `None{}` of
# a `Maybe<&2, SpanContext>`. A context may carry no span context, and a span
# started without an SDK and without a parent has none (#2). Trace flags as a
# number and a remote span context built from parts come with #10.

# A remote span context: the incoming context that extraction gave for a
# received message, or one built from parts with TC.IncomingContext.from_remote
# (laws span_context_remote and remote_readers).
def SpanContext.remote(incoming: TC.IncomingContext) -> SpanContext:
  RemoteSpanContext{incoming}

# A local span context: an outgoing context of this participant's operation,
# with the tracestate it sends (laws span_context_local and local_readers).
def SpanContext.local(outgoing: TC.OutgoingContext) -> SpanContext:
  LocalSpanContext{outgoing}

# Whether the span context was received from another participant.
def SpanContext.is_remote(context: SpanContext) -> Bool:
  match context:
    case RemoteSpanContext{incoming}:
      True{}
    case LocalSpanContext{outgoing}:
      False{}

# The trace the span belongs to.
def SpanContext.trace_id(context: SpanContext) -> TC.TraceId:
  match context:
    case RemoteSpanContext{incoming}:
      TC.RemoteContext.trace_id(TC.IncomingContext.context(incoming))
    case LocalSpanContext{outgoing}:
      TC.LocalContext.trace_id(TC.OutgoingContext.context(outgoing))

# The span's own identifier: the sender's operation for a remote span
# context, this participant's for a local one.
def SpanContext.span_id(context: SpanContext) -> TC.SpanId:
  match context:
    case RemoteSpanContext{incoming}:
      TC.RemoteContext.span_id(TC.IncomingContext.context(incoming))
    case LocalSpanContext{outgoing}:
      TC.LocalContext.span_id(TC.OutgoingContext.context(outgoing))

# The sampled indication: the trace flag that says the trace is sampled, as
# received or as this participant sends it.
def SpanContext.is_sampled(context: SpanContext) -> Bool:
  match context:
    case RemoteSpanContext{incoming}:
      TC.RemoteContext.is_sampled(TC.IncomingContext.context(incoming))
    case LocalSpanContext{outgoing}:
      TC.LocalContext.is_sampled(TC.OutgoingContext.context(outgoing))

# The tracestate: the vendor state received with a remote span context, or
# the state a local one sends.
def SpanContext.tracestate(context: SpanContext) -> TC.TraceState:
  match context:
    case RemoteSpanContext{incoming}:
      TC.IncomingContext.state(incoming)
    case LocalSpanContext{outgoing}:
      TC.OutgoingContext.state(outgoing)

# The trace ID as its 32 lowercase hexadecimal digits (law hex_readers).
def SpanContext.trace_id_hex(context: SpanContext) -> String:
  TC.TraceId.to_string(SpanContext.trace_id(context))

# The span ID as its 16 lowercase hexadecimal digits (law hex_readers).
def SpanContext.span_id_hex(context: SpanContext) -> String:
  TC.SpanId.to_string(SpanContext.span_id(context))

# The wrapped incoming context of a remote span context, as a propagator
# forwards it; None{} for a local one.
def SpanContext.incoming(context: SpanContext) -> Maybe<&2, TC.IncomingContext>:
  match context:
    case RemoteSpanContext{incoming}:
      Some{incoming}
    case LocalSpanContext{outgoing}:
      None{}

# The wrapped outgoing context of a local span context, as a propagator
# emits it; None{} for a remote one.
def SpanContext.outgoing(context: SpanContext) -> Maybe<&2, TC.OutgoingContext>:
  match context:
    case RemoteSpanContext{incoming}:
      None{}
    case LocalSpanContext{outgoing}:
      Some{outgoing}

# Context
# =======
#
# The explicit context (#5): the value that code passes to carry the current
# span context, and later baggage and propagation extras (#26), across calls
# and into forked computations. Every operation that needs a parent takes
# one; there is no attach, detach or current context, and nothing is
# attached to a thread or a computation. It is `Data`: instrumentation marks
# it reusable and copies it into forked computations.
#
# The record is closed: callers build it with Context.empty and read and
# change it through the operations below, never by constructing or matching
# it, so that a field added later breaks no caller.

# The context with no span context: a program's root, from which a span
# starts a new trace (law context_empty).
def Context.empty() -> Context:
  Context{None{}}

# The context with `span_context` as its span context, in place of any it
# carried (law context_set_then_read).
def Context.set_span_context(context: Context, span_context: SpanContext) -> Context:
  match context:
    case Context{previous}:
      Context{Some{span_context}}

# The span context the context carries, if any.
def Context.span_context(context: Context) -> Maybe<&2, SpanContext>:
  match context:
    case Context{span_context}:
      span_context

# The context without its span context: a span started from it begins a new
# trace (law context_cleared).
def Context.clear_span_context(context: Context) -> Context:
  match context:
    case Context{span_context}:
      Context{None{}}

# Instrumentation scope
# =====================
#
# The instrumentation scope (#6) identifies the instrumentation that created
# a span: a tracer carries one, and so does every span it starts. The
# constructor InstrumentationScope{name, version, schema_url, attributes}
# builds it; these readers answer its fields (law scope_readers).

# The name of the instrumentation, such as its package name.
def InstrumentationScope.name(scope: InstrumentationScope) -> String:
  match scope:
    case InstrumentationScope{name, version, schema_url, attributes}:
      name

# The version of the instrumentation, if it has one.
def InstrumentationScope.version(scope: InstrumentationScope) -> Maybe<&2, String>:
  match scope:
    case InstrumentationScope{name, version, schema_url, attributes}:
      version

# The schema URL of the semantic conventions the instrumentation follows, if
# it names one.
def InstrumentationScope.schema_url(scope: InstrumentationScope) -> Maybe<&2, String>:
  match scope:
    case InstrumentationScope{name, version, schema_url, attributes}:
      schema_url

# The attributes of the instrumentation scope.
def InstrumentationScope.attributes(scope: InstrumentationScope) -> Attributes:
  match scope:
    case InstrumentationScope{name, version, schema_url, attributes}:
      attributes

# Span options
# ============
#
# The start options (#6): what instrumentation asks of a span it starts,
# beyond its name. The record is closed: callers build it with
# SpanOptions.default and the with_ operations, and read it with the readers,
# so that an option added later breaks no caller.

# The default options: an internal span with no initial attributes or links,
# no start timestamp, and a parent taken from the context (law
# default_options).
def SpanOptions.default() -> SpanOptions:
  SpanOptions{Internal{}, Nil{}, Nil{}, None{}, False{}}

# The options with the kind (law options_set_then_read).
def SpanOptions.with_kind(options: SpanOptions, kind: SpanKind) -> SpanOptions:
  match options:
    case SpanOptions{previous, attributes, links, start_timestamp, root}:
      SpanOptions{kind, attributes, links, start_timestamp, root}

# The options with the initial attributes, in place of any: the SDK sets
# them on the span under its limits when it starts it.
def SpanOptions.with_attributes(options: SpanOptions, attributes: List<&2, Attribute>) -> SpanOptions:
  match options:
    case SpanOptions{kind, previous, links, start_timestamp, root}:
      SpanOptions{kind, attributes, links, start_timestamp, root}

# The options with the links, in place of any: the SDK adds them to the span
# under its limits when it starts it.
def SpanOptions.with_links(options: SpanOptions, links: List<&2, Link>) -> SpanOptions:
  match options:
    case SpanOptions{kind, attributes, previous, start_timestamp, root}:
      SpanOptions{kind, attributes, links, start_timestamp, root}

# The options with an explicit start timestamp, in place of the SDK's clock.
def SpanOptions.with_start_timestamp(options: SpanOptions, timestamp: Timestamp) -> SpanOptions:
  match options:
    case SpanOptions{kind, attributes, links, previous, root}:
      SpanOptions{kind, attributes, links, Some{timestamp}, root}

# The options with the root indication: a root span ignores the parent in
# the context and begins a new trace.
def SpanOptions.with_root(options: SpanOptions, root: Bool) -> SpanOptions:
  match options:
    case SpanOptions{kind, attributes, links, start_timestamp, previous}:
      SpanOptions{kind, attributes, links, start_timestamp, root}

# The kind asked for.
def SpanOptions.kind(options: SpanOptions) -> SpanKind:
  match options:
    case SpanOptions{kind, attributes, links, start_timestamp, root}:
      kind

# The initial attributes asked for.
def SpanOptions.attributes(options: SpanOptions) -> List<&2, Attribute>:
  match options:
    case SpanOptions{kind, attributes, links, start_timestamp, root}:
      attributes

# The links asked for.
def SpanOptions.links(options: SpanOptions) -> List<&2, Link>:
  match options:
    case SpanOptions{kind, attributes, links, start_timestamp, root}:
      links

# The explicit start timestamp, if one was given.
def SpanOptions.start_timestamp(options: SpanOptions) -> Maybe<&2, Timestamp>:
  match options:
    case SpanOptions{kind, attributes, links, start_timestamp, root}:
      start_timestamp

# Whether the span is to be a root.
def SpanOptions.is_root(options: SpanOptions) -> Bool:
  match options:
    case SpanOptions{kind, attributes, links, start_timestamp, root}:
      root

# Status
# ======
#
# The outcome of a span (#6): Unset{}, Ok{} or Error{description}. Only the
# last status set is kept, except that ok is final: once a span owner has
# validated the span as ok, a later status is ignored.

# The description of an error status; None{} for the unset and the ok
# status, which have none (law status_description).
def Status.description(status: Status) -> Maybe<&2, String>:
  match status:
    case Unset{}:
      None{}
    case Ok{}:
      None{}
    case Error{description}:
      Some{description}

# The status after setting `next` over `current`: `next`, unless `current`
# is ok, which is final (law status_after).
def Status.after(current: Status, next: Status) -> Status:
  match current:
    case Ok{}:
      Ok{}
    case other:
      next

# Events and links
# ================
#
# An event (#6) is built with a name, its attributes as a list, and a time:
# an explicit timestamp with SpanEvent.at, or an offset in milliseconds from
# the span's start reading with SpanEvent.at_offset, which the effectful
# addition of a later ticket measures with Base's monotonic clock. The
# exception event follows the specification's names. A link is built with
# Link.to. Each carries its attributes as a collection with its own dropped
# count; the span re-enforces its limits on them when it adds them, through
# SpanEvent.within and Link.within.

# The event named `name` with the attributes, at an explicit timestamp (law
# event_readers).
def SpanEvent.at(name: String, attributes: List<&2, Attribute>, timestamp: Timestamp) -> SpanEvent:
  SpanEvent{name, Attributes.from_list(attributes), AtTimestamp{timestamp}}

# The event named `name` with the attributes, at an offset in milliseconds
# from the span's start reading.
def SpanEvent.at_offset(name: String, attributes: List<&2, Attribute>, milliseconds: Nat) -> SpanEvent:
  SpanEvent{name, Attributes.from_list(attributes), AtOffset{milliseconds}}

# The exception event with extra attributes: named `exception`, with
# `exception.type` and `exception.message` as strings followed by the extra
# attributes, at the timestamp (law exception_with_event). There is no stack
# trace.
def SpanEvent.exception_with(type_name: String, message: String, attributes: List<&2, Attribute>,
  timestamp: Timestamp) -> SpanEvent:
  SpanEvent.at("exception", Con{Attribute{"exception.type", StringValue{type_name}},
    Con{Attribute{"exception.message", StringValue{message}}, attributes}}, timestamp)

# The exception event: named `exception`, with `exception.type` and
# `exception.message` as strings, at the timestamp (law exception_event).
def SpanEvent.exception(type_name: String, message: String, timestamp: Timestamp) -> SpanEvent:
  SpanEvent.exception_with(type_name, message, Nil{}, timestamp)

# The name of an event.
def SpanEvent.name(event: SpanEvent) -> String:
  match event:
    case SpanEvent{name, attributes, time}:
      name

# The attributes of an event, with their dropped count.
def SpanEvent.attributes(event: SpanEvent) -> Attributes:
  match event:
    case SpanEvent{name, attributes, time}:
      attributes

# When the event happened: AtTimestamp{timestamp} or AtOffset{milliseconds}.
def SpanEvent.time(event: SpanEvent) -> EventTime:
  match event:
    case SpanEvent{name, attributes, time}:
      time

# The event with its attributes re-enforced under limits, as a span stores
# it (law within_event_and_link).
def SpanEvent.within(limits: AttributeLimits, event: SpanEvent) -> SpanEvent:
  match event:
    case SpanEvent{name, attributes, time}:
      SpanEvent{name, Attributes.within(limits, attributes), time}

# The link to a span context, with the attributes (law link_readers).
def Link.to(span_context: SpanContext, attributes: List<&2, Attribute>) -> Link:
  Link{span_context, Attributes.from_list(attributes)}

# The span context a link points to.
def Link.span_context(link: Link) -> SpanContext:
  match link:
    case Link{span_context, attributes}:
      span_context

# The attributes of a link, with their dropped count.
def Link.attributes(link: Link) -> Attributes:
  match link:
    case Link{span_context, attributes}:
      attributes

# The link with its attributes re-enforced under limits, as a span stores it
# (law within_event_and_link).
def Link.within(limits: AttributeLimits, link: Link) -> Link:
  match link:
    case Link{span_context, attributes}:
      Link{span_context, Attributes.within(limits, attributes)}

# Spans
# =====
#
# A span (#6) is an affine value that its owner threads through the code:
# every operation below is pure and answers the span, so recording needs no
# effect and stays provable. A recording span, Recording{payload, data},
# applies each operation to its data and passes the SDK's payload through
# untouched (law recording_delegates); a non-recording span,
# NonRecording{span_context}, accepts every operation and keeps nothing
# (law non_recording_identity). Readers work on a copy: the span is Data,
# and a caller marks it `+span` to read it and keep it.
#
# The span's limits apply as each operation runs: attributes follow the
# collection's rules under the span's attribute limits (law
# span_attribute_rules), an event or a link is appended while its count is
# below the limit and dropped and counted once the limit is reached (laws
# event_added, event_dropped, link_added, link_dropped), and the attributes
# of an event and of a link are re-enforced under their own limits. The
# decisions on computed checks go through small helpers that take the check
# as a Bool, so that the proofs can rewrite it.
#
# An SDK's start slot builds a recording span with Span.recording, then
# applies the start options' attributes and links with Span.set_attributes
# and Span.add_links, so that the limits apply to them as to any other.
# Ending a span, the effect that hands its data to the SDK, comes with the
# SDK slots of a later ticket.

# Whether one more item fits under an optional count: always without a
# count, and while the length is below it with one.
def Span.room(count: Maybe<&2, Nat>, length: Nat) -> Bool:
  match count:
    case None{}:
      True{}
    case Some{limit}:
      Nat.is_lt(length, limit)

# The items with one appended when it is kept, the items as they are when it
# is dropped.
def Span.kept(-A: Data, items: List<&2, A>, item: A, kept: Bool) -> List<&2, A>:
  match kept:
    case True{}:
      List.append(&2, A, items, [item])
    case False{}:
      items

# The dropped count, grown by one when the item is dropped.
def Span.counted(dropped: Nat, kept: Bool) -> Nat:
  match kept:
    case True{}:
      dropped
    case False{}:
      1n+dropped

# New span data: the parts a span starts with, no attributes, events or
# links, nothing dropped and the unset status (law new_data_readers).
def SpanData.new(scope: InstrumentationScope, span_context: SpanContext, parent: Maybe<&2, SpanContext>, name: String,
  kind: SpanKind, start_timestamp: Timestamp, start_reading: Nat, sampled: Bool, limits: SpanLimits) -> SpanData:
  SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, Attributes.empty(), Nil{}, 0n,
    Nil{}, 0n, Unset{}, limits}

# The instrumentation scope of the tracer that started the span.
def SpanData.scope(data: SpanData) -> InstrumentationScope:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, limits}:
      scope

# The span's own span context.
def SpanData.span_context(data: SpanData) -> SpanContext:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, limits}:
      span_context

# The span context the span was started from; None{} for a root.
def SpanData.parent(data: SpanData) -> Maybe<&2, SpanContext>:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, limits}:
      parent

# The span's name.
def SpanData.name(data: SpanData) -> String:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, limits}:
      name

# The span's kind.
def SpanData.kind(data: SpanData) -> SpanKind:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, limits}:
      kind

# The timestamp the span started at.
def SpanData.start_timestamp(data: SpanData) -> Timestamp:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, limits}:
      start_timestamp

# The monotonic reading taken at start, in milliseconds, from which event
# offsets are measured.
def SpanData.start_reading(data: SpanData) -> Nat:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, limits}:
      start_reading

# The sampled indication: whether the sampler marked the trace as sampled.
def SpanData.is_sampled(data: SpanData) -> Bool:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, limits}:
      sampled

# The span's attributes, with their dropped count.
def SpanData.attributes(data: SpanData) -> Attributes:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, limits}:
      attributes

# The span's events, in the order they were added.
def SpanData.events(data: SpanData) -> List<&2, SpanEvent>:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, limits}:
      events

# How many events the span limits dropped.
def SpanData.dropped_events(data: SpanData) -> Nat:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, limits}:
      dropped_events

# The span's links, in the order they were added.
def SpanData.links(data: SpanData) -> List<&2, Link>:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, limits}:
      links

# How many links the span limits dropped.
def SpanData.dropped_links(data: SpanData) -> Nat:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, limits}:
      dropped_links

# The span's status.
def SpanData.status(data: SpanData) -> Status:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, limits}:
      status

# The span limits the span enforces.
def SpanData.limits(data: SpanData) -> SpanLimits:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, limits}:
      limits

# The data with the key set to the value under the span's attribute limits
# (law span_attribute_rules).
def SpanData.set_attribute(data: SpanData, key: String, value: AttributeValue) -> SpanData:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, +limits}:
      SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled,
        Attributes.set_within(SpanLimits.span_attributes(limits), attributes, key, value), events, dropped_events, links,
        dropped_links, status, limits}

# The data with each attribute set in turn under the span's attribute
# limits.
def SpanData.set_attributes(data: SpanData, entries: List<&2, Attribute>) -> SpanData:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, +limits}:
      SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled,
        Attributes.set_all_within(SpanLimits.span_attributes(limits), attributes, entries), events, dropped_events, links,
        dropped_links, status, limits}

# The data with the link added: appended, its attributes re-enforced under
# the link attribute limits, while the links are below the link count;
# dropped and counted once the count is reached (laws link_added,
# link_dropped).
def SpanData.add_link(data: SpanData, link: Link) -> SpanData:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, +links, dropped_links, status, +limits}:
      +kept = Span.room(SpanLimits.link_count(limits), List.length(&2, Link, links))
      SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes, events, dropped_events,
        Span.kept(Link, links, Link.within(SpanLimits.link_attributes(limits), link), kept), Span.counted(dropped_links, kept),
        status, limits}

# The data with each link added in turn: a fold of SpanData.add_link.
def SpanData.add_links(data: SpanData, links: List<&2, Link>) -> SpanData:
  List.foldl(~&2, ~Link, ~SpanData, ~SpanData.add_link, links, data)

# The data with the status set over its status: ok is final (law
# status_set).
def SpanData.set_status(data: SpanData, status: Status) -> SpanData:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, current, limits}:
      SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes, events, dropped_events,
        links, dropped_links, Status.after(current, status), limits}

# The data with the name replaced (law update_name_replaces).
def SpanData.update_name(data: SpanData, name: String) -> SpanData:
  match data:
    case SpanData{scope, span_context, parent, previous, kind, start_timestamp, start_reading, sampled, attributes,
      events, dropped_events, links, dropped_links, status, limits}:
      SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes, events, dropped_events,
        links, dropped_links, status, limits}

# The data with the event added: appended, its attributes re-enforced under
# the event attribute limits, while the events are below the event count;
# dropped and counted once the count is reached (laws event_added,
# event_dropped).
def SpanData.add_event(data: SpanData, event: SpanEvent) -> SpanData:
  match data:
    case SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
      +events, dropped_events, links, dropped_links, status, +limits}:
      +kept = Span.room(SpanLimits.event_count(limits), List.length(&2, SpanEvent, events))
      SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes,
        Span.kept(SpanEvent, events, SpanEvent.within(SpanLimits.event_attributes(limits), event), kept),
        Span.counted(dropped_events, kept), links, dropped_links, status, limits}

# The data with each event added in turn: a fold of SpanData.add_event.
def SpanData.add_events(data: SpanData, events: List<&2, SpanEvent>) -> SpanData:
  List.foldl(~&2, ~SpanEvent, ~SpanData, ~SpanData.add_event, events, data)

# A recording span from its parts, as an SDK's start slot builds it after
# sampling and identifier generation: the payload the SDK stores, the
# tracer's scope, the span's own span context, the parent span context if
# any, the name, the kind, the start timestamp, the monotonic reading taken
# at start, the sampled indication and the span limits (law
# recording_readers). It starts with no attributes, events or links; the
# start options' attributes and links go through Span.set_attributes and
# Span.add_links.
def Span.recording(-P: Data, payload: P, scope: InstrumentationScope, span_context: SpanContext,
  parent: Maybe<&2, SpanContext>, name: String, kind: SpanKind, start_timestamp: Timestamp, start_reading: Nat,
  sampled: Bool, limits: SpanLimits) -> Span<P>:
  Recording{payload, SpanData.new(scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, limits)}

# A non-recording span carrying an optional span context, its parent's, or
# the one an SDK chose for a dropped span (law non_recording_readers).
def Span.non_recording(-P: Data, span_context: Maybe<&2, SpanContext>) -> Span<P>:
  NonRecording{span_context}

# Whether the span is recording: whether an SDK records what is set on it.
# Instrumentation skips expensive attributes when it is not.
def Span.is_recording(-P: Data, span: Span<P>) -> Bool:
  match span:
    case Recording{payload, data}:
      True{}
    case NonRecording{span_context}:
      False{}

# The span context of the span, to inject it or link to it: a recording
# span's own, or the optional one a non-recording span carries.
def Span.span_context(-P: Data, span: Span<P>) -> Maybe<&2, SpanContext>:
  match span:
    case Recording{payload, data}:
      Some{SpanData.span_context(data)}
    case NonRecording{span_context}:
      span_context

# The name of a recording span; None{} for a non-recording span, which keeps
# none.
def Span.name(-P: Data, span: Span<P>) -> Maybe<&2, String>:
  match span:
    case Recording{payload, data}:
      Some{SpanData.name(data)}
    case NonRecording{span_context}:
      None{}

# The data of a recording span, for tests and for SDKs; None{} for a
# non-recording span, which keeps none.
def Span.data(-P: Data, span: Span<P>) -> Maybe<&2, SpanData>:
  match span:
    case Recording{payload, data}:
      Some{data}
    case NonRecording{span_context}:
      None{}

# Set one attribute: the key takes the value under the span's attribute
# limits, as Attributes.set_within sets it.
def Span.set_attribute(-P: Data, span: Span<P>, key: String, value: AttributeValue) -> Span<P>:
  match span:
    case Recording{payload, data}:
      Recording{payload, SpanData.set_attribute(data, key, value)}
    case NonRecording{span_context}:
      NonRecording{span_context}

# Set several attributes, in order, each under the span's attribute limits
# (law set_attributes_fold).
def Span.set_attributes(-P: Data, span: Span<P>, entries: List<&2, Attribute>) -> Span<P>:
  match span:
    case Recording{payload, data}:
      Recording{payload, SpanData.set_attributes(data, entries)}
    case NonRecording{span_context}:
      NonRecording{span_context}

# Add a link, under the link count and the link attribute limits.
def Span.add_link(-P: Data, span: Span<P>, link: Link) -> Span<P>:
  match span:
    case Recording{payload, data}:
      Recording{payload, SpanData.add_link(data, link)}
    case NonRecording{span_context}:
      NonRecording{span_context}

# Add several links, in order, each under the limits (law add_links_fold).
def Span.add_links(-P: Data, span: Span<P>, links: List<&2, Link>) -> Span<P>:
  match span:
    case Recording{payload, data}:
      Recording{payload, SpanData.add_links(data, links)}
    case NonRecording{span_context}:
      NonRecording{span_context}

# Set the status: the last status set is kept, except that ok is final (law
# ok_final).
def Span.set_status(-P: Data, span: Span<P>, status: Status) -> Span<P>:
  match span:
    case Recording{payload, data}:
      Recording{payload, SpanData.set_status(data, status)}
    case NonRecording{span_context}:
      NonRecording{span_context}

# Update the name: the new name replaces the old (law update_name_replaces).
def Span.update_name(-P: Data, span: Span<P>, name: String) -> Span<P>:
  match span:
    case Recording{payload, data}:
      Recording{payload, SpanData.update_name(data, name)}
    case NonRecording{span_context}:
      NonRecording{span_context}

# Add an event, under the event count and the event attribute limits.
def Span.add_event(-P: Data, span: Span<P>, event: SpanEvent) -> Span<P>:
  match span:
    case Recording{payload, data}:
      Recording{payload, SpanData.add_event(data, event)}
    case NonRecording{span_context}:
      NonRecording{span_context}

# Add an event with an explicit timestamp: the event SpanEvent.at builds
# (law event_shorthands).
def Span.add_event_at(-P: Data, span: Span<P>, name: String, attributes: List<&2, Attribute>, timestamp: Timestamp) -> Span<P>:
  Span.add_event(P, span, SpanEvent.at(name, attributes, timestamp))

# Add a list of events, in order, each under the limits: how a span owner
# records the observations a forked computation returned (law
# add_events_fold).
def Span.add_events(-P: Data, span: Span<P>, events: List<&2, SpanEvent>) -> Span<P>:
  match span:
    case Recording{payload, data}:
      Recording{payload, SpanData.add_events(data, events)}
    case NonRecording{span_context}:
      NonRecording{span_context}

# Record an exception with an explicit timestamp: the event named
# `exception` with `exception.type` and `exception.message` (law
# event_shorthands).
def Span.record_exception(-P: Data, span: Span<P>, type_name: String, message: String, timestamp: Timestamp) -> Span<P>:
  Span.add_event(P, span, SpanEvent.exception(type_name, message, timestamp))

# Record an exception with extra attributes and an explicit timestamp.
def Span.record_exception_with(-P: Data, span: Span<P>, type_name: String, message: String,
  attributes: List<&2, Attribute>, timestamp: Timestamp) -> Span<P>:
  Span.add_event(P, span, SpanEvent.exception_with(type_name, message, attributes, timestamp))
