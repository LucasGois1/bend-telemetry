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
# carrier with the W3C examples of traceparent and tracestate, a child of the
# remote one built from its value readers, and a remote one built from parts
# (#10): the literal identifiers, the trace ID asserted random, a sampled
# indication and a parsed tracestate. Each prints every reader; one line
# prints the trace flags of all four, and one what forwarding through
# bend-trace-context answers for the extracted one and for the one built from
# parts. Then a context carries a span context, is copied, replaced, read and
# cleared. Then spans (#6): the start options, a recording span built from
# the literal identifiers with tight span limits, every pure operation applied
# to it with the limits at work, its link pointing at the span context built
# from parts, its data printed, and a non-recording span that accepts the
# same operations and keeps nothing. The payload type is Unit: the API
# never inspects the payload. Last, the semantic conventions (#33): attribute
# names, enumeration values and a deprecated name.

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

# The W3C example tracestate with its entries in the other order, parsed as a
# tracestate.
def tracestate() -> Result<&2, &2, TC.StateError, TC.TraceState>:
  TC.TraceState.parse(TC.Limits.default(), "rojo=00f067aa0ba902b7,congo=t61rcWkgMzE")

# A remote span context built from parts, as an SDK builds the span context
# of a link or of a propagator of another format: the parsed identifiers, the
# trace ID asserted random so that bit 1 of the flags is seen, the sampled
# indication and the parsed tracestate. It is held in a one-element list,
# empty when the parts did not parse, so that Bend's native backend keeps it
# boxed between the steps of main: a fourth span context held directly, about
# 50 registers, takes main past what the backend compiles (#60).
def parts(parsed_trace: Result<&2, &2, TC.Error, TC.TraceId>, parsed_span: Result<&2, &2, TC.Error, TC.SpanId>,
  parsed_state: Result<&2, &2, TC.StateError, TC.TraceState>) -> List<&2, Api.SpanContext>:
  match parsed_trace parsed_span parsed_state:
    case Done{trace} Done{span} Done{state}:
      [Api.SpanContext.remote_from_parts(TC.TraceId.assert_random(trace), span, True{}, state)]
    case _ _ _:
      Nil{}

# The span context a held list carries, if any.
def first(held: List<&2, Api.SpanContext>) -> Maybe<&2, Api.SpanContext>:
  match held:
    case Con{context, rest}:
      Some{context}
    case Nil{}:
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

# The trace flags of a span context as a number; "none" for an absent one.
def show_flags(found: Maybe<&2, Api.SpanContext>) -> String:
  match found:
    case None{}:
      "none"
    case Some{context}:
      U32.show(Api.SpanContext.trace_flags(context))

# What forwarding answered: how many fields the carrier written holds, or the
# name of the error.
def show_forward(result: Result<&2, &2, TC.ForwardError, List<&2, TC.Header>>) -> String:
  match result:
    case Done{carrier}:
      Nat.show(List.length(&2, TC.Header, carrier)) ++ " fields"
    case Fail{error}:
      TC.ForwardError.show(error)

# What forwarding the incoming context a span context wraps into an empty
# carrier answers; "nothing received" for a local span context, which wraps
# none.
def forwarded(found: Maybe<&2, TC.IncomingContext>) -> String:
  match found:
    case Some{incoming}:
      show_forward(TC.Context.forward(TC.Limits.default(), incoming, Nil{}))
    case None{}:
      "nothing received"

# What forwarding a span context answers; "none" for an absent one.
def forward_of(found: Maybe<&2, Api.SpanContext>) -> String:
  match found:
    case None{}:
      "none"
    case Some{context}:
      forwarded(Api.SpanContext.incoming(context))

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

# The instrumentation scope of this consumer, with a version, no schema URL
# and one attribute.
def scope() -> Api.InstrumentationScope:
  Api.InstrumentationScope{"bend-telemetry-consumer", Some{"0.1.0"}, None{},
    Api.Attributes.from_list([Api.Attribute{"tier", Api.StringValue{"test"}}])}

# Tight span limits, so that every limit is seen at work: two attributes of
# at most eight characters, four events of two attributes, one link of one
# attribute.
def limits() -> Api.SpanLimits:
  Api.SpanLimits{Some{2n}, Some{8n}, Some{4n}, Some{1n}, Some{2n}, Some{1n}}

