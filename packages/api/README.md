# bend-telemetry-api

The OpenTelemetry tracing API for Bend: the package that instrumented code
depends on. Its contract is the specification in
[#2](https://github.com/LucasGois1/bend-telemetry/issues/2), and its terms
are those of the glossary, [CONTEXT.md](../../CONTEXT.md). The package
imports no foreign code, so every library that depends on it stays provable;
its rules are laws in [LAWS.bend](LAWS.bend), proved in
[PROOF.bend](PROOF.bend). This is a community project; it is not part of, or
endorsed by, the OpenTelemetry project.

A program imports the package by its BendHub name and version, never by a
relative path, and bend-trace-context beside it for the W3C Trace Context
values that a span context wraps:

```bend
import Base
import bend-telemetry-api@0.1.0.0/api.bend as Api
import bend-trace-context@0.2.0.0/trace_context.bend as TC
```

The independent consumer, [tests/consumer/main.bend](../../tests/consumer/main.bend),
exercises everything below against a clean checkout; its output is
[expected.txt](../../tests/consumer/expected.txt).

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
