import Base
import ./core.bend as HttpCore
import bend-telemetry-api@0.1.0.0/api.bend as Api

# The laws of bend-telemetry-instrumentation-http
# ===============================================
#
# This file is the package's statement of claims about its pure core,
# core.bend. Each `law` below is a property the Bend checker must prove for
# every value it quantifies over, or, where it quantifies over nothing, a
# fact about literal values that the checker computes. PROOF.bend proves each
# law with a def of the same name (`law method_listed` is proved by
# `def Laws.method_listed`), and
#
#   ./bend packages/instrumentation-http/PROOF.bend --check-only
#
# prints "ALL PROOFS CHECK" only when every law in this file is proved and no
# definition PROOF.bend imports relies on `@unsafe` or foreign code: the
# laws import the pure core alone, never host.bend. scripts/validate.sh runs
# that gate against the local hub, which serves the API and the semconv
# package that the core imports by name. The project owner reviews and owns
# these statements; the proofs may change freely as long as the statements
# hold.
#
# Every law is documented with the same headings:
#
#   Claim        what the law says, in plain words.
#   Requirement  the rule it enforces: a section of the OpenTelemetry
#                semantic conventions for HTTP spans at v1.44.0 ("the
#                conventions" below: docs/http/http-spans.md and the
#                attribute registries http, url, server, client, user_agent
#                and error), a decision of the HTTP instrumentation
#                specification (issue #27, "spec #27") or of its ticket #34.
#   Why          what would go wrong for an adopter without it.
#   Reading      how the Bend statement expresses the claim, when the
#                notation is not obvious.
#   Proof        where the proof lives.
#
# How to read a law
# -----------------
#
#   law name:                  the claim is called `name`.
#     for x: T                 "for every x of type T". A law holds for every
#                              combination of its `for` lines at once.
#     for h: {a == b : T}      a hypothesis: the claim only covers the values
#                              for which a equals b, typically that a check
#                              holds (`{U32.is_ge(code, 500) == True{} : Bool}`).
#     {a == b : T}             the conclusion: a and b are the same value of
#                              type T.
#     P & Q                    both P and Q hold.
#
#   `+x` is a resource annotation: `+x` may be used several times. It never
#   changes what a law means. A law with no `for` line is a fact about the
#   literal values it names, proved by computation: a legitimate law, used
#   where the universal statement is beyond what the checker computes
#   (strings are compared character by character and numbers bit by bit, so
#   the rules on texts, status codes and ports are stated on literal cases).
#
# Values that appear in the statements:
#
#   Some{v}, None{}            a present and an absent optional value (Maybe).
#   True{}, False{}            Booleans. Checks such as U32.is_ge(a, b)
#                              ("a >= b") return a Bool.
#   200, 443                   32-bit words (U32): status codes, ports, sizes.
#   "text", [a, b], Nil{}      strings, lists and the empty list.
#   HttpCore.Name              a definition of the package, from core.bend;
#                              HttpCore.Header{n, v}, HttpCore.KnownMethod{m}
#                              and the other constructors build its values.
#   Api.Attribute{k, v}        an attribute of the API, with Api.StringValue{t}
#                              or Api.IntValue{Api.Int64.from_u32(n)}.
#   Api.Unset{}, Api.Error{d}  the API's span status: unset, or error with a
#                              description.
#
# Definitions made in this file with `def` (`among`, the header fixtures,
# `keys`, `capturing`) are independent specifications and fixtures used to
# state the laws. `among` is deliberately not taken from the package, so
# that the method laws compare the package with a second, simpler description
# of the rule; the fixtures are literal messages, as a request would carry
# them.
#
# Contents
# --------
#
#   1. Package            name
#   2. Headers            header_lookup, headers_from_map
#   3. Methods            known_methods_default ... method_attributes
#   4. Span names         span_name_route ... span_name_other
#   5. Status             server_status_low ... error_type_literal
#   6. url.full           url_full_credentials ... url_full_override
#   7. Targets            target_split, target_query_redacted
#   8. Server headers     server_scheme ... user_agent
#   9. Client URL         client_server_attributes
#  10. Header capture     capture_literal ... body_size_length
#  11. Configuration      config_default ... config_from_variables_literal
#  12. Spans              server_request_literal ... client_response_literal

# 1. Package
# ==========

# LAW name
#   Claim: the package answers its own BendHub name.
#   Proof: Laws.name, by computation.
law name:
  {HttpCore.Package.name() == "bend-telemetry-instrumentation-http" : String}

# 2. Headers
# ==========

# The headers of a request behind no proxy: a Host with a port, a user
# agent and two Accept lines, names in mixed case.
def plain_headers() -> List<&2, HttpCore.Header>:
  [HttpCore.Header{"Host", "example.com:8080"}, HttpCore.Header{"User-Agent", "curl/8.4.0"},
   HttpCore.Header{"Accept", "text/html"}, HttpCore.Header{"accept", "application/json"}]

# LAW header_lookup
#   Claim: a lookup compares names without regard to case: the first value
#     of a header is answered whatever the case of the name sought or
#     written, every value of a repeated header is answered in arrival order,
#     a header that is not there answers none and no header answers nothing.
#   Requirement: RFC 9110, section 5.1: field names are case-insensitive;
#     spec #27, "Facts": bend-kit lowercases header names on both sides, and
#     the core must read what any library hands it.
#   Why: a proxy writes `X-Forwarded-For` and bend-kit `x-forwarded-for`;
#     the derivation must read both.
#   Proof: Laws.header_lookup, by computation.
law header_lookup:
  {HttpCore.Headers.first(plain_headers(), "HOST") == Some{"example.com:8080"} : Maybe<&2, String>} &
  {HttpCore.Headers.first(plain_headers(), "Accept") == Some{"text/html"} : Maybe<&2, String>} &
  {HttpCore.Headers.values(plain_headers(), "ACCEPT") == ["text/html", "application/json"] : List<&2, String>} &
  {HttpCore.Headers.first(plain_headers(), "x-missing") == None{} : Maybe<&2, String>} &
  {HttpCore.Headers.values(Nil{}, "host") == Nil{} : List<&2, String>}

# A header map as bend-kit-http builds one: one list of values per lowercase
# name.
def header_map() -> Map<&2, List<&2, String>>:
  Map.set(&2, List<&2, String>, Map.set(&2, List<&2, String>, Map.new(&2, List<&2, String>), "host", ["example.com"]),
    "accept", ["text/html", "application/json"])

# LAW headers_from_map
#   Claim: the header list of a header map answers, for each name, the
#     values the map held for it, in their order.
#   Requirement: spec #27, "Facts": bend-kit-http's requests and responses
#     hold their headers as a map from lowercase names to lists of values;
#     ticket #34: the core takes a header map.
#   Why: the wrappers hand the core bend-kit's headers unchanged in meaning.
#   Proof: Laws.headers_from_map, by computation.
law headers_from_map:
  {HttpCore.Headers.values(HttpCore.Headers.from_map(header_map()), "accept") ==
    ["text/html", "application/json"] : List<&2, String>} &
  {HttpCore.Headers.first(HttpCore.Headers.from_map(header_map()), "host") == Some{"example.com"} : Maybe<&2, String>} &
  {HttpCore.Headers.first(HttpCore.Headers.from_map(header_map()), "x-missing") == None{} : Maybe<&2, String>}

