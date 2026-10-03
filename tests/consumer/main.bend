import Base
import bend-telemetry-api@0.1.0.0/api.bend as Api
import bend-trace-context@0.2.0.0/trace_context.bend as TC
import bend-telemetry-semconv@0.1.0.0/semconv.bend as Semconv

# The independent consumer: an application that depends on the published
# packages by their BendHub names and versions, as every adopter will. This
# file belongs to the application, not to the packages;
# scripts/test-consumer.sh runs it against a clean clone served by the local
# hub and compares its output with expected.txt.
#
# It prints the pure values of the API (#4): literal 64-bit integers, doubles
# and bytes, attribute collections with span limits at work, and timestamps.
# Then span contexts (#5): a local one from literal identifiers through
# bend-trace-context's pure constructors, a remote one extracted from a
# carrier with the W3C examples of traceparent and tracestate, and a child of
# the remote one built from its value readers. Each prints every reader. Then
# a context carries a span context, is copied, replaced, read and cleared.
# Last, the semantic conventions (#33): attribute names, enumeration values
# and a deprecated name.

# The cells of a bytes value, in decimal.
def show_cells(cells: List<&2, U32>) -> List<&2, String>:
  match cells:
    case Nil{}:
      Nil{}
    case Con{cell, rest}:
      Con{U32.show(cell), show_cells(rest)}

# The text of the values this program builds: the primitives and arrays of
# them, each array's items between brackets, nested arrays included. A
# key-value list is not among them.
def show_items(items: List<&2, Api.AttributeValue>) -> String:
  match items:
    case Nil{}:
      ""
    case Con{Api.StringValue{text}, Nil{}}:
      "'" ++ text ++ "'"
    case Con{Api.StringValue{text}, Con{next, rest}}:
      "'" ++ text ++ "', " ++ show_items(Con{next, rest})
    case Con{Api.BoolValue{flag}, Nil{}}:
      Bool.show(flag)
    case Con{Api.BoolValue{flag}, Con{next, rest}}:
      Bool.show(flag) ++ ", " ++ show_items(Con{next, rest})
    case Con{Api.IntValue{integer}, Nil{}}:
      Api.Int64.show(integer)
    case Con{Api.IntValue{integer}, Con{next, rest}}:
      Api.Int64.show(integer) ++ ", " ++ show_items(Con{next, rest})
    case Con{Api.DoubleValue{double}, Nil{}}:
      Api.Double.show(double)
    case Con{Api.DoubleValue{double}, Con{next, rest}}:
      Api.Double.show(double) ++ ", " ++ show_items(Con{next, rest})
    case Con{Api.BytesValue{cells}, Nil{}}:
      "bytes[" ++ String.join(show_cells(cells), ", ") ++ "]"
    case Con{Api.BytesValue{cells}, Con{next, rest}}:
      "bytes[" ++ String.join(show_cells(cells), ", ") ++ "], " ++ show_items(Con{next, rest})
    case Con{Api.ArrayValue{inner}, Nil{}}:
      "[" ++ show_items(inner) ++ "]"
    case Con{Api.ArrayValue{inner}, Con{next, rest}}:
      "[" ++ show_items(inner) ++ "], " ++ show_items(Con{next, rest})
    case Con{other, Nil{}}:
      "?"
    case Con{other, Con{next, rest}}:
      "?, " ++ show_items(Con{next, rest})

# The text of one value.
def show_value(value: Api.AttributeValue) -> String:
  show_items([value])

# An optional value's text, or None.
def show_maybe_value(value: Maybe<&2, Api.AttributeValue>) -> String:
  match value:
    case None{}:
      "None"
    case Some{present}:
      show_value(present)

# Each attribute as key=value.
def show_attributes(attributes: List<&2, Api.Attribute>) -> List<&2, String>:
  match attributes:
    case Nil{}:
      Nil{}
    case Con{Api.Attribute{key, value}, rest}:
      Con{key ++ "=" ++ show_value(value), show_attributes(rest)}

# A collection: its attributes in order, then how many it dropped.
def show_collection(+attributes: Api.Attributes) -> String:
  String.join(show_attributes(Api.Attributes.to_list(attributes)), ", ")
    ++ "; dropped " ++ Nat.show(Api.Attributes.dropped(attributes))

# A timestamp as its seconds and nanoseconds.
def show_timestamp(+timestamp: Api.Timestamp) -> String:
  Nat.show(Api.Timestamp.seconds(timestamp)) ++ "s " ++ U32.show(Api.Timestamp.nanoseconds(timestamp)) ++ "ns"

# The name of a comparison.
def show_cmp(order: Cmp) -> String:
  match order:
    case LT{}:
      "LT"
    case EQ{}:
      "EQ"
    case GT{}:
      "GT"

# The attributes of a request, as instrumentation would set them: a string,
# an integer, an array of integers, a Boolean and a double.
def request_attributes() -> Api.Attributes:
  Api.Attributes.from_list([
    Api.Attribute{"http.request.method", Api.StringValue{"GET"}},
    Api.Attribute{"http.response.status_code", Api.IntValue{Api.Int64.from_u32(200)}},
    Api.Attribute{"retries", Api.AttributeValue.ints([Api.Int64.from_u32(1), Api.Int64.from_negated_nat(2n)])},
    Api.Attribute{"ok", Api.BoolValue{True{}}},
    Api.Attribute{"ratio", Api.DoubleValue{Api.Double.from_f32(0.5)}}])