# The span's start: a literal timestamp and a literal monotonic reading.
def start() -> Api.Timestamp:
  Api.Timestamp.from_unix(1700000000n, 0)

# A timestamp within the span, at the given nanoseconds after its start.
def during(nanoseconds: U32) -> Api.Timestamp:
  Api.Timestamp.from_unix(1700000000n, nanoseconds)

# Start options as instrumentation would build them: a client span with one
# initial attribute, a link, an explicit start timestamp and a root
# indication; links that need a span context come through `linked`.
def options(links: List<&2, Api.Link>) -> Api.SpanOptions:
  Api.SpanOptions.with_root(Api.SpanOptions.with_start_timestamp(Api.SpanOptions.with_links(
    Api.SpanOptions.with_attributes(Api.SpanOptions.with_kind(Api.SpanOptions.default(), Api.Client{}),
      [Api.Attribute{"peer.service", Api.StringValue{"users"}}]), links), start()), True{})

# A link to a span context, when there is one: the list is empty otherwise,
# so that the operations that take a list run either way.
def linked(found: Maybe<&2, Api.SpanContext>, attributes: List<&2, Api.Attribute>) -> List<&2, Api.Link>:
  match found:
    case Some{span_context}:
      [Api.Link.to(span_context, attributes)]
    case None{}:
      Nil{}

# The span with the first link of a list added; the span as it is when the
# list is empty.
def first_link(span: Api.Span<Unit>, links: List<&2, Api.Link>) -> Api.Span<Unit>:
  match links:
    case Con{link, rest}:
      Api.Span.add_link(Unit, span, link)
    case Nil{}:
      span

# The recording span of a server request, as an SDK's start slot builds it:
# its span context is the child of the remote one, its parent the remote one.
# When the identifiers did not parse, a non-recording span without a span
# context stands in, and the output says so.
def recording(span_context: Maybe<&2, Api.SpanContext>, parent: Maybe<&2, Api.SpanContext>) -> Api.Span<Unit>:
  match span_context:
    case Some{own}:
      Api.Span.recording(Unit, Unit{}, scope(), own, parent, "GET /users/{id}", Api.Server{}, start(), 10n, True{}, limits())
    case None{}:
      Api.Span.non_recording(Unit, None{})

# The name of a kind.
def show_kind(kind: Api.SpanKind) -> String:
  match kind:
    case Api.Internal{}:
      "Internal"
    case Api.Server{}:
      "Server"
    case Api.Client{}:
      "Client"
    case Api.Producer{}:
      "Producer"
    case Api.Consumer{}:
      "Consumer"

# A status, with its description when it is an error.
def show_status(status: Api.Status) -> String:
  match status:
    case Api.Unset{}:
      "Unset"
    case Api.Ok{}:
      "Ok"
    case Api.Error{description}:
      "Error(" ++ description ++ ")"

# When an event happened: an explicit timestamp, or an offset from the
# span's start reading.
def show_time(time: Api.EventTime) -> String:
  match time:
    case Api.AtTimestamp{timestamp}:
      show_timestamp(timestamp)
    case Api.AtOffset{milliseconds}:
      "+" ++ Nat.show(milliseconds) ++ "ms"

# A text as it is.
def same(text: String) -> String:
  text

# Start options: the kind, how many attributes and links, the start
# timestamp and the root indication.
def show_options(+options: Api.SpanOptions) -> String:
  "kind=" ++ show_kind(Api.SpanOptions.kind(options))
    ++ " attributes=" ++ Nat.show(List.length(&2, Api.Attribute, Api.SpanOptions.attributes(options)))
    ++ " links=" ++ Nat.show(List.length(&2, Api.Link, Api.SpanOptions.links(options)))
    ++ " start=" ++ Maybe.show(~&2, ~Api.Timestamp, ~(timestamp => show_timestamp(timestamp)), Api.SpanOptions.start_timestamp(options))
    ++ " root=" ++ Bool.show(Api.SpanOptions.is_root(options))

