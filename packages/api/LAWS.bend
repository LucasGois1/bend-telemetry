import Base
import ./api.bend as Api
import bend-trace-context@0.2.0.0/trace_context.bend as TC

# The laws of bend-telemetry-api
# ==============================
#
# Each `law` below is an open claim about the package's public operations.
# PROOF.bend proves each one with a `def Laws.<name>`; the proof gate is
#
#   ./bend packages/api/PROOF.bend --check-only
#
# which prints "ALL PROOFS CHECK" only when every law holds and nothing the
# proofs import relies on `@unsafe` or foreign code.
#
# A law holds for every combination of its `for` lines at once; `P & Q` says
# that both hold. The rules come from the tracing API specification (#2) and
# its tickets; a law names the one it enforces.

# Package
# -------

# The package answers its own BendHub name.
law name:
  {Api.Package.name() == "bend-telemetry-api" : String}

# The context fields are those of W3C Trace Context, in injection order.
law context_fields:
  {Api.TraceContext.fields() == ["traceparent", "tracestate"] : List<&2, String>}

# Span context (#5)
# -----------------

# The variant tells remote from local: a span context built from an incoming
# context is remote, wraps that incoming context and wraps no outgoing one.
law span_context_remote:
  for incoming: TC.IncomingContext
  {Api.SpanContext.is_remote(Api.SpanContext.remote(incoming)) == True{} : Bool} &
  {Api.SpanContext.incoming(Api.SpanContext.remote(incoming)) == Some{incoming} :
    Maybe<&2, TC.IncomingContext>} &
  {Api.SpanContext.outgoing(Api.SpanContext.remote(incoming)) == None{} :
    Maybe<&2, TC.OutgoingContext>}

# The variant tells local from remote: a span context built from an outgoing
# context is local, wraps that outgoing context and wraps no incoming one.
law span_context_local:
  for outgoing: TC.OutgoingContext
  {Api.SpanContext.is_remote(Api.SpanContext.local(outgoing)) == False{} : Bool} &
  {Api.SpanContext.outgoing(Api.SpanContext.local(outgoing)) == Some{outgoing} :
    Maybe<&2, TC.OutgoingContext>} &
  {Api.SpanContext.incoming(Api.SpanContext.local(outgoing)) == None{} :
    Maybe<&2, TC.IncomingContext>}

# Each reader of a remote span context agrees with the field of the wrapped
# incoming context: the sender's trace, operation and sampled indication, and
# the tracestate received with them.
law remote_readers:
  for incoming: TC.IncomingContext
  {Api.SpanContext.trace_id(Api.SpanContext.remote(incoming)) ==
    TC.RemoteContext.trace_id(TC.IncomingContext.context(incoming)) : TC.TraceId} &
  {Api.SpanContext.span_id(Api.SpanContext.remote(incoming)) ==
    TC.RemoteContext.span_id(TC.IncomingContext.context(incoming)) : TC.SpanId} &
  {Api.SpanContext.is_sampled(Api.SpanContext.remote(incoming)) ==
    TC.RemoteContext.is_sampled(TC.IncomingContext.context(incoming)) : Bool} &
  {Api.SpanContext.tracestate(Api.SpanContext.remote(incoming)) ==
    TC.IncomingContext.state(incoming) : TC.TraceState}

# Each reader of a local span context agrees with the field of the wrapped
# outgoing context: this participant's trace, operation and sampled
# indication, and the tracestate it sends.
law local_readers:
  for outgoing: TC.OutgoingContext
  {Api.SpanContext.trace_id(Api.SpanContext.local(outgoing)) ==
    TC.LocalContext.trace_id(TC.OutgoingContext.context(outgoing)) : TC.TraceId} &
  {Api.SpanContext.span_id(Api.SpanContext.local(outgoing)) ==
    TC.LocalContext.span_id(TC.OutgoingContext.context(outgoing)) : TC.SpanId} &
  {Api.SpanContext.is_sampled(Api.SpanContext.local(outgoing)) ==
    TC.LocalContext.is_sampled(TC.OutgoingContext.context(outgoing)) : Bool} &
  {Api.SpanContext.tracestate(Api.SpanContext.local(outgoing)) ==
    TC.OutgoingContext.state(outgoing) : TC.TraceState}

# The hexadecimal readers are the lowercase digits of the identifiers that
# the value readers answer, for either variant.
law hex_readers:
  for context: Api.SpanContext
  {Api.SpanContext.trace_id_hex(context) ==
    TC.TraceId.to_string(Api.SpanContext.trace_id(context)) : String} &
  {Api.SpanContext.span_id_hex(context) ==
    TC.SpanId.to_string(Api.SpanContext.span_id(context)) : String}

# Context (#5)
# ------------

# Reading a context after setting a span context answers that span context,
# whatever the context held before.
law context_set_then_read:
  for context: Api.Context
  for span_context: Api.SpanContext
  {Api.Context.span_context(Api.Context.set_span_context(context, span_context)) ==
    Some{span_context} : Maybe<&2, Api.SpanContext>}

# The empty context holds no span context.
law context_empty:
  {Api.Context.span_context(Api.Context.empty()) == None{} : Maybe<&2, Api.SpanContext>}

# A cleared context holds no span context, whatever it held before.
law context_cleared:
  for context: Api.Context
  {Api.Context.span_context(Api.Context.clear_span_context(context)) == None{} :
    Maybe<&2, Api.SpanContext>}