# Limits of two attributes and three characters, as a span with such limits
# would enforce them.
def tight_limits() -> Api.AttributeLimits:
  Api.AttributeLimits{Some{2n}, Some{3n}}

# Three attributes set under the tight limits: the third is dropped.
def limited_attributes() -> Api.Attributes:
  Api.Attributes.set_all_within(tight_limits(), Api.Attributes.empty(), [
    Api.Attribute{"a", Api.StringValue{"hello"}},
    Api.Attribute{"b", Api.StringValue{"hi"}},
    Api.Attribute{"c", Api.StringValue{"x"}}])

# 1700000000500 milliseconds since the epoch, built within Nat's literals.
def milliseconds() -> Nat:
  Nat.add(Nat.mul(1700000000n, 1000n), 500n)

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
    IO.print("int64: " ++ String.join([
      Api.Int64.show(Api.Int64.from_limbs(2147483647, 4294967295)),
      Api.Int64.show(Api.Int64.from_limbs(2147483648, 0)),
      Api.Int64.show(Api.Int64.from_negated_nat(1n)),
      Api.Int64.show(Api.Int64.from_limbs(1, 0)),
      Api.Int64.show(Api.Int64.from_nat(Nat.mul(1700000000n, 1000n)))], " "))
    IO.print("int64 read: " ++ Maybe.show(~&2, ~Api.Int64, ~Api.Int64.show, Api.Int64.read("-70000"))
      ++ " " ++ Maybe.show(~&2, ~Api.Int64, ~Api.Int64.show, Api.Int64.read("9223372036854775808")))
    IO.print("double: " ++ Api.Double.show(Api.Double.from_f32(1.5))
      ++ " " ++ Maybe.show(~&2, ~Api.Double, ~Api.Double.show, Api.Double.read("0.1"))
      ++ " " ++ Maybe.show(~&2, ~Api.Double, ~Api.Double.show, Api.Double.read("abc")))
    IO.print("bytes: " ++ show_maybe_value(Api.AttributeValue.bytes([0, 127, 255]))
      ++ " " ++ show_maybe_value(Api.AttributeValue.bytes([256])))
    IO.print("strings: " ++ show_value(Api.AttributeValue.strings(["a", "b"]))
      ++ " nested: " ++ show_value(Api.ArrayValue{[Api.AttributeValue.strings(["c"]), Api.EmptyValue{}]}))
    IO.print("attributes: " ++ show_collection(request_attributes()))
    IO.print("get: " ++ show_maybe_value(Api.Attributes.get(request_attributes(), "retries"))
      ++ " " ++ show_maybe_value(Api.Attributes.get(request_attributes(), "missing")))
    IO.print("replaced: " ++ show_collection(
      Api.Attributes.set(request_attributes(), "http.request.method", Api.StringValue{"POST"})))
    IO.print("limited: " ++ show_collection(limited_attributes()))
    IO.print("replaced under limits: " ++ show_collection(
      Api.Attributes.set_within(tight_limits(), limited_attributes(), "a", Api.StringValue{"world"})))
    IO.print("array under limits: " ++ show_collection(
      Api.Attributes.set_within(tight_limits(), Api.Attributes.empty(), "tags", Api.AttributeValue.strings(["alpha", "be"]))))
    IO.print("default limits: " ++ Maybe.show(~&2, ~Nat, ~Nat.show, Api.SpanLimits.attribute_count(Api.SpanLimits.default()))
      ++ " attributes, length " ++ Maybe.show(~&2, ~Nat, ~Nat.show, Api.SpanLimits.attribute_value_length(Api.SpanLimits.default()))
      ++ ", per event " ++ Maybe.show(~&2, ~Nat, ~Nat.show, Api.SpanLimits.attribute_per_event_count(Api.SpanLimits.default())))
    IO.print("timestamps: " ++ show_timestamp(Api.Timestamp.from_unix(1700000000n, 500000000))
      ++ "; " ++ show_timestamp(Api.Timestamp.from_unix(1700000000n, 1500000000))
      ++ "; " ++ show_timestamp(Api.Timestamp.from_milliseconds(milliseconds()))
      ++ "; " ++ Nat.show(Api.Timestamp.milliseconds(Api.Timestamp.from_milliseconds(milliseconds()))) ++ "ms")
    IO.print("order: " ++ show_cmp(Api.Timestamp.cmp(Api.Timestamp.from_unix(1700000000n, 5), Api.Timestamp.from_unix(1700000000n, 6)))
      ++ " " ++ show_cmp(Api.Timestamp.cmp(Api.Timestamp.from_unix(1700000001n, 0), Api.Timestamp.from_unix(1700000000n, 999999999)))
      ++ " " ++ show_cmp(Api.Timestamp.cmp(Api.Timestamp.from_milliseconds(milliseconds()), Api.Timestamp.from_unix(1700000000n, 500000000))))
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
    IO.print("package: " ++ Semconv.Package.name())
    IO.print("schema: " ++ Semconv.Schema.url())
    IO.print(Semconv.Http.Request.method() ++ " = " ++ Semconv.Http.Request.Method.get())
    IO.print(Semconv.Http.Response.status_code())
    IO.print(Semconv.Url.full())
    IO.print(Semconv.Server.address())
    IO.print(Semconv.Error.type() ++ " = " ++ Semconv.Error.Type.other())
    IO.print(Semconv.Service.name())
    IO.print(Semconv.Telemetry.Sdk.language() ++ " = " ++ Semconv.Telemetry.Sdk.Language.bend())
    IO.print("deprecated: " ++ Semconv.Http.method())