# 3. Methods
# ==========
#
# The conventions, `http.request.method`: the method is known when it is
# exactly one of the known methods, `_OTHER` otherwise with the original kept,
# and the known set is a full override.

# LAW known_methods_default
#   Claim: the default known methods are the eight methods of RFC 9110,
#     PATCH and QUERY, in uppercase.
#   Requirement: the conventions, `http.request.method`: "this convention
#     defines 'known' methods as the ones listed in RFC9110, the PATCH method
#     defined in RFC5789 and the QUERY method".
#   Proof: Laws.known_methods_default, by computation.
law known_methods_default:
  {HttpCore.Method.known_defaults() ==
    ["CONNECT", "DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT", "TRACE", "QUERY"] : List<&2, String>}

# Whether `name` is among `names`: an ordinary search, comparing the name
# sought with each name of the list.
def among(+name: String, names: List<&2, String>) -> Bool:
  match names:
    case Nil{}:
      False{}
    case Con{other, rest}:
      Bool.or(String.eq(name, other), among(name, rest))

# LAW method_listed
#   Claim: a method that is among the known methods is known, with its own
#     name, whatever the known set.
#   Requirement: the conventions, `http.request.method`: "http.request.method
#     attribute value MUST match a known HTTP method name exactly".
#   Reading: the hypothesis `listed` says that the search finds the method.
#   Proof: Laws.method_listed, via proofs/methods.bend.
law method_listed:
  for +known: List<&2, String>
  for +method: String
  for listed: {among(method, known) == True{} : Bool}
  {HttpCore.Method.normalize(known, method) == HttpCore.KnownMethod{method} : HttpCore.Method}

# LAW method_unlisted
#   Claim: a method that is not among the known methods is `_OTHER`, with
#     the method as its original text, whatever the known set.
#   Requirement: the conventions, `http.request.method`: "If the HTTP
#     request method is not known to instrumentation, it MUST set the
#     http.request.method attribute to _OTHER"; "MUST also set
#     http.request.method_original to the original value".
#   Why: an unknown method would otherwise become a high-cardinality value
#     of a low-cardinality attribute.
#   Proof: Laws.method_unlisted, via proofs/methods.bend.
law method_unlisted:
  for +known: List<&2, String>
  for +method: String
  for unlisted: {among(method, known) == False{} : Bool}
  {HttpCore.Method.normalize(known, method) == HttpCore.OtherMethod{method} : HttpCore.Method}

# LAW method_literal
#   Claim: under the defaults, each of the ten methods is known; `GeT`,
#     `get` and `ACL` are `_OTHER`; and under the override `["ACL"]`, `ACL`
#     is known and `GET` is `_OTHER`.
#   Requirement: the conventions, `http.request.method`: "HTTP method names
#     are case-sensitive"; "this list MUST be a full override of the default
#     known methods, it is not a list of known methods in addition to the
#     defaults".
#   Proof: Laws.method_literal, by computation.
law method_literal:
  {HttpCore.Method.normalize(HttpCore.Method.known_defaults(), "GET") == HttpCore.KnownMethod{"GET"} : HttpCore.Method} &
  {HttpCore.Method.normalize(HttpCore.Method.known_defaults(), "QUERY") == HttpCore.KnownMethod{"QUERY"} : HttpCore.Method} &
  {HttpCore.Method.normalize(HttpCore.Method.known_defaults(), "PATCH") == HttpCore.KnownMethod{"PATCH"} : HttpCore.Method} &
  {HttpCore.Method.normalize(HttpCore.Method.known_defaults(), "GeT") == HttpCore.OtherMethod{"GeT"} : HttpCore.Method} &
  {HttpCore.Method.normalize(HttpCore.Method.known_defaults(), "get") == HttpCore.OtherMethod{"get"} : HttpCore.Method} &
  {HttpCore.Method.normalize(HttpCore.Method.known_defaults(), "ACL") == HttpCore.OtherMethod{"ACL"} : HttpCore.Method} &
  {HttpCore.Method.normalize(["ACL"], "ACL") == HttpCore.KnownMethod{"ACL"} : HttpCore.Method} &
  {HttpCore.Method.normalize(["ACL"], "GET") == HttpCore.OtherMethod{"GET"} : HttpCore.Method}

# LAW method_attributes
#   Claim: a known method gives `http.request.method` with its name and no
#     original; `_OTHER` gives `http.request.method` as `_OTHER` and
#     `http.request.method_original` with the original text.
#   Requirement: the conventions, HTTP server span and HTTP client span:
#     `http.request.method_original` is required "if and only if it's
#     different than http.request.method".
#   Proof: Laws.method_attributes, by computation.
law method_attributes:
  for +name: String
  for +original: String
  {HttpCore.Method.attributes(HttpCore.KnownMethod{name}) ==
    [Api.Attribute{"http.request.method", Api.StringValue{name}}] : List<&2, Api.Attribute>} &
  {HttpCore.Method.attributes(HttpCore.OtherMethod{original}) ==
    [Api.Attribute{"http.request.method", Api.StringValue{"_OTHER"}},
     Api.Attribute{"http.request.method_original", Api.StringValue{original}}] : List<&2, Api.Attribute>} &
  {HttpCore.Method.name(HttpCore.KnownMethod{name}) == name : String} &
  {HttpCore.Method.original(HttpCore.KnownMethod{name}) == None{} : Maybe<&2, String>} &
  {HttpCore.Method.name(HttpCore.OtherMethod{original}) == "_OTHER" : String} &
  {HttpCore.Method.original(HttpCore.OtherMethod{original}) == Some{original} : Maybe<&2, String>}

# 4. Span names
# =============

# LAW span_name_route
#   Claim: with a route, the span name is the method, a space and the route.
#   Requirement: the conventions, "Name": "HTTP span names SHOULD be
#     `{method} {target}` if there is a (low-cardinality) target available";
#     the target of a server span is `http.route`.
#   Why: dashboards group by span name; a route keeps the cardinality low.
#   Proof: Laws.span_name_route, by computation.
law span_name_route:
  for +method: String
  for +route: String
  {HttpCore.Span.name(HttpCore.KnownMethod{method}, Some{route}) == method ++ " " ++ route : String}

# LAW span_name_method
#   Claim: without a route, the span name is the method alone.
#   Requirement: the conventions, "Name": "If there is no (low-cardinality)
#     {target} available, HTTP span names SHOULD be `{method}`" and
#     "Instrumentation MUST NOT default to using URI path as a {target}".
#   Proof: Laws.span_name_method, by computation.
law span_name_method:
  for +method: String
  {HttpCore.Span.name(HttpCore.KnownMethod{method}, None{}) == method : String}

# LAW span_name_other
#   Claim: when the method is `_OTHER`, the span name says `HTTP`, with the
#     route when there is one.
#   Requirement: the conventions, "Name": "when {http.request.method} is set
#     to _OTHER, {method} MUST be HTTP".
#   Proof: Laws.span_name_other, by computation.
law span_name_other:
  for +original: String
  for +route: String
  {HttpCore.Span.name(HttpCore.OtherMethod{original}, None{}) == "HTTP" : String} &
  {HttpCore.Span.name(HttpCore.OtherMethod{original}, Some{route}) == "HTTP " ++ route : String}