# The counts of span data on one line: the kind, the status and how many
# attributes, events and links it keeps. The record is matched once: a
# reader call on a reusable copy would duplicate the data, which Bend's
# native backend keeps unboxed in about 150 registers (#60).
def show_counts(data: Api.SpanData) -> String:
  match data:
    case Api.SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes, events,
        dropped_events, links, dropped_links, status, limits}:
      "kind=" ++ show_kind(kind) ++ " status=" ++ show_status(status)
        ++ " attributes=" ++ Nat.show(Api.Attributes.count(attributes))
        ++ " events=" ++ Nat.show(List.length(&2, Api.SpanEvent, events))
        ++ " links=" ++ Nat.show(List.length(&2, Api.Link, links))

# An instrumentation scope: every reader.
def show_scope(+scope: Api.InstrumentationScope) -> String:
  Api.InstrumentationScope.name(scope)
    ++ " version=" ++ Maybe.show(~&2, ~String, ~same, Api.InstrumentationScope.version(scope))
    ++ " schema_url=" ++ Maybe.show(~&2, ~String, ~same, Api.InstrumentationScope.schema_url(scope))
    ++ " attributes=" ++ show_collection(Api.InstrumentationScope.attributes(scope))

# Each event on its own line: its name, when it happened and its attributes.
def show_events(events: List<&2, Api.SpanEvent>) -> List<&2, String>:
  match events:
    case Nil{}:
      Nil{}
    case Con{+event, rest}:
      Con{"event: " ++ Api.SpanEvent.name(event) ++ " at " ++ show_time(Api.SpanEvent.time(event)) ++ ": "
        ++ show_collection(Api.SpanEvent.attributes(event)), show_events(rest)}

# Each link on its own line: the span context it points to and its
# attributes.
def show_links(links: List<&2, Api.Link>) -> List<&2, String>:
  match links:
    case Nil{}:
      Nil{}
    case Con{+link, rest}:
      Con{"link: " ++ describe(Some{Api.Link.span_context(link)}) ++ ": " ++ show_collection(Api.Link.attributes(link)),
        show_links(rest)}

# The limits a span enforces: each count and the value length.
def show_limits(+limits: Api.SpanLimits) -> String:
  "attributes " ++ Maybe.show(~&2, ~Nat, ~Nat.show, Api.SpanLimits.attribute_count(limits))
    ++ ", length " ++ Maybe.show(~&2, ~Nat, ~Nat.show, Api.SpanLimits.attribute_value_length(limits))
    ++ ", events " ++ Maybe.show(~&2, ~Nat, ~Nat.show, Api.SpanLimits.event_count(limits))
    ++ ", links " ++ Maybe.show(~&2, ~Nat, ~Nat.show, Api.SpanLimits.link_count(limits))
    ++ ", per event " ++ Maybe.show(~&2, ~Nat, ~Nat.show, Api.SpanLimits.attribute_per_event_count(limits))
    ++ ", per link " ++ Maybe.show(~&2, ~Nat, ~Nat.show, Api.SpanLimits.attribute_per_link_count(limits))

# The data of a span, one line per fact, as an exporter would read it by
# matching the constructor, whose fields are the readers' in that order; one
# line saying so when the span keeps none. The record is matched once: a
# reader call on a reusable copy would duplicate the data, which Bend's
# native backend keeps unboxed in about 150 registers (#60).
def show_data(found: Maybe<&2, Api.SpanData>) -> List<&2, String>:
  match found:
    case None{}:
      ["data: none"]
    case Some{Api.SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, attributes, events,
        dropped_events, links, dropped_links, status, limits}}:
      List.concat(&2, String, [
        ["parent: " ++ describe(parent),
          "scope: " ++ show_scope(scope),
          "start: " ++ show_timestamp(start_timestamp) ++ ", reading " ++ Nat.show(start_reading) ++ "ms, sampled " ++ Bool.show(sampled),
          "attributes: " ++ show_collection(attributes)],
        show_events(events),
        ["dropped events: " ++ Nat.show(dropped_events)],
        show_links(links),
        ["dropped links: " ++ Nat.show(dropped_links),
          "limits: " ++ show_limits(limits)]])

