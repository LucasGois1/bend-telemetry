import Base
import bend-telemetry-api@0.1.0.0/api.bend as Api
import bend-telemetry-instrumentation-http@0.1.0.0/core.bend as HttpCore

# The independent consumer of the HTTP instrumentation's pure core (#34): an
# application that depends on the published packages by their BendHub names
# and versions and prints what the core derives from literal requests, as
# the server and client wrappers will hand them to it. This file belongs to
# the application, not to the packages; scripts/test-consumer.sh runs it
# against a clean clone served by the local hub and compares its output with
# http_core.expected.txt.
#
# It prints the known methods and the normalization of literal methods,
# under the defaults and under an override; span names with and without a
# route and for `_OTHER`; the status and `error.type` of server and client
# spans on literal codes and on a transport failure; `url.full` with
# credentials and sensitive query values redacted, under the default keys
# and under an override; a request target split and redacted; the request
# attributes of a server span behind a proxy writing `Forwarded`, behind one
# writing the `X-Forwarded-*` headers, and behind none with header and body
# capture on; the response attributes of a server span; the request and
# response attributes of a client span, a transport failure included; the
# header list of a bend-kit header map; body sizes; and the configuration
# from literal variables. The core is pure, so the program runs natively,
# in-process on the JavaScript lane and under node (tests/lanes/programs.txt).

# The text of a value this program builds: a string between quotes, an
# integer in decimal, an array of strings between brackets.
def show_strings(items: List<&2, Api.AttributeValue>) -> List<&2, String>:
  match items:
    case Nil{}:
      Nil{}
    case Con{Api.StringValue{text}, rest}:
      Con{"'" ++ text ++ "'", show_strings(rest)}
    case Con{other, rest}:
      Con{"?", show_strings(rest)}

def show_value(value: Api.AttributeValue) -> String:
  match value:
    case Api.StringValue{text}:
      "'" ++ text ++ "'"
    case Api.IntValue{integer}:
      Api.Int64.show(integer)
    case Api.ArrayValue{items}:
      "[" ++ String.join(show_strings(items), ", ") ++ "]"
    case other:
      "?"

# Each attribute as key=value.
def show_attributes(attributes: List<&2, Api.Attribute>) -> List<&2, String>:
  match attributes:
    case Nil{}:
      Nil{}
    case Con{Api.Attribute{key, value}, rest}:
      Con{key ++ "=" ++ show_value(value), show_attributes(rest)}

# A collection: its attributes in order.
def show_collection(attributes: Api.Attributes) -> String:
  String.join(show_attributes(Api.Attributes.to_list(attributes)), ", ")

# An optional text, as Maybe.show prints it.
def show_text(value: Maybe<&2, String>) -> String:
  Maybe.show(~&2, ~String, ~(text => text), value)

# A normalized method: its kind and its text.
def show_method(method: HttpCore.Method) -> String:
  match method:
    case HttpCore.KnownMethod{name}:
      "known " ++ name
    case HttpCore.OtherMethod{original}:
      "_OTHER from " ++ original

# A status of the API: unset, ok, or error with its description between
# quotes; the HTTP rules never answer ok.
def show_status(status: Api.Status) -> String:
  match status:
    case Api.Unset{}:
      "unset"
    case Api.Ok{}:
      "ok"
    case Api.Error{description}:
      "error '" ++ description ++ "'"

# Each header as name: value.
def show_headers(headers: List<&2, HttpCore.Header>) -> List<&2, String>:
  match headers:
    case Nil{}:
      Nil{}
    case Con{HttpCore.Header{name, value}, rest}:
      Con{name ++ ": " ++ value, show_headers(rest)}

# A server span's status and error type for a code, on one line.
def server_outcome(+code: U32) -> String:
  U32.show(code) ++ " " ++ show_status(HttpCore.Server.status(code)) ++ " " ++ show_text(HttpCore.Server.error_type(code))

# A client span's status and error type for how its call ended.
def client_outcome(label: String, +outcome: HttpCore.Outcome) -> String:
  label ++ " " ++ show_status(HttpCore.Client.status(outcome)) ++ " " ++ show_text(HttpCore.Client.error_type(outcome))

