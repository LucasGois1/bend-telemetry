# bend-telemetry-api

The OpenTelemetry tracing API for Bend: the package that instrumented code
depends on. It is written in pure Bend, imports no foreign code, and states
the rules it implements as laws that the Bend checker proves, so that every
library that depends on it stays provable. Its contract is the tracing API
specification, [issue #2](https://github.com/LucasGois1/bend-telemetry/issues/2);
the terms are those of the repository's glossary,
[CONTEXT.md](../../CONTEXT.md). This is a community project; it is not part
of, or endorsed by, the OpenTelemetry project.

**Status: in development.** This package holds the pure values of the API
([#4](https://github.com/LucasGois1/bend-telemetry/issues/4)): attribute
values, attributes, span limits and timestamps; and the span context and the
explicit context ([#5](https://github.com/LucasGois1/bend-telemetry/issues/5)).
Spans, tracers, the SDK slots and the no-op implementation follow in later
tickets, and nothing is published on BendHub yet.

A program imports the package by its BendHub name and version, never by a
relative path, and bend-trace-context beside it for the W3C Trace Context
values that a span context wraps:

```bend
import Base
import bend-telemetry-api@0.1.0.0/api.bend as Api
import bend-trace-context@0.2.0.0/trace_context.bend as TC
```

Every definition below is then `Api.Name`; the constructors of its types are
`Api.StringValue{...}`, `Api.Attribute{...}` and so on. The repository's
independent consumer, [tests/consumer/main.bend](../../tests/consumer/main.bend),
is a complete program over these values with its exact output beside it.

## Contents

- [Attribute values](#attribute-values): `AttributeValue`, with its
  [64-bit integers](#64-bit-integers) and [doubles](#doubles)
- [Attributes](#attributes): `Attribute` and the collection `Attributes`
- [Span limits](#span-limits): `SpanLimits`, `AttributeLimits` and
  `Attributes.set_within`
- [Timestamps](#timestamps): `Timestamp`
- [Span context](#span-context): `SpanContext`, remote or local
- [Context](#context): `Context`, the explicit context
- [Laws and proofs](#laws-and-proofs)
- [Writing Bend with the package](#writing-bend-with-the-package)

## Attribute values

An attribute value is any value that OTLP's `AnyValue` carries. The type has
eight constructors:

| Constructor | Holds |
| --- | --- |
| `StringValue{value: String}` | a string |
| `BoolValue{value: Bool}` | a Boolean |
| `IntValue{value: Int64}` | a 64-bit integer |
| `DoubleValue{value: Double}` | a double |
| `BytesValue{cells: List<&2, U32>}` | bytes, each cell from 0 to 255 |
| `ArrayValue{items: List<&2, AttributeValue>}` | an array; arrays nest |
| `KvlistValue{entries: List<&2, Attribute>}` | a key-value list; they nest too |
| `EmptyValue{}` | the empty value |

The **standard values** of the specification are the four primitives and
homogeneous arrays of them: those are the values that backends reliably
accept. The constructors below build the arrays; use the primitives'
constructors directly for single values.

| Definition | Builds |
| --- | --- |
| `AttributeValue.strings(values: List<&2, String>)` | an array of string values |
| `AttributeValue.bools(values: List<&2, Bool>)` | an array of Boolean values |
| `AttributeValue.ints(values: List<&2, Int64>)` | an array of integer values |
| `AttributeValue.doubles(values: List<&2, Double>)` | an array of double values |
| `AttributeValue.bytes(cells: List<&2, U32>) -> Maybe<&2, AttributeValue>` | a bytes value, or `None{}` when a cell is above 255 |

Bytes follow Base's byte convention, a list of cells from 0 to 255, as
bend-trace-context's byte forms do. The other shapes, arrays of mixed or
nested values and key-value lists, complete OTLP's shape so that an exporter
needs no second conversion layer; backends may not accept them.

`AttributeValue.truncate(limit: Maybe<&2, Nat>, value)` is the value within
an optional length limit: a string longer than the limit is cut to its first
`limit` characters, and so is each string of an array; every other value,
and every value without a limit, is kept as it is.
[Span limits](#span-limits) apply it to every value they store.

### 64-bit integers

`Int64` is the integer of an attribute value: a 64-bit two's complement
number held as two `U32` limbs, since Base has no `U64` yet (local ADR 0006,
decided in the G8 grilling). The type is opaque: build a value with the
constructors and read it with the readers; the record behind it may change
when Base ships `U64`, and then constructors and readers for `U64` are added
beside these without breaking callers.

| Constructor | Value |
| --- | --- |
| `Int64.from_u32(value: U32)` | the value of a word, never negative |
| `Int64.from_nat(value: Nat)` | the value of a natural number, which Base keeps below 2^48 |
| `Int64.from_negated_nat(value: Nat)` | minus the natural number; zero stays zero |
| `Int64.from_limbs(high: U32, low: U32)` | the value whose two's complement limbs these are: the bridge for a caller holding a 64-bit value in another form |
| `Int64.read(text: String) -> Maybe<&2, Int64>` | the value of a decimal text: an optional minus sign and at least one digit, from -9223372036854775808 to 9223372036854775807; leading zeros are accepted, as Base's `U32.read` accepts them, and anything else answers `None{}` |

| Reader | Answers |
| --- | --- |
| `Int64.high(value) -> U32` | bits 63 to 32 |
| `Int64.low(value) -> U32` | bits 31 to 0 |
| `Int64.is_negative(value) -> Bool` | whether the value is below zero: bit 31 of the high limb |
| `Int64.show(value) -> String` | the decimal text: an optional minus sign and digits without leading zeros, which `Int64.read` reads back |

There is no general arithmetic: an attribute value carries a number, it does
not compute with it. `-1` is both limbs all ones; an exporter writes the
limbs as OTLP's protobuf encoding expects and the decimal text as its JSON
encoding expects.

### Doubles

`Double` is the floating-point number of an attribute value, held as an
`F32` until Base ships `F64`. A value that `F32` cannot hold exactly loses
precision: this is the one hard conformance gap of attribute values, and an
exporter writes the exact widening of the `F32` to protobuf and Base's
shortest `F32` text to JSON (ADR 0006). The type is opaque, as `Int64` is.

| Definition | Answers |
| --- | --- |
| `Double.from_f32(value: F32)` | the double holding the `F32` |
| `Double.read(text: String) -> Maybe<&2, Double>` | the double of a decimal text, as Base's `F32.read` reads it, or `None{}` |
| `Double.to_f32(double) -> F32` | the `F32` it holds |
| `Double.show(double) -> String` | the shortest decimal text that reads back as the same `F32`, as Base's `F32.show` writes it |

## Attributes

An **attribute** is a key with a value: `Attribute{key: String, value:
AttributeValue}`, read with `Attribute.key` and `Attribute.value`. An
**attribute collection**, `Attributes`, keeps attributes in insertion order
with unique keys, and counts what span limits dropped. Keys are unique
within their owner: setting a key again replaces its value in place and
keeps its position; a new key goes last.

| Definition | Answers |
| --- | --- |
| `Attributes.empty()` | the empty collection |
| `Attributes.from_list(entries: List<&2, Attribute>)` | the collection of the attributes set in order: a repeated key keeps its first position and its last value |
| `Attributes.set(attributes, key: String, value: AttributeValue)` | the collection with the key set to the value, with no limit |
| `Attributes.set_all(attributes, entries: List<&2, Attribute>)` | each attribute set in turn: a fold of `Attributes.set` |
| `Attributes.set_within(limits: AttributeLimits, attributes, key, value)` | the collection with the key set under [span limits](#span-limits) |
| `Attributes.set_all_within(limits, attributes, entries)` | each attribute set in turn under the limits |
| `Attributes.get(attributes, key) -> Maybe<&2, AttributeValue>` | the value of the key, if the collection has it |
| `Attributes.has(attributes, key) -> Bool` | whether the collection has the key |
| `Attributes.count(attributes) -> Nat` | how many attributes it keeps |
| `Attributes.to_list(attributes) -> List<&2, Attribute>` | the attributes in insertion order |
| `Attributes.keys(attributes) -> List<&2, String>` | the keys in insertion order |
| `Attributes.dropped(attributes) -> Nat` | how many attributes span limits dropped |

The constructor `Attributes{entries, dropped}` is the representation, not
the contract: build collections with the operations above. The laws
`set_get`, `replace_keeps_count`, `replace_keeps_position`, `new_key_last`
and `keys_unique` of [LAWS.bend](LAWS.bend) state these rules for every
collection, and `set_all_fold` says that setting several attributes is the
same as setting them one by one.

For example, instrumentation sets a request's attributes and later replaces
one; `retries` holds a standard array of integers:

```bend
request = Api.Attributes.from_list([
  Api.Attribute{"http.request.method", Api.StringValue{"GET"}},
  Api.Attribute{"http.response.status_code", Api.IntValue{Api.Int64.from_u32(200)}},
  Api.Attribute{"retries", Api.AttributeValue.ints([Api.Int64.from_u32(1), Api.Int64.from_negated_nat(2n)])}])
# Replaced in place: the method stays first and the count stays three.
updated = Api.Attributes.set(request, "http.request.method", Api.StringValue{"POST"})
```

## Span limits

Span limits are the most attributes, events and links a span keeps, and the
longest attribute value; each operation enforces them as it runs and counts
what it drops. `SpanLimits` is a record of six optional limits; an absent
limit is unlimited:

| Field and reader | Default |
| --- | --- |
| `attribute_count` | `Some{128n}` |
| `attribute_value_length` | `None{}`: no length limit |
| `event_count` | `Some{128n}` |
| `link_count` | `Some{128n}` |
| `attribute_per_event_count` | `Some{128n}` |
| `attribute_per_link_count` | `Some{128n}` |

`SpanLimits.default()` holds the defaults of the specification and
`SpanLimits.unlimited()` limits nothing. The SDK sets a span's limits when
it starts the span; the no-op span has none, because it keeps nothing.

Attributes share one enforcement wherever they live, through
`AttributeLimits{count: Maybe<&2, Nat>, length: Maybe<&2, Nat>}`: the most
attributes a collection keeps and the longest string it keeps whole.
`SpanLimits.span_attributes(limits)`, `SpanLimits.event_attributes(limits)`
and `SpanLimits.link_attributes(limits)` derive the limits of a span's own
attributes, an event's and a link's, each with the count that applies to it
and the shared value length; `AttributeLimits.unlimited()` limits nothing,
and `AttributeLimits.count` and `AttributeLimits.length` read a value.

`Attributes.set_within(limits, attributes, key, value)` enforces them:

- the value is cut to the length limit with `AttributeValue.truncate`: a
  string, and each string of an array, longer than the limit keeps its first
  `limit` characters;
- an existing key is always replaced, in place, whatever the count;
- a new key is appended while the count is below the limit, and dropped and
  counted once the limit is reached: `Attributes.dropped` grows by one for
  each dropped attribute.

Under a limit of two attributes and three characters, setting `a` to
`"hello"`, `b` to `"hi"`, `c` to `"x"` and then `a` to `"world"` keeps
`a="wor"` and `b="hi"`, in that order, with one attribute dropped. The laws
`within_replaces`, `within_adds`, `within_drops`, `within_bounded` and
`truncate_string` state the rules for every collection; `within_literal`
is this example.

## Timestamps

A timestamp is an instant as nanoseconds since the Unix epoch, held as whole
seconds and a nanosecond remainder below one second. The type is opaque: a
later move to a 64-bit integer changes no caller.

| Definition | Answers |
| --- | --- |
| `Timestamp.from_unix(seconds: Nat, nanoseconds: U32)` | the timestamp of whole seconds and nanoseconds within them; nanoseconds of a second or more are carried into the seconds, so `from_unix(1n, 1500000000)` is `from_unix(2n, 500000000)` |
| `Timestamp.from_milliseconds(milliseconds: Nat)` | the timestamp of milliseconds since the epoch |
| `Timestamp.seconds(timestamp) -> Nat` | the whole seconds |
| `Timestamp.nanoseconds(timestamp) -> U32` | the nanoseconds within the second, below 1000000000 |
| `Timestamp.milliseconds(timestamp) -> Nat` | the milliseconds since the epoch, the rest dropped |
| `Timestamp.cmp(a, b) -> Cmp` | `LT{}`, `EQ{}` or `GT{}`: by seconds, then by nanoseconds |
| `Timestamp.is_eq`, `is_ne`, `is_lt`, `is_le`, `is_gt`, `is_ge` | the comparisons as Booleans |

Span start, span end and events carry a timestamp; the specification asks
for at least millisecond precision, which `from_milliseconds` gives, and
`from_unix` keeps whatever precision a clock has. Base's `Nat` holds
seconds and milliseconds since the epoch comfortably: it stops at 2^48 - 1.

## Span context

`Api.SpanContext` is the identity of a span: a remote span context, received
from another participant, or a local span context, an operation of this
participant, each with its tracestate. The two variants wrap
bend-trace-context's types, so that package's type rule holds here too: a
received context is continued or forwarded, never sent as this participant's
own operation.

| Variant | Wraps | Built by |
| --- | --- | --- |
| `RemoteSpanContext{incoming}` | `TC.IncomingContext` | `Api.SpanContext.remote(incoming)` |
| `LocalSpanContext{outgoing}` | `TC.OutgoingContext` | `Api.SpanContext.local(outgoing)` |

A remote span context comes from a received message, through
bend-trace-context's extraction (`TC.Extraction.incoming` of
`TC.Context.extract`). A local one comes from an operation of this
participant: an SDK builds the outgoing context with `TC.Context.from_ids`
and `TC.OutgoingContext.new`, or `TC.OutgoingContext.with_state` to send a
tracestate.

Whether a span context is remote is its variant. An SDK or a propagator
matches the two constructors; the readers below answer the parts, for either
variant:

| Reader | Answers |
| --- | --- |
| `Api.SpanContext.is_remote(context)` | `True{}` for a remote span context, `False{}` for a local one |
| `Api.SpanContext.trace_id(context)` | The trace ID, as a `TC.TraceId` |
| `Api.SpanContext.span_id(context)` | The span ID, as a `TC.SpanId` |
| `Api.SpanContext.trace_id_hex(context)` | The trace ID as its 32 lowercase hexadecimal digits |
| `Api.SpanContext.span_id_hex(context)` | The span ID as its 16 lowercase hexadecimal digits |
| `Api.SpanContext.is_sampled(context)` | The sampled indication |
| `Api.SpanContext.tracestate(context)` | The tracestate, as a `TC.TraceState` (`TC.TraceState.format` gives its text) |
| `Api.SpanContext.incoming(context)` | `Some{incoming}` for a remote span context, `None{}` for a local one |
| `Api.SpanContext.outgoing(context)` | `Some{outgoing}` for a local span context, `None{}` for a remote one |

Each reader agrees with the field of the wrapped context (laws
`remote_readers`, `local_readers` and `hex_readers`), and the variant tells
remote from local (laws `span_context_remote` and `span_context_local`). For
example, the remote span context of a received message, when its traceparent
was accepted:

```bend
def remote(extracted: Maybe<&2, TC.IncomingContext>) -> Maybe<&2, Api.SpanContext>:
  match extracted:
    case Some{incoming}:
      Some{Api.SpanContext.remote(incoming)}
    case None{}:
      None{}

# remote(TC.Extraction.incoming(TC.Context.extract(TC.Limits.default(), carrier, None{})))
```

Trace flags as a number from 0 to 3, and a remote span context built from a
trace ID, a span ID, a sampled indication and a tracestate, come with
[#10](https://github.com/LucasGois1/bend-telemetry/issues/10).

### Absence in place of an invalid span context

There is no invalid span context, and no all-zero identity. Where the
OpenTelemetry specification has an invalid span context, this API has an
absence: `None{}` of a `Maybe<&2, Api.SpanContext>`. A context may carry no
span context, and a span started without an SDK and without a parent has
none. Code never checks identifiers for validity: a value of
`Api.SpanContext` is always a valid identity, because bend-trace-context's
constructors admit no all-zero identifier. An exporter never meets absence,
because a span without a span context is never recorded.

## Context

`Api.Context` is the value that code passes explicitly to carry the current
span context, and later baggage, across calls and into forked computations.
Every operation that needs a parent takes one. There is no attach, detach or
current context, and no global: nothing is attached to a thread or a
computation. These rows of the OpenTelemetry compliance matrix are therefore
not applicable, as they are for Go.

The context is a closed `Data` record. Build it with `Api.Context.empty`,
and read and change it through its operations, never by constructing or
matching it, so that a field added later breaks no caller:

| Operation | Answers |
| --- | --- |
| `Api.Context.empty()` | The context with no span context |
| `Api.Context.set_span_context(context, span_context)` | The context with `span_context`, in place of any it carried |
| `Api.Context.span_context(context)` | `Some{span_context}`, or `None{}` when the context carries none |
| `Api.Context.clear_span_context(context)` | The context with no span context |

Reading after setting answers the span context that was set, and the empty
context and a cleared context read `None{}` (laws `context_set_then_read`,
`context_empty` and `context_cleared`).

Because the context is `Data`, code marks it reusable with `+` and copies it
into every call and forked computation that needs it. Here `handle` stands
for an application's own `Api.Context -> IO(Unit)`:

```bend
def serve(span_context: Api.SpanContext) -> IO(Unit):
  do IO<Unit>:
    +context : Api.Context = Api.Context.set_span_context(Api.Context.empty(), span_context)
    handle(context)
    handle(context)
```

## Laws and proofs

[LAWS.bend](LAWS.bend) states the package's claims and
[PROOF.bend](PROOF.bend) proves them; `./bend packages/api/PROOF.bend
--check-only` prints `ALL PROOFS CHECK` only when every law holds and nothing
the proofs import relies on `@unsafe` or foreign code. The laws over every
value are the rules of the attribute collection (set then get, replacement
in place, insertion order, unique keys), the enforcement of span limits
(replacement under any limits, appending below the count, dropping and
counting at the count, the count never above the limit, truncation to the
limit's length), the readers of timestamps and the millisecond constructor,
and the readers of the opaque numbers.

The laws of the span context and the context say that the variant tells
remote from local, that each reader agrees with the field of the wrapped
context, and that a context answers the span context set on it and none when
it is empty or cleared.

Where the universal statement is beyond what the checker computes, a law
states the property on literal values and the checker computes it: the
checker evaluates `Nat` in unary and `F32`'s text is a run-time primitive,
so the decimal text of 64-bit integers (including the minimum and the
maximum), the two's complement limbs of negated numbers, the normalization
of nanoseconds and the ordering of timestamps are stated on literal cases.
The consumer prints further literal cases, which the gates compare with
their expected output natively and on Node.

## Writing Bend with the package

`bend guide` explains the language; these points come up with this package:

- Bend is affine: a variable is used at most once, unless it is bound with
  `+`, as in `+request = Api.Attributes.from_list(...)`, which lets a value
  of a `Data` type be used again. Every type of this package is `Data`.
- A `match` inspects a parameter or a variable bound by a pattern, never a
  computed value: give the result of `Api.Attributes.get` or
  `Api.Int64.read` to a helper `def` that matches on its parameter.
- `Api.Int64.read` and `Api.AttributeValue.bytes` answer `Maybe`; the span
  operations that follow never fail at run time (spec #2, "Errors").
- Numbers have no hexadecimal literals, and a `Nat` literal stops at
  `4294967295n`: build a larger `Nat` with `Nat.mul` and `Nat.add`, as the
  consumer builds a count of milliseconds.