# The state of span data after an operation: the status, the name and how
# many attributes, events and links it keeps and dropped; "nothing kept" for
# a non-recording span. The record is matched once, as in show_data.
def show_state(found: Maybe<&2, Api.SpanData>) -> String:
  match found:
    case None{}:
      "nothing kept"
    case Some{Api.SpanData{scope, span_context, parent, name, kind, start_timestamp, start_reading, sampled, +attributes, events,
        dropped_events, links, dropped_links, status, limits}}:
      "status=" ++ show_status(status) ++ " name=" ++ name
        ++ " attributes=" ++ Nat.show(Api.Attributes.count(attributes))
        ++ " (" ++ Nat.show(Api.Attributes.dropped(attributes)) ++ " dropped)"
        ++ " events=" ++ Nat.show(List.length(&2, Api.SpanEvent, events)) ++ " (" ++ Nat.show(dropped_events) ++ " dropped)"
        ++ " links=" ++ Nat.show(List.length(&2, Api.Link, links)) ++ " (" ++ Nat.show(dropped_links) ++ " dropped)"

# A span travels in a one-element list between the steps of this program,
# so that Bend's native backend keeps it boxed: a span held directly is kept
# unboxed in about 150 registers, and using it twice doubles them past what
# clang compiles (#60). Each helper below takes the span out once and reads
# it with one reader of the API.

# The data of the held span, if it is recording.
def data_of(held: List<&2, Api.Span<Unit>>) -> Maybe<&2, Api.SpanData>:
  match held:
    case Con{span, rest}:
      Api.Span.data(Unit, span)
    case Nil{}:
      None{}

# Whether the held span is recording.
def held_recording(held: List<&2, Api.Span<Unit>>) -> String:
  match held:
    case Con{span, rest}:
      Bool.show(Api.Span.is_recording(Unit, span))
    case Nil{}:
      "none"

# The name of the held span.
def held_name(held: List<&2, Api.Span<Unit>>) -> String:
  match held:
    case Con{span, rest}:
      Maybe.show(~&2, ~String, ~same, Api.Span.name(Unit, span))
    case Nil{}:
      "none"

# The span context of the held span.
def held_context(held: List<&2, Api.Span<Unit>>) -> String:
  match held:
    case Con{span, rest}:
      describe(Api.Span.span_context(Unit, span))
    case Nil{}:
      "none"

# The readers of the held span on one line: whether it is recording, its
# name and the counts of its data.
def held_summary(+held: List<&2, Api.Span<Unit>>) -> String:
  "recording=" ++ held_recording(held) ++ " name=" ++ held_name(held)
    ++ " data=" ++ Maybe.show(~&2, ~Api.SpanData, ~(data => show_counts(data)), data_of(held))

# The start timestamp of span data, through its reader; "none" without data.
def start_of(found: Maybe<&2, Api.SpanData>) -> String:
  match found:
    case Some{data}:
      show_timestamp(Api.SpanData.start_timestamp(data))
    case None{}:
      "none"

# The start reading of span data, through its reader.
def reading_of(found: Maybe<&2, Api.SpanData>) -> String:
  match found:
    case Some{data}:
      Nat.show(Api.SpanData.start_reading(data)) ++ "ms"
    case None{}:
      "none"

# The sampled indication of span data, through its reader.
def sampled_of(found: Maybe<&2, Api.SpanData>) -> String:
  match found:
    case Some{data}:
      Bool.show(Api.SpanData.is_sampled(data))
    case None{}:
      "none"

# The state of the held span.
def held_state(held: List<&2, Api.Span<Unit>>) -> String:
  show_state(data_of(held))

# The data of the held span, one line per fact.
def held_data(held: List<&2, Api.Span<Unit>>) -> List<&2, String>:
  show_data(data_of(held))

# The held span with the status set.
def held_status(held: List<&2, Api.Span<Unit>>, status: Api.Status) -> List<&2, Api.Span<Unit>>:
  match held:
    case Con{span, rest}:
      [Api.Span.set_status(Unit, span, status)]
    case Nil{}:
      Nil{}