# A request through a proxy that writes `Forwarded` and the X-Forwarded
# headers both: the Forwarded parameters win.
def proxied_headers() -> List<&2, HttpCore.Header>:
  [HttpCore.Header{"Host", "internal:8080"},
   HttpCore.Header{"Forwarded", "for=192.0.2.60;proto=https;host=\"example.com:8443\""},
   HttpCore.Header{"X-Forwarded-For", "203.0.113.5, 198.51.100.7"},
   HttpCore.Header{"X-Forwarded-Proto", "http"},
   HttpCore.Header{"User-Agent", "curl/8.4.0"}]

# A request through a proxy that writes the X-Forwarded headers only, with
# the lowercase names bend-kit hands over.
def x_forwarded_headers() -> List<&2, HttpCore.Header>:
  [HttpCore.Header{"host", "internal:8080"}, HttpCore.Header{"x-forwarded-host", "example.com"},
   HttpCore.Header{"x-forwarded-proto", "HTTPS"}, HttpCore.Header{"x-forwarded-for", "203.0.113.5, 198.51.100.7"}]

# A request behind no proxy, with two Accept lines and a body.
def plain_headers() -> List<&2, HttpCore.Header>:
  [HttpCore.Header{"Host", "[2001:db8::1]:8080"}, HttpCore.Header{"User-Agent", "curl/8.4.0"},
   HttpCore.Header{"Accept", "text/html"}, HttpCore.Header{"accept", "application/json"},
   HttpCore.Header{"Content-Length", "12"}]

# The configuration that captures the Accept request header, the
# Content-Type response header and body sizes.
def capturing() -> HttpCore.Config:
  HttpCore.Config.with_body_sizes(HttpCore.Config.with_response_headers(
    HttpCore.Config.with_request_headers(HttpCore.Config.default(), ["Accept"]), ["Content-Type"]), True{})

