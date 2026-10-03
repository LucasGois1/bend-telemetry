# bend-telemetry-api: the OpenTelemetry tracing API for Bend. Source: https://github.com/LucasGois1/bend-telemetry
import Base
import bend-trace-context@0.2.0.0/trace_context.bend as TC

# The tracing API package
# =======================
#
# The OpenTelemetry tracing API for Bend: the package that instrumented code
# depends on. Its contract is the specification in
# https://github.com/LucasGois1/bend-telemetry/issues/2. This file is the
# package's entry module: it holds the public types and operations, a section
# per ticket of the specification, and the glossary of CONTEXT.md names them.
# It imports no foreign code, so that every library that depends on it stays
# provable.
#
# W3C Trace Context comes from bend-trace-context, imported by its BendHub
# name and version, never by a relative path (#1).

# The package's BendHub name.
def Package.name() -> String:
  "bend-telemetry-api"

# The names of the context fields that the W3C Trace Context propagator
# writes, in injection order: traceparent, then tracestate.
def TraceContext.fields() -> List<&2, String>:
  TC.Context.field_names()

# Span context (#5)
# =================
#
# The identity of a span: a remote span context, received from another
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
type SpanContext is Data:
  RemoteSpanContext{incoming: TC.IncomingContext}
  LocalSpanContext{outgoing: TC.OutgoingContext}

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

# Context (#5)
# ============
#
# The value that code passes explicitly to carry the current span context,
# and later baggage and propagation extras (#26), across calls and into
# forked computations. Every operation that needs a parent takes one; there
# is no attach, detach or current context, and nothing is attached to a
# thread or a computation. It is `Data`: instrumentation marks it reusable
# and copies it into forked computations.
#
# The record is closed: callers build it with Context.empty and read and
# change it through the operations below, never by constructing or matching
# it, so that a field added later breaks no caller.
type Context is Data:
  Context{span_context: Maybe<&2, SpanContext>}

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