# 5. Status
# =========
#
# The conventions, "Status": unset on 1xx to 3xx; for 4xx, unset on a server
# span and error on a client span; error on 5xx and on a transport failure;
# no description when the status code says the reason. The status is the
# API's Api.Status, and the HTTP rules never answer Api.Ok{}. `error.type` is
# the status code as text when the status is an error and never set on
# success.

# LAW server_status_low
#   Claim: a server span's status is unset for every response code below
#     500, 4xx included.
#   Requirement: the conventions, "Status": "For HTTP status codes in the
#     4xx range span status MUST be left unset in case of SpanKind.SERVER".
#   Why: a 404 is the client's mistake, not the server's failure; marking it
#     an error would make every probe of a missing resource an alert.
#   Reading: the hypothesis `low` says the code is below 500.
#   Proof: Laws.server_status_low, by rewriting the hypothesis into the
#     check.
law server_status_low:
  for +code: U32
  for low: {U32.is_ge(code, 500) == False{} : Bool}
  {HttpCore.Server.status(code) == Api.Unset{} : Api.Status}

# LAW server_status_error
#   Claim: a server span's status is an error with no description for every
#     response code from 500 on.
#   Requirement: the conventions, "Status": "For HTTP status codes in the
#     5xx range ... span status SHOULD be set to Error" and "Don't set the
#     span status description if the reason can be inferred from
#     http.response.status_code".
#   Proof: Laws.server_status_error, by rewriting the hypothesis into the
#     check.
law server_status_error:
  for +code: U32
  for high: {U32.is_ge(code, 500) == True{} : Bool}
  {HttpCore.Server.status(code) == Api.Error{""} : Api.Status}

# LAW client_status_low
#   Claim: a client span's status is unset for every response code below 400.
#   Requirement: the conventions, "Status": "Span Status MUST be left unset
#     if HTTP status code was in the 1xx, 2xx or 3xx ranges".
#   Proof: Laws.client_status_low, by rewriting the hypothesis into the
#     check.
law client_status_low:
  for +code: U32
  for low: {U32.is_ge(code, 400) == False{} : Bool}
  {HttpCore.Client.status(HttpCore.Responded{code}) == Api.Unset{} : Api.Status}

# LAW client_status_error
#   Claim: a client span's status is an error with no description for every
#     response code from 400 on.
#   Requirement: the conventions, "Status": "For HTTP status codes in the
#     4xx range span status ... SHOULD be set to Error in case of
#     SpanKind.CLIENT", and 5xx likewise.
#   Proof: Laws.client_status_error, by rewriting the hypothesis into the
#     check.
law client_status_error:
  for +code: U32
  for high: {U32.is_ge(code, 400) == True{} : Bool}
  {HttpCore.Client.status(HttpCore.Responded{code}) == Api.Error{""} : Api.Status}

# LAW client_status_failed
#   Claim: a client span whose call failed in transport has an error status
#     with the failure's description, whatever the failure.
#   Requirement: the conventions, "Status": "HTTP request may fail if an
#     error occurred preventing the client or server from sending/receiving
#     the request/response fully. When instrumentation detects such errors
#     it SHOULD set span status to Error".
#   Proof: Laws.client_status_failed, by computation.
law client_status_failed:
  for error_type: String
  for +description: String
  {HttpCore.Client.status(HttpCore.Failed{error_type, description}) == Api.Error{description} : Api.Status}

# LAW status_literal
#   Claim: the two tables on literal codes: a server span is unset on 100,
#     200, 301, 404 and 499 and an error on 500, 503 and 599; a client span
#     is unset on 100, 200, 301 and 399 and an error on 400, 404, 500 and
#     599.
#   Requirement: the conventions, "Status", as the four laws above.
#   Proof: Laws.status_literal, by computation.
law status_literal:
  {HttpCore.Server.status(100) == Api.Unset{} : Api.Status} &
  {HttpCore.Server.status(200) == Api.Unset{} : Api.Status} &
  {HttpCore.Server.status(301) == Api.Unset{} : Api.Status} &
  {HttpCore.Server.status(404) == Api.Unset{} : Api.Status} &
  {HttpCore.Server.status(499) == Api.Unset{} : Api.Status} &
  {HttpCore.Server.status(500) == Api.Error{""} : Api.Status} &
  {HttpCore.Server.status(503) == Api.Error{""} : Api.Status} &
  {HttpCore.Server.status(599) == Api.Error{""} : Api.Status} &
  {HttpCore.Client.status(HttpCore.Responded{100}) == Api.Unset{} : Api.Status} &
  {HttpCore.Client.status(HttpCore.Responded{200}) == Api.Unset{} : Api.Status} &
  {HttpCore.Client.status(HttpCore.Responded{301}) == Api.Unset{} : Api.Status} &
  {HttpCore.Client.status(HttpCore.Responded{399}) == Api.Unset{} : Api.Status} &
  {HttpCore.Client.status(HttpCore.Responded{400}) == Api.Error{""} : Api.Status} &
  {HttpCore.Client.status(HttpCore.Responded{404}) == Api.Error{""} : Api.Status} &
  {HttpCore.Client.status(HttpCore.Responded{500}) == Api.Error{""} : Api.Status} &
  {HttpCore.Client.status(HttpCore.Responded{599}) == Api.Error{""} : Api.Status}

# LAW server_error_type_low
#   Claim: a server span has no `error.type` for a response code below 500.
#   Requirement: the conventions, `error.type`: "If the request has
#     completed successfully, instrumentations SHOULD NOT set error.type";
#     a 4xx is not an error of a server span.
#   Proof: Laws.server_error_type_low, by rewriting the hypothesis into the
#     check.
law server_error_type_low:
  for +code: U32
  for low: {U32.is_ge(code, 500) == False{} : Bool}
  {HttpCore.Server.error_type(code) == None{} : Maybe<&2, String>}

# LAW server_error_type_error
#   Claim: a server span's `error.type` is the response code as text from
#     500 on.
#   Requirement: the conventions, `error.type`: "If response status code was
#     sent or received and status indicates an error according to HTTP span
#     status definition, error.type SHOULD be set to the status code number
#     (represented as a string)".
#   Why: `error.type` is the low-cardinality key that error-rate dashboards
#     group by.
#   Proof: Laws.server_error_type_error, by rewriting the hypothesis into
#     the check.
law server_error_type_error:
  for +code: U32
  for high: {U32.is_ge(code, 500) == True{} : Bool}
  {HttpCore.Server.error_type(code) == Some{U32.show(code)} : Maybe<&2, String>}

# LAW client_error_type_low
#   Claim: a client span has no `error.type` for a response code below 400.
#   Requirement: as server_error_type_low, for a client span.
#   Proof: Laws.client_error_type_low, by rewriting the hypothesis into the
#     check.
law client_error_type_low:
  for +code: U32
  for low: {U32.is_ge(code, 400) == False{} : Bool}
  {HttpCore.Client.error_type(HttpCore.Responded{code}) == None{} : Maybe<&2, String>}

