import Base
import bend-telemetry-api@0.1.0.0/api.bend as Api
import bend-trace-context@0.2.0.0/trace_context.bend as TC

# The independent consumer: an application that depends on the published
# package by its BendHub name and version, as every adopter will. This file
# belongs to the application, not to the package; scripts/test-consumer.sh
# runs it against a clean clone served by the local hub and compares its
# output with expected.txt.
#
# Span contexts (#5): a local one from literal identifiers through
# bend-trace-context's pure constructors, a remote one extracted from a
# carrier with the W3C examples of traceparent and tracestate, and a child of
# the remote one built from its value readers. Each prints every reader. Then
# a context carries a span context, is copied, replaced, read and cleared.

# The W3C example identifiers, parsed as bend-trace-context values.
def trace_id() -> Result<&2, &2, TC.Error, TC.TraceId>:
  TC.TraceId.parse("0af7651916cd43dd8448eb211c80319c")

def span_id() -> Result<&2, &2, TC.Error, TC.SpanId>:
  TC.SpanId.parse("b7ad6b7169203331")

# A received message: the W3C examples of a traceparent and a tracestate.
def carrier() -> List<&2, TC.Header>:
  [TC.Header{"traceparent", "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"},
    TC.Header{"tracestate", "congo=t61rcWkgMzE,rojo=00f067aa0ba902b7"}]

# A local span context of an operation with the parsed identifiers, not
# sampled, with no tracestate.
def local(parsed_trace: Result<&2, &2, TC.Error, TC.TraceId>,
  parsed_span: Result<&2, &2, TC.Error, TC.SpanId>) -> Maybe<&2, Api.SpanContext>:
  match parsed_trace parsed_span:
    case Done{trace} Done{span}:
      Some{Api.SpanContext.local(TC.OutgoingContext.new(TC.Context.from_ids(trace, span, False{})))}
    case _ _:
      None{}

# The remote span context of the received message, when its traceparent was
# accepted.
def remote(extracted: Maybe<&2, TC.IncomingContext>) -> Maybe<&2, Api.SpanContext>:
  match extracted:
    case Some{incoming}:
      Some{Api.SpanContext.remote(incoming)}
    case None{}:
      None{}

# A local span context that continues the parent's trace with the parsed span
# ID: the parent's trace ID, sampled indication and tracestate come from the
# value readers, as an SDK takes them.
def child(parent: Maybe<&2, Api.SpanContext>, parsed_span: Result<&2, &2, TC.Error, TC.SpanId>) ->
  Maybe<&2, Api.SpanContext>:
  match parent parsed_span:
    case Some{+found} Done{span}:
      Some{Api.SpanContext.local(TC.OutgoingContext.with_state(
        TC.Context.from_ids(Api.SpanContext.trace_id(found), span, Api.SpanContext.is_sampled(found)),
        Api.SpanContext.tracestate(found)))}
    case _ _:
      None{}

# The readers of a span context on one line; "none" for an absent one.
def describe(found: Maybe<&2, Api.SpanContext>) -> String:
  match found:
    case None{}:
      "none"
    case Some{+context}:
      "trace_id=" ++ Api.SpanContext.trace_id_hex(context) ++ " span_id=" ++ Api.SpanContext.span_id_hex(context) ++
        " sampled=" ++ Bool.show(Api.SpanContext.is_sampled(context)) ++ " tracestate=\"" ++
        TC.TraceState.format(Api.SpanContext.tracestate(context)) ++ "\" remote=" ++
        Bool.show(Api.SpanContext.is_remote(context))

# The decimal text of each byte, in order.
def shown(bytes: List<&2, U32>) -> List<&2, String>:
  match bytes:
    case Nil{}:
      Nil{}
    case Con{byte, rest}:
      Con{U32.show(byte), shown(rest)}

# The bytes of a span context's span ID, as the value reader hands it to
# bend-trace-context's byte form; "none" for an absent span context.
def span_id_bytes(found: Maybe<&2, Api.SpanContext>) -> String:
  match found:
    case None{}:
      "none"
    case Some{context}:
      String.join(shown(TC.SpanId.to_bytes(Api.SpanContext.span_id(context))), ",")

# A context that carries the span context, when there is one.
def carrying(found: Maybe<&2, Api.SpanContext>) -> Api.Context:
  match found:
    case Some{context}:
      Api.Context.set_span_context(Api.Context.empty(), context)
    case None{}:
      Api.Context.empty()

# The context with the span context set in place of the one it carried, when
# there is one to set.
def replacing(context: Api.Context, found: Maybe<&2, Api.SpanContext>) -> Api.Context:
  match found:
    case Some{span_context}:
      Api.Context.set_span_context(context, span_context)
    case None{}:
      context

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("package: " ++ Api.Package.name())
    IO.print("fields: " ++ String.join(Api.TraceContext.fields(), ", "))
    +local : Maybe<&2, Api.SpanContext> = local(trace_id(), span_id())
    +remote : Maybe<&2, Api.SpanContext> = remote(TC.Extraction.incoming(TC.Context.extract(TC.Limits.default(),
      carrier(), None{})))
    IO.print("local: " ++ describe(local))
    IO.print("remote: " ++ describe(remote))
    IO.print("remote span_id bytes: " ++ span_id_bytes(remote))
    IO.print("child: " ++ describe(child(remote, span_id())))
    # The context is Data: marked reusable, it is copied into each use below.
    +context : Api.Context = carrying(local)
    IO.print("context: " ++ describe(Api.Context.span_context(context)))
    IO.print("replaced: " ++ describe(Api.Context.span_context(replacing(context, remote))))
    IO.print("empty: " ++ describe(Api.Context.span_context(Api.Context.empty())))
    IO.print("cleared: " ++ describe(Api.Context.span_context(Api.Context.clear_span_context(context))))
