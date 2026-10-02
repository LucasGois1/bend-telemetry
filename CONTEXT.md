# OpenTelemetry for Bend

The vocabulary of this OpenTelemetry tracing implementation for Bend. W3C
Trace Context terms, such as remote context, local context and tracestate,
are those of bend-trace-context's glossary.

## Language

**Signal**:
A kind of telemetry that OpenTelemetry defines: traces, metrics or logs. This project supports traces.
_Avoid_: Data type

**API package**:
The package that instrumented code depends on. It defines how code creates spans and propagates context, and it works alone through its no-op implementation.
_Avoid_: Client library

**No-op implementation**:
What the API does when no SDK is installed: its operations return valid values that record nothing, and a received context still travels on.
_Avoid_: Mock, stub

**SDK package**:
The package that an application installs to record spans: the API's implementation, with sampling, processing and export.
_Avoid_: Agent

**Span context**:
The identity of a span: a remote context received from another participant, or a local context of this participant, each with its tracestate. A span started without an SDK and without a parent has none; there is no all-zero identity.
_Avoid_: Trace context, for a span's identity; invalid span context

**Context**:
The value that code passes explicitly to carry the current span context, and later baggage, across calls and into forked computations. Every operation that needs a parent takes one; nothing is attached to a thread or a computation.
_Avoid_: Trace context; current context, active span (there is no implicit one)

**Recording span**:
A span that an SDK records: its attributes, events, links and status reach the span processors when it ends.

**Non-recording span**:
A span whose operations accept everything and keep nothing. The API alone starts only non-recording spans, and so does an SDK whose sampler drops the span or whose identifier generation failed; it carries its parent's span context so that propagation continues.
_Avoid_: Dropped span, for a span that was never ended

**Attribute**:
A key with a value attached to a span, an event, a link, a resource or an instrumentation scope. Keys are unique within their owner: setting a key again replaces its value.
_Avoid_: Tag, label

**Attribute value**:
Any value that OTLP can carry: a string, a Boolean, a 64-bit integer, a double, bytes, an array, a map, or empty. The standard values of the specification are the primitive ones and homogeneous arrays of them; backends reliably accept those.
_Avoid_: AnyValue, in prose

**Timestamp**:
An instant as nanoseconds since the Unix epoch, with at least millisecond precision. Span start, span end and events carry one.
_Avoid_: Time, tick

**Tracer provider**:
The value an application configures once and passes to instrumentation, from which a tracer for each instrumentation scope is derived. The API's no-op provider records nothing.
_Avoid_: Global tracer, singleton

**Tracer**:
The value that starts spans for one instrumentation scope. Instrumentation derives its own from the provider it receives.
_Avoid_: Span factory, logger

**Instrumentation scope**:
The name, version, schema URL and attributes that identify the instrumentation that created a span, such as the HTTP instrumentation package.
_Avoid_: Library name, tracer name

**SDK slot**:
The template parameters through which the API's span start and span end reach the installed SDK, or the no-op. An application fills them once; instrumentation passes them through unchanged.
_Avoid_: Callback, hook, plugin

**Propagator**:
The codec that reads a context from a message's fields and writes it into another's: W3C Trace Context, W3C Baggage, B3 in its single or multi-header form, or a composite that applies several in order. Instrumentation takes it from the tracer provider.
_Avoid_: Injector, extractor, as separate things

**Baggage**:
Name-value pairs, each with optional opaque metadata, that travel with a context across services under the `baggage` field. One value per name; names and values are case sensitive.
_Avoid_: Tags, correlation context

**Propagation extras**:
Small facts a propagator must carry across a process that have no place in a span context, such as B3's debug flag. Only the propagator that wrote them reads them.
_Avoid_: Flags, for these

**Route**:
The low-cardinality pattern a server matched a request's path against, such as `/users/:id`. It names a server span together with the method; a path never does.
_Avoid_: Path, endpoint, for the span name

**Span owner**:
The computation that holds a span's value. Only the owner records into it and ends it; a forked computation starts spans of its own and hands events back as data.
_Avoid_: Shared span

**Event**:
A named, timestamped record with attributes on a span. A recorded exception is an event.

**Link**:
A reference from a span to another span context, with attributes, for causal relations that are not parent and child.