# LAW client_error_type_error
#   Claim: a client span's `error.type` is the response code as text from
#     400 on.
#   Requirement: as server_error_type_error, for a client span.
#   Proof: Laws.client_error_type_error, by rewriting the hypothesis into
#     the check.
law client_error_type_error:
  for +code: U32
  for high: {U32.is_ge(code, 400) == True{} : Bool}
  {HttpCore.Client.error_type(HttpCore.Responded{code}) == Some{U32.show(code)} : Maybe<&2, String>}

# LAW client_error_type_failed
#   Claim: a client span whose call failed in transport has the failure's
#     identifier as its `error.type`, whatever the description.
#   Requirement: the conventions, `error.type`: "If the request fails with
#     an error before response status code was sent or received, error.type
#     SHOULD be set to exception type ... or a component-specific low
#     cardinality error identifier"; spec #27, "Client": the `Http.Err`
#     variant name.
#   Proof: Laws.client_error_type_failed, by computation.
law client_error_type_failed:
  for +error_type: String
  for description: String
  {HttpCore.Client.error_type(HttpCore.Failed{error_type, description}) == Some{error_type} : Maybe<&2, String>}

# LAW error_type_literal
#   Claim: `error.type` on literal cases: none for a server's 200 and 404 and
#     `500` for its 500; none for a client's 200, `404` and `500` for its
#     404 and 500, and `ErrDns` for a failed name lookup.
#   Requirement: the conventions, `error.type`, as the laws above; the
#     example "HTTP client call: Internal Server Error" (`error.type` `500`).
#   Proof: Laws.error_type_literal, by computation.
law error_type_literal:
  {HttpCore.Server.error_type(200) == None{} : Maybe<&2, String>} &
  {HttpCore.Server.error_type(404) == None{} : Maybe<&2, String>} &
  {HttpCore.Server.error_type(500) == Some{"500"} : Maybe<&2, String>} &
  {HttpCore.Client.error_type(HttpCore.Responded{200}) == None{} : Maybe<&2, String>} &
  {HttpCore.Client.error_type(HttpCore.Responded{404}) == Some{"404"} : Maybe<&2, String>} &
  {HttpCore.Client.error_type(HttpCore.Responded{500}) == Some{"500"} : Maybe<&2, String>} &
  {HttpCore.Client.error_type(HttpCore.Failed{"ErrDns", "no such host"}) == Some{"ErrDns"} : Maybe<&2, String>}

# 6. url.full
# ===========
#
# The conventions, `url.full`: no credentials, the sensitive query values
# redacted with the keys kept, the keys compared case-sensitively, the list a
# full override. The laws are literal, since the rules are on text.

# The sensitive query keys of the defaults.
def keys() -> List<&2, String>:
  HttpCore.Config.sensitive_query_keys(HttpCore.Config.default())

# LAW url_full_credentials
#   Claim: the userinfo of a URL, a user with or without a password, is
#     replaced by `REDACTED:REDACTED` before the host, whether or not a port,
#     a path or a query follows; a URL with no `@` in its authority is kept,
#     an `@` in the query included; a scheme-relative URL is redacted too.
#   Requirement: the conventions, `url.full`: "url.full MUST NOT contain
#     credentials passed via URL in form of https://username:password@www.example.com/.
#     In such case username and password SHOULD be redacted and attribute's
#     value SHOULD be https://REDACTED:REDACTED@www.example.com/"; spec #27,
#     "Client": userinfo is replaced before any parsing.
#   Why: a password in a URL would otherwise reach every backend that stores
#     the span.
#   Proof: Laws.url_full_credentials, by computation.
law url_full_credentials:
  {HttpCore.Url.full(keys(), "https://user:secret@example.com/path?x=1") ==
    "https://REDACTED:REDACTED@example.com/path?x=1" : String} &
  {HttpCore.Url.full(keys(), "https://user@example.com:8443/") == "https://REDACTED:REDACTED@example.com:8443/" : String} &
  {HttpCore.Url.full(keys(), "https://user:secret@example.com") == "https://REDACTED:REDACTED@example.com" : String} &
  {HttpCore.Url.full(keys(), "//user:secret@example.com/") == "//REDACTED:REDACTED@example.com/" : String} &
  {HttpCore.Url.full(keys(), "http://example.com/?email=a@b.example") == "http://example.com/?email=a@b.example" : String} &
  {HttpCore.Url.full(keys(), "https://example.com:8080/a/b?x=1&y=2#frag") == "https://example.com:8080/a/b?x=1&y=2#frag" : String}

# LAW url_full_sensitive_keys
#   Claim: the value of each sensitive query key is replaced by `REDACTED`
#     and the key kept: the five keys of the conventions at v1.44.0 and the
#     two of their earlier versions; several at once, among other parameters
#     and before a fragment, which is kept.
#   Requirement: the conventions, `url.full`: "Query string values for the
#     following keys SHOULD be redacted by default and replaced by the value
#     REDACTED: X-Amz-Signature, X-Amz-Credential, X-Amz-Security-Token, sig,
#     X-Goog-Signature"; "When a query string value is redacted, the query
#     string key SHOULD still be preserved"; ticket #34: `AWSAccessKeyId` and
#     `Signature` too.
#   Why: a presigned URL's signature grants access to the object it signs.
#   Proof: Laws.url_full_sensitive_keys, by computation.
law url_full_sensitive_keys:
  {HttpCore.Url.full(keys(), "https://example.com/?X-Amz-Signature=abc") == "https://example.com/?X-Amz-Signature=REDACTED" : String} &
  {HttpCore.Url.full(keys(), "https://example.com/?X-Amz-Credential=abc") == "https://example.com/?X-Amz-Credential=REDACTED" : String} &
  {HttpCore.Url.full(keys(), "https://example.com/?X-Amz-Security-Token=abc") ==
    "https://example.com/?X-Amz-Security-Token=REDACTED" : String} &
  {HttpCore.Url.full(keys(), "https://example.com/?AWSAccessKeyId=abc") == "https://example.com/?AWSAccessKeyId=REDACTED" : String} &
  {HttpCore.Url.full(keys(), "https://example.com/?Signature=abc") == "https://example.com/?Signature=REDACTED" : String} &
  {HttpCore.Url.full(keys(), "https://example.com/?sig=abc") == "https://example.com/?sig=REDACTED" : String} &
  {HttpCore.Url.full(keys(), "https://example.com/?X-Goog-Signature=abc") == "https://example.com/?X-Goog-Signature=REDACTED" : String} &
  {HttpCore.Url.full(keys(), "https://s3.example.com/f?X-Amz-Credential=AKIA%2F20240101&X-Amz-Signature=abc&x=1#top") ==
    "https://s3.example.com/f?X-Amz-Credential=REDACTED&X-Amz-Signature=REDACTED&x=1#top" : String}

# LAW url_full_key_without_value
#   Claim: a sensitive key with an empty value is redacted to `REDACTED`; a
#     sensitive key with no `=` has no value and is kept whole, alone or
#     among other parameters.
#   Requirement: the conventions, `url.full`: a value is redacted and the
#     key preserved; a parameter without a value carries nothing to redact.
#   Proof: Laws.url_full_key_without_value, by computation.
law url_full_key_without_value:
  {HttpCore.Url.full(keys(), "https://example.com/?sig=") == "https://example.com/?sig=REDACTED" : String} &
  {HttpCore.Url.full(keys(), "https://example.com/?sig") == "https://example.com/?sig" : String} &
  {HttpCore.Url.full(keys(), "https://example.com/?sig&x=1") == "https://example.com/?sig&x=1" : String}

