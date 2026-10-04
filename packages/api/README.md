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
values, attributes, span limits and timestamps; the span context and the
explicit context ([#5](https://github.com/LucasGois1/bend-telemetry/issues/5));
and the span with its two states, recording and non-recording, its pure
operations, its events, links, status, kinds, start options and
instrumentation scope ([#6](https://github.com/LucasGois1/bend-telemetry/issues/6)).
Tracers, span start and end, the SDK slots and the no-op implementation
follow in later tickets, and nothing is published on BendHub yet.

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
- [Instrumentation scope](#instrumentation-scope): `InstrumentationScope`
- [Span options](#span-options): `SpanOptions` and the kinds, `SpanKind`
- [Status](#status): `Status`
- [Events](#events): `SpanEvent` and `EventTime`, with the
  [exception event](#the-exception-event)
- [Links](#links): `Link`
- [Spans](#spans): `Span`, recording or non-recording, its
  [operations](#operations), its [readers](#readers), its data `SpanData`
  and the [span limits at work](#span-limits-at-work)
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

## Instrumentation scope

`Api.InstrumentationScope` is the name, version, schema URL and attributes
that identify the instrumentation that created a span, such as an HTTP
instrumentation package. A tracer carries one, and so does every span it
starts. The constructor builds it; the version and the schema URL are
optional:

```bend
scope = Api.InstrumentationScope{"my-http-client", Some{"1.2.0"}, None{}, Api.Attributes.empty()}
```

| Reader | Answers |
| --- | --- |
| `Api.InstrumentationScope.name(scope)` | The name of the instrumentation, such as its package name |
| `Api.InstrumentationScope.version(scope)` | `Some{version}`, or `None{}` |
| `Api.InstrumentationScope.schema_url(scope)` | `Some{url}` of the semantic conventions it follows, or `None{}` |
| `Api.InstrumentationScope.attributes(scope)` | Its attributes |

Each reader answers the field the scope was built with (law
`scope_readers`). The API keeps an empty name as given; what an SDK does
with it belongs to the SDK's configuration and error handling.

## Span options

`Api.SpanOptions` is what instrumentation asks of a span it starts, beyond
its name: the kind, the initial attributes and links, an optional start
timestamp and whether the span is a root. The record is closed: build it
from `Api.SpanOptions.default()` with the `with_` operations and read it
with the readers, never by constructing or matching it, so that an option
added later breaks no caller.

| Operation | Answers |
| --- | --- |
| `Api.SpanOptions.default()` | The options of an internal span with no initial attributes or links, no start timestamp, and a parent taken from the context |
| `Api.SpanOptions.with_kind(options, kind: SpanKind)` | The options with the kind |
| `Api.SpanOptions.with_attributes(options, attributes: List<&2, Attribute>)` | The options with the initial attributes, in place of any |
| `Api.SpanOptions.with_links(options, links: List<&2, Link>)` | The options with the links, in place of any |
| `Api.SpanOptions.with_start_timestamp(options, timestamp: Timestamp)` | The options with an explicit start timestamp, in place of the SDK's clock |
| `Api.SpanOptions.with_root(options, root: Bool)` | The options with the root indication: a root ignores the parent in the context and begins a new trace |
| `Api.SpanOptions.kind`, `attributes`, `links`, `start_timestamp`, `is_root` | The readers: `start_timestamp` answers `Maybe<&2, Timestamp>` |

The default is as stated, and each option set is what its reader answers
(laws `default_options` and `options_set_then_read`). The SDK's start slot
receives the options with the span's name: it sets the attributes and adds
the links under the span's limits, and uses the start timestamp in place
of its clock when one was given.

`Api.SpanKind` is how a span relates to its parent and its children in the
trace: `Api.Internal{}`, the default; `Api.Server{}` and `Api.Client{}`,
which frame a remote request; `Api.Producer{}` and `Api.Consumer{}`, which
frame a message.

## Status

`Api.Status` is the outcome of a span: `Api.Unset{}`, `Api.Ok{}` or
`Api.Error{description}`. A description exists only in the error variant:
`Api.Status.description(status)` answers `Some{description}` for an error
and `None{}` for the other two (law `status_description`). Setting a status
on a span keeps the last status set, except that ok is final: once a span
owner has validated the span as ok, a later status is ignored (laws
`status_after`, `status_set` and `ok_final`). `Api.Status.after(current,
next)` is that transition, which `Span.set_status` applies.

## Events

An event is a named, timestamped record with attributes on a span; a
recorded exception is an event. The type is `Api.SpanEvent`, since Base's
`Event` is the window event, and its time is an `Api.EventTime`: an explicit
timestamp, `Api.AtTimestamp{timestamp}`, or an offset in milliseconds from
the span's start reading, `Api.AtOffset{milliseconds}`.

| Constructor | Builds |
| --- | --- |
| `Api.SpanEvent.at(name, attributes: List<&2, Attribute>, timestamp)` | An event at an explicit timestamp |
| `Api.SpanEvent.at_offset(name, attributes, milliseconds: Nat)` | An event at an offset from the span's start reading |
| `Api.SpanEvent.exception(type_name, message, timestamp)` | The [exception event](#the-exception-event) |
| `Api.SpanEvent.exception_with(type_name, message, attributes, timestamp)` | The exception event with extra attributes |

| Reader | Answers |
| --- | --- |
| `Api.SpanEvent.name(event)` | The name |
| `Api.SpanEvent.attributes(event)` | The attributes, an `Attributes` with its own dropped count |
| `Api.SpanEvent.time(event)` | `Api.AtTimestamp{timestamp}` or `Api.AtOffset{milliseconds}` |

Each reader answers what the event was built with (law `event_readers`). An
offset is how the effectful addition of a later ticket records an event
without a timestamp: it reads Base's monotonic clock and stores the
milliseconds since the span's start reading, and the SDK resolves offsets
to wall time at the end, from the start timestamp. Events therefore have at
least millisecond precision, as the specification requires; an explicit
timestamp keeps its own. An exporter or an SDK matches the two
constructors of `EventTime`.

A span adds an event under its own limits, so an author builds events with
no limits in sight: a forked computation returns its observations as a
list of events, and the span owner adds them.
`Api.SpanEvent.within(limits: AttributeLimits, event)` is the event as a
span stores it, with its attributes re-enforced under the limits by
`Api.Attributes.within(limits, attributes)`: the attributes set again in
order under the limits, starting from no attributes and the count already
dropped, so that what the limits drop now adds to it (laws
`attributes_within`, `within_event_and_link` and `event_limits_literal`).

### The exception event

`Api.SpanEvent.exception(type_name, message, timestamp)` is the event named
`exception` with the attributes `exception.type` and `exception.message`,
both strings given by the caller, at the timestamp (law `exception_event`).
`Api.SpanEvent.exception_with(type_name, message, attributes, timestamp)`
puts the extra attributes after those two, so an extra attribute with a
standard key replaces the standard value in place (law
`exception_with_event`). There is no stack trace. `Span.record_exception`
and `Span.record_exception_with` add these events to a span.

## Links

A link is a reference from a span to another span context, with
attributes, for causal relations that are not parent and child.
`Api.Link.to(span_context, attributes: List<&2, Attribute>)` builds one;
`Api.Link.span_context(link)` and `Api.Link.attributes(link)` read it, the
attributes as an `Attributes` with its own dropped count (law
`link_readers`). `Api.Link.within(limits: AttributeLimits, link)` is the
link as a span stores it, with its attributes re-enforced under the limits,
as for an event.

## Spans

`Api.Span<P>` is a span whose SDK payload type is `P`: a `Data` type the SDK
chooses to carry its configuration in every recording span, so that ending
a span needs nothing but the span. The API never inspects the payload. A
span has two states:

| State | Holds | Built by |
| --- | --- | --- |
| A recording span, `Api.Recording{payload, data}` | The payload and the span's data, an `Api.SpanData` | `Api.Span.recording(P, payload, scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, limits)` |
| A non-recording span, `Api.NonRecording{span_context}` | Only an optional span context, its parent's | `Api.Span.non_recording(P, span_context: Maybe<&2, SpanContext>)` |

A span is an affine `Data` value that its owner threads through the code:
every operation below is pure and answers the span, so recording needs no
effect and stays provable, and a forked computation receives the context,
not the span, and returns its observations as events. Ending a span, the
one effect, which hands a recording span's data and payload to the SDK,
comes with the SDK slots of a later ticket, as do the tracers that start
spans. An SDK's start slot builds a recording span with `Api.Span.recording`
after sampling and identifier generation, with the span's own span context,
the parent span context from the context if any, the start timestamp, the
monotonic reading taken at start, the sampled indication and the span
limits; it then applies the start options' attributes and links with
`set_attributes` and `add_links`, so that the limits apply to them as to
any other. The no-op start, of a later ticket, builds a non-recording span
carrying the parent's span context, so that propagation continues.

`P` is the first argument of every operation, erased at run time. The
repository's consumer uses `Unit`:

```bend
span = Api.Span.set_attribute(Unit, span, "http.request.method", Api.StringValue{"GET"})
```

### Operations

Each operation answers the span. On a recording span it is the operation
on the span's data, with the payload passed through untouched (law
`recording_delegates`); on a non-recording span every operation answers the
span unchanged (law `non_recording_identity`), so instrumentation has one
code path whether or not an SDK records.

| Operation | On a recording span |
| --- | --- |
| `Api.Span.set_attribute(P, span, key, value)` | Sets the key to the value under the span's attribute limits, as [`Attributes.set_within`](#span-limits) does |
| `Api.Span.set_attributes(P, span, attributes: List<&2, Attribute>)` | Sets each attribute in turn, under the limits |
| `Api.Span.add_link(P, span, link)` | Appends the link, with its attributes under the link attribute limits, while the links are below the link count; drops and counts it once the count is reached |
| `Api.Span.add_links(P, span, links: List<&2, Link>)` | Adds each link in turn |
| `Api.Span.set_status(P, span, status)` | Sets the status; ok is final |
| `Api.Span.update_name(P, span, name)` | Replaces the name |
| `Api.Span.add_event(P, span, event: SpanEvent)` | Appends the event, with its attributes under the event attribute limits, while the events are below the event count; drops and counts it once the count is reached |
| `Api.Span.add_event_at(P, span, name, attributes, timestamp)` | Adds the event `SpanEvent.at` builds: an event with an explicit timestamp |
| `Api.Span.add_events(P, span, events: List<&2, SpanEvent>)` | Adds each event in turn: how a span owner records the observations a forked computation returned |
| `Api.Span.record_exception(P, span, type_name, message, timestamp)` | Adds the exception event |
| `Api.Span.record_exception_with(P, span, type_name, message, attributes, timestamp)` | Adds the exception event with extra attributes |

The attributes of a span follow the rules of the collection under the
span's attribute limits, so every law of [attributes](#attributes) and of
[span limits](#span-limits) holds of them (law `span_attribute_rules`);
setting several attributes, adding several events and adding several links
are folds of the single operations (laws `set_attributes_fold`,
`add_events_fold` and `add_links_fold`); an update replaces the name (law
`update_name_replaces`); and the shorthands add exactly the events their
constructors build (law `event_shorthands`).

### Readers

Readers work on a copy: the span is `Data`, so a caller marks it `+span` to
read it and keep it.

| Reader | Answers |
| --- | --- |
| `Api.Span.is_recording(P, span)` | `True{}` for a recording span, `False{}` for a non-recording one: instrumentation skips expensive attributes when it is `False{}` |
| `Api.Span.span_context(P, span)` | `Some{span_context}` of a recording span, to inject it or link to it; the optional span context a non-recording span carries |
| `Api.Span.name(P, span)` | `Some{name}`, or `None{}` for a non-recording span, which keeps none |
| `Api.Span.data(P, span)` | `Some{data}`, or `None{}` for a non-recording span |

A recording span built from parts is recording and answers the span
context, the name and the data it was built with; a non-recording span is
not recording, answers its optional span context, and has no name and no
data (laws `recording_readers` and `non_recording_readers`).

### Span data

`Api.SpanData` is everything a recording span holds but the payload: what
the SDK's end slot receives and an exporter encodes. `Api.SpanData.new(scope,
span_context, parent, name, kind, start_timestamp, start_reading, sampled,
limits)` is the data a span starts with, and each reader answers the field
it was built with (law `new_data_readers`):

| Reader | Answers |
| --- | --- |
| `Api.SpanData.scope(data)` | The instrumentation scope of the tracer that started the span |
| `Api.SpanData.span_context(data)` | The span's own span context |
| `Api.SpanData.parent(data)` | `Some{parent}` it was started from, or `None{}` for a root |
| `Api.SpanData.name(data)` | The name |
| `Api.SpanData.kind(data)` | The kind |
| `Api.SpanData.start_timestamp(data)` | The timestamp it started at |
| `Api.SpanData.start_reading(data)` | The monotonic reading taken at start, in milliseconds, from which event offsets are measured |
| `Api.SpanData.is_sampled(data)` | The sampled indication |
| `Api.SpanData.attributes(data)` | The attributes, with their dropped count; empty at start |
| `Api.SpanData.events(data)` | The events, in the order added; none at start |
| `Api.SpanData.dropped_events(data)` | How many events the limits dropped |
| `Api.SpanData.links(data)` | The links, in the order added; none at start |
| `Api.SpanData.dropped_links(data)` | How many links the limits dropped |
| `Api.SpanData.status(data)` | The status; `Api.Unset{}` at start |
| `Api.SpanData.limits(data)` | The span limits the span enforces |

The operations of a recording span are `Api.SpanData.set_attribute`,
`set_attributes`, `add_link`, `add_links`, `set_status`, `update_name`,
`add_event` and `add_events` on its data, with the same arguments after the
data; the laws of events and links are stated on them. An SDK and an
exporter read the data with the readers or by matching the constructor
`Api.SpanData{...}`, whose fields are the readers' in that order.

### Span limits at work

A span's limits apply as each operation runs. An event or a link is kept
while its count is below the limit, with its attributes re-enforced under
the limits per event or per link, and dropped and counted once the limit is
reached; without a count limit, everything is kept; and the count never
exceeds the limit (laws `event_added`, `event_dropped`, `event_unlimited`
and `events_bounded`, and their link counterparts). Under limits of two
attributes of at most eight characters, four events of two attributes and
one link of one attribute, the consumer sets three attributes, adds two
links and six events, and reads back two attributes with one dropped, one
link with one dropped, four events with two dropped, and `exception.type`
cut to `TimeoutE`; its exact output is in
[tests/consumer/expected.txt](../../tests/consumer/expected.txt).

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

The laws of spans say that every operation on a recording span is the
operation on its data with the payload untouched, and the identity on a
non-recording span; that the span's attributes follow the collection's rules
under its limits; that ok is final and a description exists only with
error; that an update replaces the name; that events and links are appended
while their counts leave room, dropped and counted once they do not, and
never exceed their limits; that adding a list of events or links is a fold
of single additions; that the exception event carries its two attributes;
and that the readers answer the fields set at construction.

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
  operations never fail at run time (spec #2, "Errors").
- A `Data` type with a parameter, such as `Api.Span<P>`, takes the parameter
  as the erased first argument of its operations: `Api.Span.name(Unit,
  span)`. A template argument such as the `~f` of `Maybe.show` must be a
  plain function: a definition with a `+` parameter is passed as a closed
  lambda, `~(data => show_counts(data))`, as the consumer does.
- On the native lane, Bend 2.0.34 keeps a value that a definition builds or
  destructures unboxed, one register per scalar field, and inlines every
  non-recursive definition into its caller. A span is about 150 registers,
  most of them the digits of its span context and its parent's; a segment
  may carry 247, and large segments can defeat clang. Today a pure
  definition that applies three or more operations to one span, a function
  that takes a span and two span contexts, or a loop that reads a reusable
  span twice does not compile natively, while the JavaScript lane has no
  such limit. The shapes that compile are those of the consumer: carry a
  span between steps inside a one-element list, which Bend keeps boxed,
  apply one operation per iteration of a recursive definition, read a span
  once per helper, and match `SpanData` once rather than calling several
  readers on a copy. The limit and its options are tracked in
  [#60](https://github.com/LucasGois1/bend-telemetry/issues/60).
- Numbers have no hexadecimal literals, and a `Nat` literal stops at
  `4294967295n`: build a larger `Nat` with `Nat.mul` and `Nat.add`, as the
  consumer builds a count of milliseconds.