**Status**:
The outcome of a span: unset, ok, or error with a description. Ok is final, and a description is kept only with error.

**Span limits**:
The most attributes, events and links a span keeps, and the longest attribute value. Each operation enforces them as it runs and counts what it drops.
_Avoid_: Quota

**Span processor**:
The component that receives a recording span when it ends and hands it to an exporter: at once (simple processor) or in batches from a bounded queue (batch processor). A span that finds the queue full is dropped and counted, never waited for.
_Avoid_: Pipeline stage, middleware

**Sampler**:
The component that decides, when a span starts, whether it is recorded and whether its trace is marked sampled, from the parent span context, the trace ID, the name, the kind, the attributes and the links.
_Avoid_: Filter

**Sampling decision**:
The outcome of a sampler: drop, record only, or record and sample. Only sampled spans reach an exporter.
_Avoid_: Sampling flag, for the decision

**Resource**:
The immutable description of the entity that produces the telemetry, such as the service name and the SDK's own identity, attached to every span of a tracer provider.
_Avoid_: Tags, environment

**Resource detector**:
Code that reads part of the resource from where the process runs: its environment variables, its arguments, its container.
_Avoid_: Probe

**Sampling threshold**:
The 56-bit value, written as up to 14 lowercase hex digits without trailing zeros under the `th` key of the `ot` tracestate entry, below which a trace's randomness value means the span is dropped. It encodes the sampling probability a participant applied.
_Avoid_: Sampling rate, for the threshold itself

**Randomness value**:
The 56 random bits a sampler compares with the threshold: the rightmost 14 hex digits of a random trace ID, or the explicit `rv` value of the `ot` entry, which no participant alters.
_Avoid_: Seed

**Shutdown**:
The one-time end of a tracer provider: pending spans are exported, exporters are closed and the provider's computations stop, within a timeout. A program that never shuts its provider down does not end cleanly.
_Avoid_: Dispose, stop

**Force flush**:
A request that a provider export everything pending within a timeout, without ending it.
_Avoid_: Sync

**Lane**:
A target of the Bend compiler on which a program runs: the native C build, or the JavaScript lane, which is the Bun embedded in the pinned compiler. Node runs only programs with no effect that waits; browsers run only pure definitions.
_Avoid_: Platform, runtime, for the compiler target

**Graceful shutdown**:
Ending a process on SIGTERM or SIGINT by exporting the pending spans within a deadline and then exiting, instead of dying with them in the queue. Native only; draining a server's requests is the server's own concern.
_Avoid_: Clean exit, for a kill without a flush

**Ready composition**:
The SDK's span start and span end definitions assembled from default components (host identifier source, clock, reporter), plus a provider constructor that binds an exporter, so that an application fills the SDK slots and builds its provider without composing anything itself. The SDK ships the constructor for its built-in exporters; the OTLP exporter package ships one for its exporter.
_Avoid_: Preset, bundle

**Diagnostic**:
A message the SDK emits about its own operation, such as an invalid setting or a dropped span, on an internal logger that never fails the application.
_Avoid_: Error, exception, for the SDK's own reports

**Exporter**:
The component that sends finished spans to a destination, such as an OTLP endpoint, standard output or memory.
_Avoid_: Collector

**Export**:
One delivery of a batch of finished spans to a destination. It succeeds, succeeds partially, or fails; a failed batch is dropped and never sent again.
_Avoid_: Flush, for a single delivery

**Partial success**:
A destination's successful answer that rejected part of the batch and says how many spans and why. The batch is not sent again; the rejection is reported.

**Retryable response**:
A destination's answer that asks for the same batch again later: too many requests, a bad gateway, an unavailable service, a gateway timeout, a dropped connection or no answer at all. Every other failure drops the batch.
_Avoid_: Soft failure

**Export budget**:
The most time one export may take, retries and waits included. The processor's own export timeout is the outer limit around it.
_Avoid_: Deadline, for the per-step timeouts of the transport

**Instrumentation**:
Code that creates spans and propagates context for a library or protocol on an application's behalf, such as HTTP.
_Avoid_: Plugin

**Semantic conventions**:
The standard names and meanings of telemetry attributes, such as those that describe an HTTP request.
_Avoid_: Tags