# LAW url_full_prefix_key
#   Claim: keys compare whole and case-sensitively: a key that extends a
#     sensitive key (`sigma`, `Signature2`) is kept, and so is a sensitive
#     key in another case (`SIG`), while the exact key beside them is
#     redacted.
#   Requirement: the conventions, `url.full`: "Matching of query parameter
#     keys against the sensitive list SHOULD be case-sensitive".
#   Why: redacting by prefix would blank unrelated parameters and hide the
#     request from its operators.
#   Proof: Laws.url_full_prefix_key, by computation.
law url_full_prefix_key:
  {HttpCore.Url.full(keys(), "https://example.com/?sigma=1&sig=2&Signature2=3") ==
    "https://example.com/?sigma=1&sig=REDACTED&Signature2=3" : String} &
  {HttpCore.Url.full(keys(), "https://example.com/?SIG=1") == "https://example.com/?SIG=1" : String}

# LAW url_full_override
#   Claim: the sensitive keys are a full override: under the keys
#     `["token"]`, `token` is redacted and `sig` is kept.
#   Requirement: the conventions, `url.full`: "This list is a full override
#     of the default sensitive query parameter keys, it is not a list of keys
#     in addition to the defaults".
#   Proof: Laws.url_full_override, by computation.
law url_full_override:
  {HttpCore.Url.full(["token"], "https://example.com/?token=1&sig=2") == "https://example.com/?token=REDACTED&sig=2" : String} &
  {HttpCore.Config.sensitive_query_keys(HttpCore.Config.with_sensitive_query_keys(HttpCore.Config.default(), ["token"])) ==
    ["token"] : List<&2, String>}

# 7. Targets
# ==========

# LAW target_split
#   Claim: a request target splits at its first `?` into the path and the
#     query: a target without `?` has no query, one ending in `?` has an
#     empty one, and a second `?` belongs to the query.
#   Requirement: the conventions, HTTP server span: `url.path` is "the URI
#     path component" and `url.query` "the URI query component", required
#     "if and only if one was received"; RFC 3986, section 3.4: the query
#     begins at the first `?`.
#   Proof: Laws.target_split, by computation.
law target_split:
  {HttpCore.Target.split("/search?q=1") == HttpCore.Target{"/search", Some{"q=1"}} : HttpCore.Target} &
  {HttpCore.Target.split("/search") == HttpCore.Target{"/search", None{}} : HttpCore.Target} &
  {HttpCore.Target.split("/search?") == HttpCore.Target{"/search", Some{""}} : HttpCore.Target} &
  {HttpCore.Target.split("/a?b=1?c") == HttpCore.Target{"/a", Some{"b=1?c"}} : HttpCore.Target}

# LAW target_query_redacted
#   Claim: the target attributes are `url.path` and, when there is a query,
#     `url.query` with the sensitive values redacted as in `url.full`.
#   Requirement: the conventions, HTTP server span, `url.query`: "Sensitive
#     content provided in url.query SHOULD be scrubbed", with the same keys
#     and the same rule as `url.full`.
#   Proof: Laws.target_query_redacted, by computation.
law target_query_redacted:
  {HttpCore.Target.attributes(keys(), HttpCore.Target.split("/f?sig=abc&x=1")) ==
    [Api.Attribute{"url.path", Api.StringValue{"/f"}}, Api.Attribute{"url.query", Api.StringValue{"sig=REDACTED&x=1"}}] :
    List<&2, Api.Attribute>} &
  {HttpCore.Target.attributes(keys(), HttpCore.Target.split("/f")) ==
    [Api.Attribute{"url.path", Api.StringValue{"/f"}}] : List<&2, Api.Attribute>}

# 8. Server headers
# =================
#
# A server behind a proxy reads the original request from `Forwarded` and
# the `X-Forwarded-*` headers; without them, bend-kit's server speaks plain
# HTTP and exposes no peer address.

# The headers of a request through a proxy that writes `Forwarded` and the
# X-Forwarded headers both: the Forwarded parameters win.
def proxied_headers() -> List<&2, HttpCore.Header>:
  [HttpCore.Header{"Host", "internal:8080"},
   HttpCore.Header{"Forwarded", "for=192.0.2.60;proto=https;host=\"example.com:8443\""},
   HttpCore.Header{"X-Forwarded-For", "203.0.113.5, 198.51.100.7"},
   HttpCore.Header{"X-Forwarded-Proto", "http"},
   HttpCore.Header{"User-Agent", "curl/8.4.0"}]

# The headers of a request through a proxy that writes the X-Forwarded
# headers only, as bend-kit hands them: lowercase names.
def x_forwarded_headers() -> List<&2, HttpCore.Header>:
  [HttpCore.Header{"host", "internal:8080"}, HttpCore.Header{"x-forwarded-host", "example.com"},
   HttpCore.Header{"x-forwarded-proto", "HTTPS"}, HttpCore.Header{"x-forwarded-for", "203.0.113.5, 198.51.100.7"}]

# LAW server_scheme
#   Claim: `url.scheme` is the `proto` of Forwarded when there is one,
#     else X-Forwarded-Proto, lowercased, else `http`.
#   Requirement: the conventions, HTTP server span, `url.scheme`: "The scheme
#     of the original client request, if known (e.g. from Forwarded#proto,
#     X-Forwarded-Proto, or a similar header). Otherwise, the scheme of the
#     immediate peer request"; spec #27, "Facts": bend-kit's server is plain
#     HTTP.
#   Proof: Laws.server_scheme, by computation.
law server_scheme:
  {HttpCore.Server.scheme(proxied_headers()) == "https" : String} &
  {HttpCore.Server.scheme(x_forwarded_headers()) == "https" : String} &
  {HttpCore.Server.scheme(plain_headers()) == "http" : String} &
  {HttpCore.Server.scheme(Nil{}) == "http" : String}

# LAW server_address_port
#   Claim: `server.address` and `server.port` come from the `host` of
#     Forwarded, else X-Forwarded-Host, else Host, parsed into host and port:
#     a quoted host with a port, a host without a port (no `server.port`),
#     a Host with a port, a bracketed IPv6 address with a port (the brackets
#     dropped), and nothing without a host.
#   Requirement: the conventions, "Setting server.address and server.port
#     attributes": "The original host which may be passed by the reverse
#     proxy in the Forwarded#host, X-Forwarded-Host, or a similar header ...
#     The Host header"; "Instrumentations SHOULD populate both server.address
#     and server.port attributes by parsing the value of corresponding
#     header"; the conventions, "Address and port attributes": the address is
#     the IP-level address.
#   Proof: Laws.server_address_port, by computation.
law server_address_port:
  {HttpCore.Server.address_attributes(proxied_headers()) ==
    [Api.Attribute{"server.address", Api.StringValue{"example.com"}},
     Api.Attribute{"server.port", Api.IntValue{Api.Int64.from_u32(8443)}}] : List<&2, Api.Attribute>} &
  {HttpCore.Server.address_attributes(x_forwarded_headers()) ==
    [Api.Attribute{"server.address", Api.StringValue{"example.com"}}] : List<&2, Api.Attribute>} &
  {HttpCore.Server.address_attributes(plain_headers()) ==
    [Api.Attribute{"server.address", Api.StringValue{"example.com"}},
     Api.Attribute{"server.port", Api.IntValue{Api.Int64.from_u32(8080)}}] : List<&2, Api.Attribute>} &
  {HttpCore.Server.address_attributes([HttpCore.Header{"Host", "[2001:db8::1]:8080"}]) ==
    [Api.Attribute{"server.address", Api.StringValue{"2001:db8::1"}},
     Api.Attribute{"server.port", Api.IntValue{Api.Int64.from_u32(8080)}}] : List<&2, Api.Attribute>} &
  {HttpCore.Server.address_attributes(Nil{}) == Nil{} : List<&2, Api.Attribute>}