# A header map as bend-kit-http builds one: one list of values per
# lowercase name.
def header_map() -> Map<&2, List<&2, String>>:
  Map.set(&2, List<&2, String>, Map.set(&2, List<&2, String>, Map.new(&2, List<&2, String>), "host", ["example.com"]),
    "accept", ["text/html", "application/json"])

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("package: " ++ HttpCore.Package.name())
    +known : List<&2, String> = HttpCore.Method.known_defaults()
    IO.print("known methods: " ++ String.join(known, ", "))
    IO.print("methods: " ++ show_method(HttpCore.Method.normalize(known, "GET"))
      ++ " | " ++ show_method(HttpCore.Method.normalize(known, "GeT"))
      ++ " | " ++ show_method(HttpCore.Method.normalize(known, "ACL"))
      ++ " | under ACL,PURGE: " ++ show_method(HttpCore.Method.normalize(["ACL", "PURGE"], "ACL"))
      ++ " | " ++ show_method(HttpCore.Method.normalize(["ACL", "PURGE"], "GET")))
    IO.print("span names: " ++ HttpCore.Span.name(HttpCore.KnownMethod{"GET"}, Some{"/users/:id"})
      ++ " | " ++ HttpCore.Span.name(HttpCore.KnownMethod{"GET"}, None{})
      ++ " | " ++ HttpCore.Span.name(HttpCore.OtherMethod{"GeT"}, Some{"/users/:id"})
      ++ " | " ++ HttpCore.Span.name(HttpCore.OtherMethod{"GeT"}, None{}))
    IO.print("server status: " ++ server_outcome(200) ++ " | " ++ server_outcome(404) ++ " | " ++ server_outcome(500)
      ++ " | " ++ server_outcome(503))
    IO.print("client status: " ++ client_outcome("200", HttpCore.Responded{200})
      ++ " | " ++ client_outcome("404", HttpCore.Responded{404})
      ++ " | " ++ client_outcome("500", HttpCore.Responded{500})
      ++ " | " ++ client_outcome("ErrDns", HttpCore.Failed{"ErrDns", "no such host"}))
    +keys : List<&2, String> = HttpCore.Config.sensitive_query_keys(HttpCore.Config.default())
    IO.print("url.full: " ++ HttpCore.Url.full(keys,
      "https://user:secret@example.com:8443/items?X-Amz-Signature=abc&sig=&sigma=1&sig&page=2#top"))
    IO.print("url.full plain: " ++ HttpCore.Url.full(keys, "http://example.com/?email=a@b.example&Signature=x"))
    IO.print("url.full override: " ++ HttpCore.Url.full(["token"], "https://example.com/?token=1&sig=2"))
    IO.print("target: " ++ String.join(show_attributes(HttpCore.Target.attributes(keys, HttpCore.Target.split("/users/42?sig=abc&x=1"))), ", ")
      ++ " | " ++ String.join(show_attributes(HttpCore.Target.attributes(keys, HttpCore.Target.split("/ping"))), ", "))
    IO.print("server proxied: " ++ show_collection(HttpCore.Server.request_attributes(HttpCore.Config.default(), "GET",
      "/users/42?sig=abc&x=1", proxied_headers(), Some{"/users/:id"}, 0)))
    IO.print("server x-forwarded: " ++ show_collection(HttpCore.Server.request_attributes(HttpCore.Config.default(), "get",
      "/search?q=bend", x_forwarded_headers(), None{}, 0)))
    IO.print("server plain, capturing: " ++ show_collection(HttpCore.Server.request_attributes(capturing(), "POST",
      "/ping", plain_headers(), None{}, 7)))
    IO.print("server response 503: " ++ show_collection(HttpCore.Server.response_attributes(HttpCore.Config.default(), 503,
      [HttpCore.Header{"Content-Type", "text/plain"}], 7)))
    IO.print("server response 200, capturing: " ++ show_collection(HttpCore.Server.response_attributes(capturing(), 200,
      [HttpCore.Header{"Content-Type", "text/plain"}], 7)))
    IO.print("client request: " ++ show_collection(HttpCore.Client.request_attributes(HttpCore.Config.default(), "get",
      "https://user:secret@api.example.com/v1/items?sig=abc&page=2", Nil{}, 0)))
    IO.print("client request, default port: " ++ show_collection(HttpCore.Client.request_attributes(capturing(), "GET",
      "http://[::1]/health", [HttpCore.Header{"Accept", "application/json"}], 0)))
    IO.print("client response 200: " ++ show_collection(HttpCore.Client.response_attributes(HttpCore.Config.default(),
      HttpCore.Responded{200}, Nil{}, 0)))
    IO.print("client response 404, capturing: " ++ show_collection(HttpCore.Client.response_attributes(capturing(),
      HttpCore.Responded{404}, [HttpCore.Header{"Content-Type", "text/html"}, HttpCore.Header{"Content-Length", "x"}], 9)))
    IO.print("client failure: " ++ show_collection(HttpCore.Client.response_attributes(capturing(),
      HttpCore.Failed{"ErrDns", "no such host"}, Nil{}, 0)))
    IO.print("from map: " ++ String.join(show_headers(HttpCore.Headers.from_map(header_map())), "; "))
    IO.print("body size: " ++ U32.show(HttpCore.Body.size([HttpCore.Header{"Content-Length", "12"}], 5))
      ++ " | " ++ U32.show(HttpCore.Body.size(Nil{}, 5)))
    IO.print("config: known " ++ String.join(HttpCore.Config.known_methods(HttpCore.Config.default()), ",")
      ++ "; keys " ++ String.join(keys, ",")
      ++ "; capture request " ++ String.join(HttpCore.Config.request_headers(capturing()), ",")
      ++ ", response " ++ String.join(HttpCore.Config.response_headers(capturing()), ",")
      ++ ", body sizes " ++ Bool.show(HttpCore.Config.body_sizes(capturing())))
    IO.print("from variables: " ++ String.join(HttpCore.Config.known_methods(HttpCore.Config.from_variables(
      [HttpCore.Variable{"OTEL_INSTRUMENTATION_HTTP_KNOWN_METHODS", " GET , POST ,"}])), ",")
      ++ " | " ++ String.join(HttpCore.Config.known_methods(HttpCore.Config.from_variables(
        [HttpCore.Variable{"OTEL_INSTRUMENTATION_HTTP_KNOWN_METHODS", ""}])), ","))