# One pure operation to apply to a span, with the arguments it takes. The
# consumer applies a list of steps one per iteration of `record`, so that
# each operation compiles as a segment of its own: Bend's native backend
# keeps a span unboxed in about 150 registers, and several operations in one
# definition exceed what clang compiles (#60), while a recursive definition
# is a segment of its own.
type Step is Data:
  SetAttribute{key: String, value: Api.AttributeValue}
  SetAttributes{attributes: List<&2, Api.Attribute>}
  AddLink{links: List<&2, Api.Link>}
  AddLinks{links: List<&2, Api.Link>}
  SetStatus{status: Api.Status}
  UpdateName{name: String}
  AddEventAt{name: String, attributes: List<&2, Api.Attribute>, timestamp: Api.Timestamp}
  RecordExceptionWith{type_name: String, message: String, attributes: List<&2, Api.Attribute>, timestamp: Api.Timestamp}
  RecordException{type_name: String, message: String, timestamp: Api.Timestamp}
  AddEvent{event: Api.SpanEvent}
  AddEvents{events: List<&2, Api.SpanEvent>}

# The operation a step names.
def step_name(step: Step) -> String:
  match step:
    case SetAttribute{key, value}:
      "set_attribute"
    case SetAttributes{attributes}:
      "set_attributes"
    case AddLink{links}:
      "add_link"
    case AddLinks{links}:
      "add_links"
    case SetStatus{status}:
      "set_status"
    case UpdateName{name}:
      "update_name"
    case AddEventAt{name, attributes, timestamp}:
      "add_event_at"
    case RecordExceptionWith{type_name, message, attributes, timestamp}:
      "record_exception_with"
    case RecordException{type_name, message, timestamp}:
      "record_exception"
    case AddEvent{event}:
      "add_event"
    case AddEvents{events}:
      "add_events"

# The span after one step, held: the operation the step names, applied with
# its arguments; AddLink adds the first link of its list. Each arm boxes its
# result, so that the arms meet on a boxed value (#60).
def apply(step: Step, span: Api.Span<Unit>) -> List<&2, Api.Span<Unit>>:
  match step:
    case SetAttribute{key, value}:
      [Api.Span.set_attribute(Unit, span, key, value)]
    case SetAttributes{attributes}:
      [Api.Span.set_attributes(Unit, span, attributes)]
    case AddLink{links}:
      [first_link(span, links)]
    case AddLinks{links}:
      [Api.Span.add_links(Unit, span, links)]
    case SetStatus{status}:
      [Api.Span.set_status(Unit, span, status)]
    case UpdateName{name}:
      [Api.Span.update_name(Unit, span, name)]
    case AddEventAt{name, attributes, timestamp}:
      [Api.Span.add_event_at(Unit, span, name, attributes, timestamp)]
    case RecordExceptionWith{type_name, message, attributes, timestamp}:
      [Api.Span.record_exception_with(Unit, span, type_name, message, attributes, timestamp)]
    case RecordException{type_name, message, timestamp}:
      [Api.Span.record_exception(Unit, span, type_name, message, timestamp)]
    case AddEvent{event}:
      [Api.Span.add_event(Unit, span, event)]
    case AddEvents{events}:
      [Api.Span.add_events(Unit, span, events)]

# The held span after one step.
def apply_held(step: Step, held: List<&2, Api.Span<Unit>>) -> List<&2, Api.Span<Unit>>:
  match held:
    case Con{span, rest}:
      apply(step, span)
    case Nil{}:
      Nil{}

# The steps applied in order to the held span, each followed by a line with
# the span's state; then, under the label, the state, the span context and
# the data of the result.
def record(+label: String, steps: List<&2, Step>, +held: List<&2, Api.Span<Unit>>) -> IO(Unit):
  match steps:
    case Nil{}:
      do IO<Unit>:
        IO.print(label ++ ": " ++ held_state(held))
        IO.print(label ++ " span context: " ++ held_context(held))
        IO.print(String.join(held_data(held), "\n"))
    case Con{+step, rest}:
      do IO<Unit>:
        +held : List<&2, Api.Span<Unit>> = apply_held(step, held)
        IO.print(step_name(step) ++ ": " ++ held_state(held))
        record(label, rest, held)