# LAW client_address
#   Claim: `client.address` is the `for` of Forwarded when there is one,
#     else the first address of X-Forwarded-For, without quotes, brackets or
#     port; absent without them.
#   Requirement: the conventions, HTTP server span, `client.address`: "The IP
#     address of the original client behind all proxies, if known (e.g. from
#     Forwarded#for, X-Forwarded-For, or a similar header). Otherwise, the
#     immediate client peer address"; spec #27: bend-kit exposes no peer
#     address, so the attribute is absent otherwise.
#   Proof: Laws.client_address, by computation.
law client_address:
  {HttpCore.Server.client_address(proxied_headers()) == Some{"192.0.2.60"} : Maybe<&2, String>} &
  {HttpCore.Server.client_address(x_forwarded_headers()) == Some{"203.0.113.5"} : Maybe<&2, String>} &
  {HttpCore.Server.client_address([HttpCore.Header{"Forwarded", "for=\"[2001:db8:cafe::17]:4711\""}]) ==
    Some{"2001:db8:cafe::17"} : Maybe<&2, String>} &
  {HttpCore.Server.client_address([HttpCore.Header{"X-Forwarded-For", "\"203.0.113.5:4711\""}]) ==
    Some{"203.0.113.5"} : Maybe<&2, String>} &
  {HttpCore.Server.client_address(plain_headers()) == None{} : Maybe<&2, String>}

# LAW user_agent
#   Claim: `user_agent.original` is the User-Agent header, and absent
#     without one.
#   Requirement: the conventions, HTTP server span, `user_agent.original`:
#     "Value of the HTTP User-Agent header sent by the client".
#   Proof: Laws.user_agent, by computation.
law user_agent:
  {HttpCore.Server.user_agent(plain_headers()) == Some{"curl/8.4.0"} : Maybe<&2, String>} &
  {HttpCore.Server.user_agent(x_forwarded_headers()) == None{} : Maybe<&2, String>}

# 9. Client URL
# =============

# LAW client_server_attributes
#   Claim: a client span's `server.address` and `server.port` come from the
#     URL: the host of its authority after any userinfo, the brackets of an
#     IPv6 address dropped, and its port, or 80 for `http` and 443 for
#     `https` when the URL names none; a scheme without a default gives the
#     address alone, and a URL without an authority gives nothing.
#   Requirement: the conventions, HTTP client span, `server.address` and
#     `server.port`: "the host component of the request target" and "the
#     port component of the request target"; the conventions, "HTTP
#     client-server example": `server.address` `example.com`, `server.port`
#     `8080` for `https://example.com:8080/webshop/...`; spec #27, "Client":
#     default ports by scheme.
#   Proof: Laws.client_server_attributes, by computation.
law client_server_attributes:
  {HttpCore.Client.server_attributes("https://example.com:8443/x") ==
    [Api.Attribute{"server.address", Api.StringValue{"example.com"}},
     Api.Attribute{"server.port", Api.IntValue{Api.Int64.from_u32(8443)}}] : List<&2, Api.Attribute>} &
  {HttpCore.Client.server_attributes("http://example.com/") ==
    [Api.Attribute{"server.address", Api.StringValue{"example.com"}},
     Api.Attribute{"server.port", Api.IntValue{Api.Int64.from_u32(80)}}] : List<&2, Api.Attribute>} &
  {HttpCore.Client.server_attributes("https://user:secret@example.com") ==
    [Api.Attribute{"server.address", Api.StringValue{"example.com"}},
     Api.Attribute{"server.port", Api.IntValue{Api.Int64.from_u32(443)}}] : List<&2, Api.Attribute>} &
  {HttpCore.Client.server_attributes("http://[::1]:3000/") ==
    [Api.Attribute{"server.address", Api.StringValue{"::1"}},
     Api.Attribute{"server.port", Api.IntValue{Api.Int64.from_u32(3000)}}] : List<&2, Api.Attribute>} &
  {HttpCore.Client.server_attributes("ftp://example.com/") ==
    [Api.Attribute{"server.address", Api.StringValue{"example.com"}}] : List<&2, Api.Attribute>} &
  {HttpCore.Client.server_attributes("/relative?x=1") == Nil{} : List<&2, Api.Attribute>}

# 10. Header capture
# ==================

# LAW capture_literal
#   Claim: each configured header that the message carries gives one
#     attribute named by the prefix and the lowercased name, with every
#     value as a string array in arrival order; a configured header the
#     message lacks gives none.
#   Requirement: the conventions, `http.request.header.<key>`: "<key> being
#     the normalized HTTP Header name (lowercase), the value being the header
#     values"; "The attribute value MUST consist of either multiple header
#     values as an array of strings or a single-item array"; "Instrumentations
#     SHOULD require an explicit configuration of which headers are to be
#     captured".
#   Why: a configured name in any case must meet the header in any case and
#     name the attribute the conventions name.
#   Proof: Laws.capture_literal, by computation.
law capture_literal:
  {HttpCore.Capture.headers("http.request.header", ["Content-Type", "Accept", "X-Missing"],
    [HttpCore.Header{"content-type", "application/json"}, HttpCore.Header{"Accept", "text/html"},
     HttpCore.Header{"accept", "application/json"}]) ==
    [Api.Attribute{"http.request.header.content-type", Api.AttributeValue.strings(["application/json"])},
     Api.Attribute{"http.request.header.accept", Api.AttributeValue.strings(["text/html", "application/json"])}] :
    List<&2, Api.Attribute>} &
  {HttpCore.Capture.headers("http.response.header", ["Set-Cookie"], [HttpCore.Header{"set-cookie", "a=1"}]) ==
    [Api.Attribute{"http.response.header.set-cookie", Api.AttributeValue.strings(["a=1"])}] : List<&2, Api.Attribute>}

# LAW capture_nothing
#   Claim: with no configured header, nothing is captured, whatever the
#     message carries.
#   Requirement: spec #27, user story 10: capture is off by default, "so
#     that I decide what leaves the service".
#   Proof: Laws.capture_nothing, by computation.
law capture_nothing:
  for prefix: String
  for headers: List<&2, HttpCore.Header>
  {HttpCore.Capture.headers(prefix, Nil{}, headers) == Nil{} : List<&2, Api.Attribute>}

