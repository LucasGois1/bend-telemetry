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
# their enforcement, and timestamps; and the span context and the explicit
# context (#5). Spans, tracers and the SDK slots follow in later tickets.
# The package imports no foreign code, so that every library that depends on
# it stays provable; the claims this code must satisfy are stated in
# LAWS.bend and proved in PROOF.bend, beside this file. README.md beside
# this file is the reference.
#
# W3C Trace Context comes from bend-trace-context, imported by its BendHub
# name and version, never by a relative path (#1). The glossary of the
# repository's CONTEXT.md supplies the terms: attribute, attribute value,
# span limits, timestamp, span context, context.
#
# Three types are opaque: Int64, Double and Timestamp. Their constructors are
# their representation, which later Base releases may change (U64, F64), not
# their contract: callers build them with the constructors below and read
# them with the readers, and nothing else of them is promised.
#
# Contents
#
#   Package            Package.name, TraceContext.fields
#   Types              every public type, declared first
#   64-bit integers    Int64.*
#   Doubles            Double.*
#   Attribute values   AttributeValue.*
#   Attributes         Attribute.*, Attributes.*
#   Span limits        AttributeLimits.*, SpanLimits.*, Attributes.set_within
#   Timestamps         Timestamp.*
#   Span context       SpanContext.*
#   Context            Context.*

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