# Every pure operation, with the limits at work: the second attribute set
# replaces the first in place and the third is dropped; the link keeps one
# attribute, and the same link added again is dropped by the link count; ok
# is set and a later error is ignored; the name is updated; four events are
# kept, each with at most two attributes, and the two of the list are
# dropped. One link list serves both link steps: each link built in main
# holds a span context, about 50 registers that count toward its segment.
def steps(+links: List<&2, Api.Link>) -> List<&2, Step>:
  [SetAttribute{"http.request.method", Api.StringValue{"GET"}},
    SetAttributes{[
      Api.Attribute{"http.response.status_code", Api.IntValue{Api.Int64.from_u32(200)}},
      Api.Attribute{"http.request.method", Api.StringValue{"DELETE"}},
      Api.Attribute{"url.full", Api.StringValue{"https://example.com/users/42"}}]},
    AddLink{links},
    AddLinks{links},
    SetStatus{Api.Ok{}},
    SetStatus{Api.Error{"late"}},
    UpdateName{"GET /users/{id}/profile"},
    AddEventAt{"cache.miss", [
      Api.Attribute{"cache.key", Api.StringValue{"user:42"}},
      Api.Attribute{"cache.level", Api.IntValue{Api.Int64.from_u32(1)}},
      Api.Attribute{"cache.hit", Api.BoolValue{False{}}}], during(250000000)},
    RecordExceptionWith{"TimeoutError", "upstream timed out",
      [Api.Attribute{"exception.escaped", Api.BoolValue{True{}}}], during(900000000)},
    RecordException{"TimeoutError", "upstream timed out", during(950000000)},
    AddEvent{Api.SpanEvent.at_offset("retry", [Api.Attribute{"attempt", Api.IntValue{Api.Int64.from_u32(1)}}], 15n)},
    AddEvents{[Api.SpanEvent.at("done", Nil{}, Api.Timestamp.from_unix(1700000001n, 0)),
      Api.SpanEvent.at_offset("closed", Nil{}, 20n)]}]

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
    # The span context built from parts is held in a one-element list (#60).
    +parts : List<&2, Api.SpanContext> = parts(trace_id(), span_id(), tracestate())
    IO.print("parts: " ++ describe(first(parts)))
    IO.print("flags: local=" ++ show_flags(local) ++ " remote=" ++ show_flags(remote)
      ++ " child=" ++ show_flags(child(remote, span_id())) ++ " parts=" ++ show_flags(first(parts)))
    IO.print("forward: remote=" ++ forward_of(remote) ++ " parts=" ++ forward_of(first(parts)))
    # The context is Data: marked reusable, it is copied into each use below.
    +context : Api.Context = carrying(local)
    IO.print("context: " ++ describe(Api.Context.span_context(context)))
    IO.print("replaced: " ++ describe(Api.Context.span_context(replacing(context, remote))))
    IO.print("empty: " ++ describe(Api.Context.span_context(Api.Context.empty())))
    IO.print("cleared: " ++ describe(Api.Context.span_context(Api.Context.clear_span_context(context))))
    IO.print("options: " ++ show_options(Api.SpanOptions.default()))
    IO.print("options: " ++ show_options(options(linked(remote, Nil{}))))
    # Each span is held in a one-element list and read once per helper (#60).
    +started : List<&2, Api.Span<Unit>> = [recording(child(remote, span_id()), remote)]
    IO.print("started: " ++ held_summary(started))
    IO.print("started at: " ++ start_of(data_of(started)) ++ ", reading " ++ reading_of(data_of(started))
      ++ ", sampled " ++ sampled_of(data_of(started)))
    +failed : List<&2, Api.Span<Unit>> = held_status(started, Api.Error{"upstream timed out"})
    IO.print("failed: " ++ held_summary(failed))
    record("recorded", steps(linked(first(parts), [
      Api.Attribute{"peer.service", Api.StringValue{"queue-service"}},
      Api.Attribute{"messaging.system", Api.StringValue{"kafka"}}])), failed)
    record("non-recording", steps(linked(remote, Nil{})), [Api.Span.non_recording(Unit, remote)])
    +orphan : List<&2, Api.Span<Unit>> = [Api.Span.non_recording(Unit, None{})]
    IO.print("non-recording without parent: " ++ held_summary(orphan) ++ ", span context " ++ held_context(orphan))
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