# LAW body_size_declared
#   Claim: the body size is the Content-Length header when it is a number,
#     in any case of the name and with surrounding spaces, and the body's
#     length when the header is not a number.
#   Requirement: the conventions, `http.request.body.size`: "the number of
#     bytes transferred excluding headers and is often, but not always,
#     present as the Content-Length header"; spec #27, "Server": "request
#     and response body sizes from Content-Length or the body length".
#   Proof: Laws.body_size_declared, by computation.
law body_size_declared:
  {HttpCore.Body.size([HttpCore.Header{"Content-Length", "12"}], 5) == 12 : U32} &
  {HttpCore.Body.size([HttpCore.Header{"content-length", " 12 "}], 5) == 12 : U32} &
  {HttpCore.Body.size([HttpCore.Header{"Content-Length", "many"}], 5) == 5 : U32}

# LAW body_size_length
#   Claim: without a Content-Length header, the body size is the body's
#     length, whatever it is.
#   Requirement: as body_size_declared.
#   Proof: Laws.body_size_length, by computation.
law body_size_length:
  for +length: U32
  {HttpCore.Body.size(Nil{}, length) == length : U32}

# 11. Configuration
# =================

# LAW config_default
#   Claim: the defaults are the conventions' known methods, the seven
#     sensitive query keys, no captured header and no body size.
#   Requirement: the conventions, `http.request.method` and `url.full`;
#     spec #27, user story 10: header and body capture are off by default.
#   Proof: Laws.config_default, by computation.
law config_default:
  {HttpCore.Config.known_methods(HttpCore.Config.default()) == HttpCore.Method.known_defaults() : List<&2, String>} &
  {HttpCore.Config.sensitive_query_keys(HttpCore.Config.default()) ==
    ["X-Amz-Signature", "X-Amz-Credential", "X-Amz-Security-Token", "AWSAccessKeyId", "Signature", "sig", "X-Goog-Signature"] :
    List<&2, String>} &
  {HttpCore.Config.request_headers(HttpCore.Config.default()) == Nil{} : List<&2, String>} &
  {HttpCore.Config.response_headers(HttpCore.Config.default()) == Nil{} : List<&2, String>} &
  {HttpCore.Config.body_sizes(HttpCore.Config.default()) == False{} : Bool}

# LAW config_setters_read_back
#   Claim: each setter is read back by its reader, whatever the
#     configuration held before.
#   Requirement: spec #27, "Configuration": pure setters; code wins over the
#     environment and the defaults.
#   Proof: Laws.config_setters_read_back, by opening the record.
law config_setters_read_back:
  for config: HttpCore.Config
  for +known_methods: List<&2, String>
  for +sensitive_query_keys: List<&2, String>
  for +request_headers: List<&2, String>
  for +response_headers: List<&2, String>
  for +body_sizes: Bool
  {HttpCore.Config.known_methods(HttpCore.Config.with_known_methods(config, known_methods)) == known_methods : List<&2, String>} &
  {HttpCore.Config.sensitive_query_keys(HttpCore.Config.with_sensitive_query_keys(config, sensitive_query_keys)) ==
    sensitive_query_keys : List<&2, String>} &
  {HttpCore.Config.request_headers(HttpCore.Config.with_request_headers(config, request_headers)) ==
    request_headers : List<&2, String>} &
  {HttpCore.Config.response_headers(HttpCore.Config.with_response_headers(config, response_headers)) ==
    response_headers : List<&2, String>} &
  {HttpCore.Config.body_sizes(HttpCore.Config.with_body_sizes(config, body_sizes)) == body_sizes : Bool}

# LAW methods_literal
#   Claim: the variable's text is a comma-separated list: items are trimmed
#     of surrounding spaces and kept in their case, and empty items are
#     dropped, so that an empty text or one of commas alone names no method.
#   Requirement: the conventions, `http.request.method`: the variable
#     "support[s] a comma-separated list of case-sensitive known HTTP
#     methods"; spec #27, "Configuration": the SDK's parsing rules (an empty
#     value is unset; a comma list).
#   Proof: Laws.methods_literal, by computation.
law methods_literal:
  {HttpCore.Env.read_methods("GET,POST") == ["GET", "POST"] : List<&2, String>} &
  {HttpCore.Env.read_methods(" GET , post ,") == ["GET", "post"] : List<&2, String>} &
  {HttpCore.Env.read_methods("GET,,QUERY") == ["GET", "QUERY"] : List<&2, String>} &
  {HttpCore.Env.read_methods("") == Nil{} : List<&2, String>} &
  {HttpCore.Env.read_methods(" , ") == Nil{} : List<&2, String>}

# LAW config_unset_is_default
#   Claim: an environment without the variable gives the defaults.
#   Requirement: spec #27, "Configuration": the environment applies on top
#     of the defaults.
#   Proof: Laws.config_unset_is_default, by computation.
law config_unset_is_default:
  {HttpCore.Config.from_variables(Nil{}) == HttpCore.Config.default() : HttpCore.Config} &
  {HttpCore.Config.variable_name() == "OTEL_INSTRUMENTATION_HTTP_KNOWN_METHODS" : String}

# LAW config_empty_is_unset
#   Claim: a variable with an empty value changes nothing, whatever its name
#     and whatever the other variables.
#   Requirement: OTel, SDK Configuration, Environment Variables: an empty
#     value is treated as unset; spec #27: the SDK's parsing rules.
#   Proof: Laws.config_empty_is_unset, by computation: the lookup passes
#     over an empty value whatever the name.
law config_empty_is_unset:
  for name: String
  for variables: List<&2, HttpCore.Variable>
  {HttpCore.Config.from_variables(Con{HttpCore.Variable{name, ""}, variables}) ==
    HttpCore.Config.from_variables(variables) : HttpCore.Config}

# LAW config_from_variables_literal
#   Claim: the variable set to `GET, POST` makes exactly `GET` and `POST`
#     known, and the other fields keep their defaults; another variable
#     changes nothing; a value of commas alone leaves the defaults.
#   Requirement: the conventions, `http.request.method`: "If this override is
#     done via environment variable, then the environment variable MUST be
#     named OTEL_INSTRUMENTATION_HTTP_KNOWN_METHODS"; "this list MUST be a
#     full override of the default known methods".
#   Why: an operator with a custom method must not see it flattened to
#     `_OTHER` across the fleet.
#   Proof: Laws.config_from_variables_literal, by computation.
law config_from_variables_literal:
  {HttpCore.Config.from_variables([HttpCore.Variable{"OTEL_INSTRUMENTATION_HTTP_KNOWN_METHODS", "GET, POST"}]) ==
    HttpCore.Config.with_known_methods(HttpCore.Config.default(), ["GET", "POST"]) : HttpCore.Config} &
  {HttpCore.Method.normalize(HttpCore.Config.known_methods(
    HttpCore.Config.from_variables([HttpCore.Variable{"OTEL_INSTRUMENTATION_HTTP_KNOWN_METHODS", "GET, POST"}])), "PUT") ==
    HttpCore.OtherMethod{"PUT"} : HttpCore.Method} &
  {HttpCore.Config.from_variables([HttpCore.Variable{"OTEL_LOG_LEVEL", "debug"}]) == HttpCore.Config.default() : HttpCore.Config} &
  {HttpCore.Config.from_variables([HttpCore.Variable{"OTEL_INSTRUMENTATION_HTTP_KNOWN_METHODS", ","}]) ==
    HttpCore.Config.default() : HttpCore.Config}

# 12. Spans
# =========
#
# The whole derivations on literal messages: the attribute collections of a
# server span and a client span, in the order the conventions list the
# attributes that matter for sampling first.

