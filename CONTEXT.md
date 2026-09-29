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
The identity of a span: a remote context received from another participant, or a local context of this participant, each with its tracestate.
_Avoid_: Trace context, for a span's identity

**Exporter**:
The component that sends finished spans to a destination, such as an OTLP endpoint, standard output or memory.
_Avoid_: Collector

**Instrumentation**:
Code that creates spans and propagates context for a library or protocol on an application's behalf, such as HTTP.
_Avoid_: Plugin

**Semantic conventions**:
The standard names and meanings of telemetry attributes, such as those that describe an HTTP request.
_Avoid_: Tags