# The configuration that captures the Accept request header, the
# Content-Type response header and body sizes.
def capturing() -> HttpCore.Config:
  HttpCore.Config.with_body_sizes(HttpCore.Config.with_response_headers(
    HttpCore.Config.with_request_headers(HttpCore.Config.default(), ["Accept"]), ["Content-Type"]), True{})

# LAW server_request_literal
#   Claim: the request attributes of a server span behind a proxy, with a
#     route: the method, the path and the redacted query, the forwarded
#     scheme, the forwarded host and port, the forwarded client, the user
#     agent and the route, in that order, and nothing captured by default;
#     and behind no proxy, with capture: the method, the path, the plain
#     scheme, the Host's address and port, the user agent, the Accept values
#     and the body size from the body's length.
#   Requirement: the conventions, HTTP server span: the attributes
#     `http.request.method`, `url.path`, `url.query`, `url.scheme`,
#     `server.address`, `server.port`, `client.address`, `user_agent.original`,
#     `http.route`, `http.request.header.<key>` and `http.request.body.size`;
#     spec #27, "Server", "Attributes".
#   Proof: Laws.server_request_literal, by computation.
law server_request_literal:
  {Api.Attributes.to_list(HttpCore.Server.request_attributes(HttpCore.Config.default(), "GET", "/users/42?sig=abc&x=1",
    proxied_headers(), Some{"/users/:id"}, 0)) ==
    [Api.Attribute{"http.request.method", Api.StringValue{"GET"}},
     Api.Attribute{"url.path", Api.StringValue{"/users/42"}},
     Api.Attribute{"url.query", Api.StringValue{"sig=REDACTED&x=1"}},
     Api.Attribute{"url.scheme", Api.StringValue{"https"}},
     Api.Attribute{"server.address", Api.StringValue{"example.com"}},
     Api.Attribute{"server.port", Api.IntValue{Api.Int64.from_u32(8443)}},
     Api.Attribute{"client.address", Api.StringValue{"192.0.2.60"}},
     Api.Attribute{"user_agent.original", Api.StringValue{"curl/8.4.0"}},
     Api.Attribute{"http.route", Api.StringValue{"/users/:id"}}] : List<&2, Api.Attribute>} &
  {Api.Attributes.to_list(HttpCore.Server.request_attributes(capturing(), "POST", "/ping", plain_headers(), None{}, 7)) ==
    [Api.Attribute{"http.request.method", Api.StringValue{"POST"}},
     Api.Attribute{"url.path", Api.StringValue{"/ping"}},
     Api.Attribute{"url.scheme", Api.StringValue{"http"}},
     Api.Attribute{"server.address", Api.StringValue{"example.com"}},
     Api.Attribute{"server.port", Api.IntValue{Api.Int64.from_u32(8080)}},
     Api.Attribute{"user_agent.original", Api.StringValue{"curl/8.4.0"}},
     Api.Attribute{"http.request.header.accept", Api.AttributeValue.strings(["text/html", "application/json"])},
     Api.Attribute{"http.request.body.size", Api.IntValue{Api.Int64.from_u32(7)}}] : List<&2, Api.Attribute>}

# LAW server_response_literal
#   Claim: the response attributes of a server span: the status code and
#     `error.type` on a 503, nothing captured by default; the status code,
#     the Content-Type values and the declared body size on a 200 with
#     capture.
#   Requirement: the conventions, HTTP server span: `http.response.status_code`,
#     `error.type`, `http.response.header.<key>` and `http.response.body.size`.
#   Proof: Laws.server_response_literal, by computation.
law server_response_literal:
  {Api.Attributes.to_list(HttpCore.Server.response_attributes(HttpCore.Config.default(), 503,
    [HttpCore.Header{"Content-Type", "text/plain"}], 7)) ==
    [Api.Attribute{"http.response.status_code", Api.IntValue{Api.Int64.from_u32(503)}},
     Api.Attribute{"error.type", Api.StringValue{"503"}}] : List<&2, Api.Attribute>} &
  {Api.Attributes.to_list(HttpCore.Server.response_attributes(capturing(), 200,
    [HttpCore.Header{"Content-Type", "text/plain"}, HttpCore.Header{"Content-Length", "12"}], 7)) ==
    [Api.Attribute{"http.response.status_code", Api.IntValue{Api.Int64.from_u32(200)}},
     Api.Attribute{"http.response.header.content-type", Api.AttributeValue.strings(["text/plain"])},
     Api.Attribute{"http.response.body.size", Api.IntValue{Api.Int64.from_u32(12)}}] : List<&2, Api.Attribute>}

# LAW client_request_literal
#   Claim: the request attributes of a client span: `_OTHER` with the
#     original method, `url.full` with the credentials and the signature
#     redacted, and the server's address and default port, in that order.
#   Requirement: the conventions, HTTP client span: `http.request.method`,
#     `http.request.method_original`, `url.full`, `server.address` and
#     `server.port`; spec #27, "Client", "Attributes".
#   Proof: Laws.client_request_literal, by computation.
law client_request_literal:
  {Api.Attributes.to_list(HttpCore.Client.request_attributes(HttpCore.Config.default(), "get",
    "https://user:secret@api.example.com/v1/items?sig=abc&page=2", Nil{}, 0)) ==
    [Api.Attribute{"http.request.method", Api.StringValue{"_OTHER"}},
     Api.Attribute{"http.request.method_original", Api.StringValue{"get"}},
     Api.Attribute{"url.full", Api.StringValue{"https://REDACTED:REDACTED@api.example.com/v1/items?sig=REDACTED&page=2"}},
     Api.Attribute{"server.address", Api.StringValue{"api.example.com"}},
     Api.Attribute{"server.port", Api.IntValue{Api.Int64.from_u32(443)}}] : List<&2, Api.Attribute>}

# LAW client_response_literal
#   Claim: the response attributes of a client span: the status code alone
#     on a 200, the status code and `error.type` on a 404, and `error.type`
#     alone on a transport failure, which has no response.
#   Requirement: the conventions, HTTP client span: `http.response.status_code`
#     "if and only if one was received" and `error.type`; "HTTP client call:
#     DNS error" has `error.type` and no status code.
#   Proof: Laws.client_response_literal, by computation.
law client_response_literal:
  {Api.Attributes.to_list(HttpCore.Client.response_attributes(HttpCore.Config.default(), HttpCore.Responded{200}, Nil{}, 0)) ==
    [Api.Attribute{"http.response.status_code", Api.IntValue{Api.Int64.from_u32(200)}}] : List<&2, Api.Attribute>} &
  {Api.Attributes.to_list(HttpCore.Client.response_attributes(HttpCore.Config.default(), HttpCore.Responded{404}, Nil{}, 0)) ==
    [Api.Attribute{"http.response.status_code", Api.IntValue{Api.Int64.from_u32(404)}},
     Api.Attribute{"error.type", Api.StringValue{"404"}}] : List<&2, Api.Attribute>} &
  {Api.Attributes.to_list(HttpCore.Client.response_attributes(HttpCore.Config.default(),
    HttpCore.Failed{"ErrDns", "no such host"}, Nil{}, 0)) ==
    [Api.Attribute{"error.type", Api.StringValue{"ErrDns"}}] : List<&2, Api.Attribute>}
