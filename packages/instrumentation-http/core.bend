# bend-telemetry-instrumentation-http: OpenTelemetry HTTP instrumentation for Bend on bend-kit. Source: https://github.com/LucasGois1/bend-telemetry
import Base
import bend-telemetry-api@0.1.0.0/api.bend as Api
import bend-telemetry-semconv@0.1.0.0/semconv.bend as Semconv

# The HTTP instrumentation package: the pure core
# ===============================================
#
# OpenTelemetry HTTP instrumentation for Bend: spans and context propagation
# for HTTP on bend-kit. Its contract is the specification in
# https://github.com/LucasGois1/bend-telemetry/issues/27 ("spec #27" below)
# and the OpenTelemetry semantic conventions for HTTP spans at v1.44.0
# ("the conventions" below), whose attribute names and values come from the
# semconv package, never from literals typed here. This file is the pure
# core of the package (#34): given a method, a raw request target or a full
# URL, a header list and a status code or a transport failure, it answers
# the span name, the attributes and the status that the conventions require,
# with credentials and sensitive query values redacted. It performs no
# effect, so that LAWS.bend and PROOF.bend beside it import it alone and the
# proof gate prints ALL PROOFS CHECK, and it imports nothing of bend-kit, so
# that the rules are proved without the HTTP client. host.bend, the package's
# entry on the hub, adds the one effect, Config.from_env; the server and
# client wrappers over bend-kit-http follow in later tickets (#35, #36). A
# program imports the modules by the package's BendHub name:
#
#   import bend-telemetry-instrumentation-http@0.1.0.0/core.bend as HttpCore
#   import bend-telemetry-instrumentation-http@0.1.0.0/host.bend as HttpHost
#
# The results are API values: attributes as Api.Attributes and
# Api.Attribute with Api.AttributeValue, and the status as Api.Status.
# README.md beside this file is the reference; the glossary of the
# repository's CONTEXT.md supplies the terms: instrumentation, route,
# attribute, status, lane.
#
# Headers are a list of name-value pairs, one per field line in arrival
# order, and every lookup compares names without regard to case:
# Headers.from_map flattens the header map of bend-kit-http (one list of
# values per lowercase name) into that list. Status codes, ports and body
# sizes are U32, as bend-kit-http holds them.
#
# Contents
#
#   Package              Package.name
#   Types                every public type, declared first
#   Text                 Text.*: cutting, searching and unquoting text
#   Headers              Headers.*: lookups and the bridge from a header map
#   Attributes           Attribute.optional
#   Methods              Method.*: known methods, normalization, attributes
#   Span names           Span.name
#   Status               Status.*, Server.status, Client.status, error types
#   URLs                 Url.*, Query.redact, HostPort.*: url.full and server.*
#   Targets              Target.*: url.path and url.query
#   Forwarded headers    Forwarded.*, Server.scheme, address, client address
#   Header capture       Capture.*, Body.size
#   Configuration        Config.*, Env.read_methods
#   Spans                Server.* and Client.* attribute collections

# Package
# =======

# The package's BendHub name.
def Package.name() -> String:
  "bend-telemetry-instrumentation-http"

# Types
# =====

# One header field line: its name and its value. Names compare without
# regard to case in every lookup of this module.
type Header is Data:
  Header{name: String, value: String}

# One variable of an environment: its name and its text. host.bend reads
# it; Config.from_variables applies it.
type Variable is Data:
  Variable{name: String, value: String}

# A normalized request method: a known method, whose name is the value of
# `http.request.method`, or any other, which is `_OTHER` with the original
# text in `http.request.method_original` (the conventions, `http.request.method`).
type Method is Data:
  KnownMethod{name: String}
  OtherMethod{original: String}

# How a client call ended: with a response, or with a transport failure
# named by a low-cardinality identifier, the variant name of bend-kit's
# `Http.Err` in the client wrapper, and described by its message, empty when
# there is none.
type Outcome is Data:
  Responded{status_code: U32}
  Failed{error_type: String, description: String}

# A request target split into its path and its query, the query absent when
# the target has no `?`.
type Target is Data:
  Target{path: String, query: Maybe<&2, String>}

# A host and an optional port, parsed from an authority, a Host header or a
# forwarded address.
type HostPort is Data:
  HostPort{host: String, port: Maybe<&2, U32>}

# A text cut in two around a separator that is in neither part.
type Cut is Data:
  Cut{before: String, after: String}

# The authority of a URL text: what comes before it (the scheme and `//`),
# the authority itself, and the rest from the first `/`, `?` or `#` on.
type Authority is Data:
  Authority{prefix: String, authority: String, rest: String}

# The configuration of the instrumentation (spec #27, "Configuration"): the
# known methods, the sensitive query keys, the request and response headers
# to capture, and whether body sizes are captured. The record is closed:
# build it with Config.default or Config.from_variables, read it with the
# readers and change it with the setters, never by constructing or matching
# it, so that a field added later breaks no caller.
type Config is Data:
  Config{
    known_methods: List<&2, String>,
    sensitive_query_keys: List<&2, String>,
    request_headers: List<&2, String>,
    response_headers: List<&2, String>,
    body_sizes: Bool
  }

# Text
# ====
#
# The parsers of this module cut text at separators. Each recursion computes
# the cut of the rest before the comparison of the current character
# decides, since a decision helper cannot call back into a recursion defined
# after it.

# Whether a name is among a list of names, compared exactly.
def Text.listed(names: List<&2, String>, +name: String) -> Bool:
  match names:
    case Nil{}:
      False{}
    case Con{listed, rest}:
      Bool.or(String.eq(name, listed), Text.listed(rest, name))

# A character in front of the cut of the rest, when there is one.
def Text.cut.behind(char: Char, rest: Maybe<&2, Cut>) -> Maybe<&2, Cut>:
  match rest:
    case None{}:
      None{}
    case Some{Cut{before, after}}:
      Some{Cut{SCon{char, before}, after}}

# The separator ends the first part; any other character joins it.
def Text.cut.found(char: Char, tail: String, rest: Maybe<&2, Cut>, hit: Bool) -> Maybe<&2, Cut>:
  match hit:
    case True{}:
      Some{Cut{SNil{}, tail}}
    case False{}:
      Text.cut.behind(char, rest)

# The text cut at the first `sep`: the text before it and the text after it,
# the separator in neither; None when the text has no `sep`.
def Text.cut(text: String, +sep: Char) -> Maybe<&2, Cut>:
  match text:
    case SNil{}:
      None{}
    case SCon{+char, +tail}:
      Text.cut.found(char, tail, Text.cut(tail, sep), Char.is_eq(char, sep))

# The text cut at the last `sep`: a cut of the reversed text, reversed back.
def Text.cut_last.of(cut: Maybe<&2, Cut>) -> Maybe<&2, Cut>:
  match cut:
    case None{}:
      None{}
    case Some{Cut{before, after}}:
      Some{Cut{String.reverse(after), String.reverse(before)}}

def Text.cut_last(text: String, sep: Char) -> Maybe<&2, Cut>:
  Text.cut_last.of(Text.cut(String.reverse(text), sep))

# Whether the text has the character.
def Text.has(text: String, sep: Char) -> Bool:
  Maybe.is_some(&2, Cut, Text.cut(text, sep))

# Whether a character is one of the stops.
def Text.is_stop(stops: List<&2, Char>, +char: Char) -> Bool:
  match stops:
    case Nil{}:
      False{}
    case Con{stop, rest}:
      Bool.or(Char.is_eq(stop, char), Text.is_stop(rest, char))

# A character in front of the split of the rest.
def Text.split_at.behind(char: Char, rest: Cut) -> Cut:
  match rest:
    case Cut{before, after}:
      Cut{SCon{char, before}, after}

# A stop begins the second part and stays in it; any other character joins
# the first.
def Text.split_at.found(char: Char, tail: String, rest: Cut, hit: Bool) -> Cut:
  match hit:
    case True{}:
      Cut{SNil{}, SCon{char, tail}}
    case False{}:
      Text.split_at.behind(char, rest)

# The text split at the first of the stop characters, which begins the
# second part; a text without a stop is all first part.
def Text.split_at(text: String, +stops: List<&2, Char>) -> Cut:
  match text:
    case SNil{}:
      Cut{SNil{}, SNil{}}
    case SCon{+char, +tail}:
      Text.split_at.found(char, tail, Text.split_at(tail, stops), Text.is_stop(stops, char))

# The text without its closing double quote, when the opening one was there;
# with it back when the closing one is missing.
def Text.unquote.closing(reversed: String, rest: String) -> String:
  match reversed:
    case SCon{'"', more}:
      String.reverse(more)
    case other:
      SCon{'"', rest}

# The text without one double quote at each end, when both are there.
def Text.unquote(text: String) -> String:
  match text:
    case SCon{'"', +rest}:
      Text.unquote.closing(String.reverse(rest), rest)
    case other:
      other

# The first item of a comma-separated list, trimmed: the whole text when it
# has no comma.
def Text.first_item.of(+text: String, cut: Maybe<&2, Cut>) -> String:
  match cut:
    case None{}:
      String.trim(text)
    case Some{Cut{first, rest}}:
      String.trim(first)

# The parameter is plain, so that the definition is passed to Maybe.map.
def Text.first_item(text: String) -> String:
  +copy = text
  Text.first_item.of(copy, Text.cut(copy, ','))

# Headers
# =======
#
# A lookup lowercases the name sought once and each header's name as it
# compares, so that `Host`, `host` and `HOST` are one header.

# The value of the header whose name compared equal, or what the rest gave.
def Headers.first.step(value: String, rest: Maybe<&2, String>, same: Bool) -> Maybe<&2, String>:
  match same:
    case True{}:
      Some{value}
    case False{}:
      rest

def Headers.first.go(headers: List<&2, Header>, +lower: String) -> Maybe<&2, String>:
  match headers:
    case Nil{}:
      None{}
    case Con{Header{name, value}, rest}:
      Headers.first.step(value, Headers.first.go(rest, lower), String.eq(String.to_lower(name), lower))

# The value of the first header with the name, without regard to case, if
# any (law header_lookup).
def Headers.first(headers: List<&2, Header>, name: String) -> Maybe<&2, String>:
  Headers.first.go(headers, String.to_lower(name))

# The value of a header whose name compared equal, in front of the rest.
def Headers.values.step(value: String, rest: List<&2, String>, same: Bool) -> List<&2, String>:
  match same:
    case True{}:
      Con{value, rest}
    case False{}:
      rest

def Headers.values.go(headers: List<&2, Header>, +lower: String) -> List<&2, String>:
  match headers:
    case Nil{}:
      Nil{}
    case Con{Header{name, value}, rest}:
      Headers.values.step(value, Headers.values.go(rest, lower), String.eq(String.to_lower(name), lower))

# The values of every header with the name, without regard to case, in
# arrival order (law header_lookup).
def Headers.values(headers: List<&2, Header>, name: String) -> List<&2, String>:
  Headers.values.go(headers, String.to_lower(name))

# One header per value of a name, in front of the rest.
def Headers.from_map.values(+name: String, values: List<&2, String>, rest: List<&2, Header>) -> List<&2, Header>:
  match values:
    case Nil{}:
      rest
    case Con{value, more}:
      Con{Header{name, value}, Headers.from_map.values(name, more, rest)}

def Headers.from_map.go(entries: List<&2, Sigma<&2, &2, String, _ => List<&2, String>>>) -> List<&2, Header>:
  match entries:
    case Nil{}:
      Nil{}
    case Con{Tuple{name, values}, rest}:
      Headers.from_map.values(name, values, Headers.from_map.go(rest))

# The header list of a header map with one list of values per name, as
# bend-kit-http's `Req` and `Res` hold their headers: one header per value,
# names in the map's order and values in arrival order (law headers_from_map).
def Headers.from_map(map: Map<&2, List<&2, String>>) -> List<&2, Header>:
  Headers.from_map.go(Map.to_list(&2, List<&2, String>, map))

# Attributes
# ==========

# The string attribute of an optional value: one attribute when the value is
# there, none otherwise.
def Attribute.optional(key: String, value: Maybe<&2, String>) -> List<&2, Api.Attribute>:
  match value:
    case None{}:
      Nil{}
    case Some{text}:
      [Api.Attribute{key, Api.StringValue{text}}]

# Methods
# =======
#
# The conventions define the known methods as those of RFC 9110, PATCH and
# QUERY, matched exactly and case-sensitively; any other method is `_OTHER`
# with the original text kept, and the known set is overridable as a full
# replacement (the conventions, `http.request.method`).

# The known methods by default, from the semconv package's enumeration:
# CONNECT, DELETE, GET, HEAD, OPTIONS, PATCH, POST, PUT, TRACE and QUERY
# (law known_methods_default).
def Method.known_defaults() -> List<&2, String>:
  [Semconv.Http.Request.Method.connect(), Semconv.Http.Request.Method.delete(), Semconv.Http.Request.Method.get(),
   Semconv.Http.Request.Method.head(), Semconv.Http.Request.Method.options(), Semconv.Http.Request.Method.patch(),
   Semconv.Http.Request.Method.post(), Semconv.Http.Request.Method.put(), Semconv.Http.Request.Method.trace(),
   Semconv.Http.Request.Method.query()]

# A method that is known keeps its name; any other is kept as the original.
def Method.normalize.of(method: String, known: Bool) -> Method:
  match known:
    case True{}:
      KnownMethod{method}
    case False{}:
      OtherMethod{method}

# The normalized method under a set of known methods: known when the text is
# exactly one of them (laws method_listed, method_unlisted, method_literal).
def Method.normalize(known: List<&2, String>, +method: String) -> Method:
  Method.normalize.of(method, Text.listed(known, method))

# The value of `http.request.method`: the name of a known method, `_OTHER`
# otherwise.
def Method.name(method: Method) -> String:
  match method:
    case KnownMethod{name}:
      name
    case OtherMethod{original}:
      Semconv.Http.Request.Method.other()

# The value of `http.request.method_original`: the original text of a method
# that is not known; none for a known method.
def Method.original(method: Method) -> Maybe<&2, String>:
  match method:
    case KnownMethod{name}:
      None{}
    case OtherMethod{original}:
      Some{original}

# The method attributes: `http.request.method`, and `http.request.method_original`
# only when the method is `_OTHER` (law method_attributes).
def Method.attributes(method: Method) -> List<&2, Api.Attribute>:
  match method:
    case KnownMethod{name}:
      [Api.Attribute{Semconv.Http.Request.method(), Api.StringValue{name}}]
    case OtherMethod{original}:
      [Api.Attribute{Semconv.Http.Request.method(), Api.StringValue{Semconv.Http.Request.Method.other()}},
       Api.Attribute{Semconv.Http.Request.method_original(), Api.StringValue{original}}]

# Span names
# ==========

# The `{method}` placeholder of a span name: the known method, or `HTTP`
# when the method is `_OTHER` (the conventions, "Name").
def Span.name.placeholder(method: Method) -> String:
  match method:
    case KnownMethod{name}:
      name
    case OtherMethod{original}:
      "HTTP"

# The span name: `{method} {route}` when a route is known, `{method}`
# otherwise; a path never names a span (laws span_name_route,
# span_name_method, span_name_other).
def Span.name(method: Method, route: Maybe<&2, String>) -> String:
  match route:
    case None{}:
      Span.name.placeholder(method)
    case Some{pattern}:
      Span.name.placeholder(method) ++ " " ++ pattern

# Status
# ======
#
# The conventions, "Status": a server span stays unset on 1xx to 4xx and is
# an error on 5xx; a client span stays unset on 1xx to 3xx and is an error
# on 4xx and 5xx and on a transport failure; the description stays empty
# when the status code says the reason. `error.type` is the status code as
# text when the status is an error, the failure's identifier on a transport
# failure, and never set on success. The status is the API's: Api.Unset{} or
# Api.Error{description}; the HTTP rules never answer Api.Ok{}.

# An error status with no description, or unset.
def Status.of(error: Bool) -> Api.Status:
  match error:
    case True{}:
      Api.Error{""}
    case False{}:
      Api.Unset{}

# The status code as text when the status is an error, nothing otherwise.
def ErrorType.of(status_code: U32, error: Bool) -> Maybe<&2, String>:
  match error:
    case True{}:
      Some{U32.show(status_code)}
    case False{}:
      None{}

# Whether a server's response code is an error: 500 or more.
def Server.is_error(status_code: U32) -> Bool:
  U32.is_ge(status_code, 500)

# The status of a server span from its response code (laws server_status_low,
# server_status_error, status_literal).
def Server.status(status_code: U32) -> Api.Status:
  Status.of(Server.is_error(status_code))

# The `error.type` of a server span: the status code as text on 5xx, none
# otherwise (laws server_error_type_low, server_error_type_error,
# error_type_literal).
def Server.error_type(+status_code: U32) -> Maybe<&2, String>:
  ErrorType.of(status_code, Server.is_error(status_code))

# Whether a client's response code is an error: 400 or more.
def Client.is_error(status_code: U32) -> Bool:
  U32.is_ge(status_code, 400)

# The status of a client span from how its call ended: unset below 400,
# error from 400 on, and error with the failure's description on a transport
# failure (laws client_status_low, client_status_error, client_status_failed,
# status_literal).
def Client.status(outcome: Outcome) -> Api.Status:
  match outcome:
    case Responded{status_code}:
      Status.of(Client.is_error(status_code))
    case Failed{error_type, description}:
      Api.Error{description}

# The `error.type` of a client span that got a response: the status code as
# text from 400 on, none otherwise.
def Client.error_type.responded(+status_code: U32) -> Maybe<&2, String>:
  ErrorType.of(status_code, Client.is_error(status_code))

# The `error.type` of a client span: the status code as text when the
# response was an error, the failure's identifier on a transport failure,
# none on success (laws client_error_type_low, client_error_type_error,
# client_error_type_failed, error_type_literal).
def Client.error_type(outcome: Outcome) -> Maybe<&2, String>:
  match outcome:
    case Responded{status_code}:
      Client.error_type.responded(status_code)
    case Failed{error_type, description}:
      Some{error_type}

# The `http.response.status_code` attribute.
def Response.status_attribute(status_code: U32) -> Api.Attribute:
  Api.Attribute{Semconv.Http.Response.status_code(), Api.IntValue{Api.Int64.from_u32(status_code)}}

# URLs
# ====
#
# `url.full` must not carry credentials: the userinfo of the authority is
# replaced by `REDACTED:REDACTED` before anything else is read, since
# bend-kit-url refuses userinfo and the text must not leak. The values of
# the sensitive query keys are then replaced by `REDACTED`, the keys kept
# (the conventions, `url.full`). The authority also gives a client span's
# `server.address` and `server.port`, the port defaulting by scheme.

# A cut around the stops gives the authority and the rest.
def Url.authority.split(prefix: String, cut: Cut) -> Maybe<&2, Authority>:
  match cut:
    case Cut{authority, rest}:
      Some{Authority{prefix, authority, rest}}

# The authority runs from after `//` to the first `/`, `?` or `#`.
def Url.authority.with(prefix: String, remainder: String) -> Maybe<&2, Authority>:
  Url.authority.split(prefix, Text.split_at(remainder, ['/', '?', '#']))

# After a scheme, an authority begins only with `//`.
def Url.authority.slashes(prefix: String, after: String, slashes: Bool) -> Maybe<&2, Authority>:
  match slashes:
    case True{}:
      Url.authority.with(prefix ++ "//", String.drop(after, 2n))
    case False{}:
      None{}

def Url.authority.scheme(cut: Maybe<&2, Cut>) -> Maybe<&2, Authority>:
  match cut:
    case None{}:
      None{}
    case Some{Cut{scheme, +after}}:
      Url.authority.slashes(scheme ++ ":", after, String.starts_with(after, "//"))

# A text that opens with `//` is scheme-relative; otherwise the scheme ends
# at the first colon.
def Url.authority.start(+url: String, relative: Bool) -> Maybe<&2, Authority>:
  match relative:
    case True{}:
      Url.authority.with("//", String.drop(url, 2n))
    case False{}:
      Url.authority.scheme(Text.cut(url, ':'))

# The authority of a URL text, with what surrounds it; None when the text
# has none (RFC 3986, section 3.2: it begins with `//` and ends at the next
# `/`, `?` or `#`, or at the end).
def Url.authority(+url: String) -> Maybe<&2, Authority>:
  Url.authority.start(url, String.starts_with(url, "//"))

# The URL rebuilt with its userinfo, everything before the last `@` of the
# authority, replaced.
def Url.redact_userinfo.at(prefix: String, rest: String, authority: String, at: Maybe<&2, Cut>) -> String:
  match at:
    case None{}:
      prefix ++ authority ++ rest
    case Some{Cut{userinfo, host_port}}:
      prefix ++ "REDACTED:REDACTED@" ++ host_port ++ rest

def Url.redact_userinfo.of(url: String, found: Maybe<&2, Authority>) -> String:
  match found:
    case None{}:
      url
    case Some{Authority{prefix, +authority, rest}}:
      Url.redact_userinfo.at(prefix, rest, authority, Text.cut_last(authority, '@'))

# The URL with the userinfo of its authority, if any, replaced by
# `REDACTED:REDACTED` (law url_full_credentials). A URL without an authority
# is kept as it is.
def Url.redact_userinfo(+url: String) -> String:
  Url.redact_userinfo.of(url, Url.authority(url))

# A parameter whose key is sensitive keeps its key and loses its value.
def Query.parameter.sensitive(piece: String, key: String, sensitive: Bool) -> String:
  match sensitive:
    case True{}:
      key ++ "=REDACTED"
    case False{}:
      piece

# A parameter without `=` has no value to redact.
def Query.parameter.cut(piece: String, keys: List<&2, String>, cut: Maybe<&2, Cut>) -> String:
  match cut:
    case None{}:
      piece
    case Some{Cut{+key, value}}:
      Query.parameter.sensitive(piece, key, Text.listed(keys, key))

def Query.parameter(keys: List<&2, String>, +piece: String) -> String:
  Query.parameter.cut(piece, keys, Text.cut(piece, '='))

def Query.redact.go(pieces: List<&2, String>, +keys: List<&2, String>) -> List<&2, String>:
  match pieces:
    case Nil{}:
      Nil{}
    case Con{piece, rest}:
      Con{Query.parameter(keys, piece), Query.redact.go(rest, keys)}

# The query with the value of every parameter whose key is one of the
# sensitive keys, compared exactly, replaced by `REDACTED`; the key stays, a
# key without a value stays whole, and every other parameter is untouched
# (laws url_full_sensitive_keys, url_full_key_without_value,
# url_full_prefix_key, url_full_override, target_query_redacted).
def Query.redact(keys: List<&2, String>, query: String) -> String:
  String.join(Query.redact.go(String.split(query, '&'), keys), "&")

# The query ends at `#`; a fragment after it is kept.
def Url.redact_query.fragment(keys: List<&2, String>, before: String, rest: String, hash: Maybe<&2, Cut>) -> String:
  match hash:
    case None{}:
      before ++ "?" ++ Query.redact(keys, rest)
    case Some{Cut{query, fragment}}:
      before ++ "?" ++ Query.redact(keys, query) ++ "#" ++ fragment

def Url.redact_query.of(keys: List<&2, String>, url: String, question: Maybe<&2, Cut>) -> String:
  match question:
    case None{}:
      url
    case Some{Cut{before, +rest}}:
      Url.redact_query.fragment(keys, before, rest, Text.cut(rest, '#'))

# The URL with its query, from the first `?` to the `#` or the end, redacted.
def Url.redact_query(keys: List<&2, String>, +url: String) -> String:
  Url.redact_query.of(keys, url, Text.cut(url, '?'))

# The value of `url.full` for a URL text: credentials redacted first, then
# the values of the sensitive query keys (laws url_full_*).
def Url.full(keys: List<&2, String>, url: String) -> String:
  Url.redact_query(keys, Url.redact_userinfo(url))

# The scheme is a scheme only when `//` follows it.
def Url.scheme.slashes(scheme: String, slashes: Bool) -> Maybe<&2, String>:
  match slashes:
    case True{}:
      Some{String.to_lower(scheme)}
    case False{}:
      None{}

def Url.scheme.of(cut: Maybe<&2, Cut>) -> Maybe<&2, String>:
  match cut:
    case None{}:
      None{}
    case Some{Cut{scheme, after}}:
      Url.scheme.slashes(scheme, String.starts_with(after, "//"))

# The scheme of an absolute URL text, lowercased; None for a scheme-relative
# or relative text.
def Url.scheme(url: String) -> Maybe<&2, String>:
  Url.scheme.of(Text.cut(url, ':'))

# The default port of a scheme: 80 for http, 443 for https, none otherwise.
def Url.default_port.pick(http: Bool, https: Bool) -> Maybe<&2, U32>:
  match http:
    case True{}:
      Some{80}
    case False{}:
      match https:
        case True{}:
          Some{443}
        case False{}:
          None{}

def Url.default_port.of(+scheme: String) -> Maybe<&2, U32>:
  Url.default_port.pick(String.eq(scheme, "http"), String.eq(scheme, "https"))

def Url.default_port(scheme: Maybe<&2, String>) -> Maybe<&2, U32>:
  match scheme:
    case None{}:
      None{}
    case Some{name}:
      Url.default_port.of(name)

# The port after a bracketed address: the number after `:`, if any.
def HostPort.colon_port(after: String) -> Maybe<&2, U32>:
  match after:
    case SCon{':', port}:
      U32.read(port)
    case other:
      None{}

# A host with one colon has a port after it; with more, it is a bare IPv6
# address and has none.
def HostPort.plain.colons(text: String, host: String, port: String, more: Bool) -> HostPort:
  match more:
    case True{}:
      HostPort{text, None{}}
    case False{}:
      HostPort{host, U32.read(port)}

def HostPort.plain.cut(+text: String, cut: Maybe<&2, Cut>) -> HostPort:
  match cut:
    case None{}:
      HostPort{text, None{}}
    case Some{Cut{host, +port}}:
      HostPort.plain.colons(text, host, port, Text.has(port, ':'))

# A bracketed address ends at `]`; an unclosed bracket is kept as the host.
def HostPort.parse.open(text: String, bracket: Maybe<&2, Cut>) -> HostPort:
  match bracket:
    case None{}:
      HostPort{text, None{}}
    case Some{Cut{host, after}}:
      HostPort{host, HostPort.colon_port(after)}

def HostPort.parse.of(+text: String, bracketed: Bool) -> HostPort:
  match bracketed:
    case True{}:
      HostPort.parse.open(text, Text.cut(String.drop(text, 1n), ']'))
    case False{}:
      HostPort.plain.cut(text, Text.cut(text, ':'))

# The host and port of an authority without userinfo, of a Host header or of
# a forwarded address: a bracketed IPv6 address loses its brackets and may be
# followed by `:port`; any other host has a port after its only colon, read
# as a number, or none (laws server_address_port, client_address,
# client_server_attributes).
def HostPort.parse(+text: String) -> HostPort:
  HostPort.parse.of(text, String.starts_with(text, "["))

# The host.
def HostPort.host(host_port: HostPort) -> String:
  match host_port:
    case HostPort{host, port}:
      host

# The port, if any.
def HostPort.port(host_port: HostPort) -> Maybe<&2, U32>:
  match host_port:
    case HostPort{host, port}:
      port

# The host and port of a URL's authority, after its userinfo.
def Url.host_port.at(authority: String, at: Maybe<&2, Cut>) -> HostPort:
  match at:
    case None{}:
      HostPort.parse(authority)
    case Some{Cut{userinfo, host_port}}:
      HostPort.parse(host_port)

def Url.host_port.of(found: Maybe<&2, Authority>) -> Maybe<&2, HostPort>:
  match found:
    case None{}:
      None{}
    case Some{Authority{prefix, +authority, rest}}:
      Some{Url.host_port.at(authority, Text.cut_last(authority, '@'))}

# The host and port of a URL text's authority, if it has one.
def Url.host_port(url: String) -> Maybe<&2, HostPort>:
  Url.host_port.of(Url.authority(url))

# The `server.port` attribute of a port, if any.
def Address.port_attribute(port: Maybe<&2, U32>) -> List<&2, Api.Attribute>:
  match port:
    case None{}:
      Nil{}
    case Some{number}:
      [Api.Attribute{Semconv.Server.port(), Api.IntValue{Api.Int64.from_u32(number)}}]

# An empty host gives no attribute; a host gives `server.address` and then
# `server.port` when there is a port.
def Address.attributes.host(host: String, port: Maybe<&2, U32>, empty: Bool) -> List<&2, Api.Attribute>:
  match empty:
    case True{}:
      Nil{}
    case False{}:
      Con{Api.Attribute{Semconv.Server.address(), Api.StringValue{host}}, Address.port_attribute(port)}

# `server.address` and `server.port` of a host and port, the port falling
# back to a default when the text had none.
def Address.attributes(host_port: HostPort, default: Maybe<&2, U32>) -> List<&2, Api.Attribute>:
  match host_port:
    case HostPort{+host, port}:
      Address.attributes.host(host, Maybe.or(&2, U32, port, default), String.is_empty(host))

def Client.server_attributes.of(found: Maybe<&2, HostPort>, default: Maybe<&2, U32>) -> List<&2, Api.Attribute>:
  match found:
    case None{}:
      Nil{}
    case Some{host_port}:
      Address.attributes(host_port, default)

# `server.address` and `server.port` of a client span, from the URL: the
# host of its authority, and its port or the scheme's default (the
# conventions, HTTP client span, `server.address`; law
# client_server_attributes).
def Client.server_attributes(+url: String) -> List<&2, Api.Attribute>:
  Client.server_attributes.of(Url.host_port(url), Url.default_port(Url.scheme(url)))

# Targets
# =======

# A target with `?` has a query, possibly empty; one without has none.
def Target.split.of(target: String, cut: Maybe<&2, Cut>) -> Target:
  match cut:
    case None{}:
      Target{target, None{}}
    case Some{Cut{path, query}}:
      Target{path, Some{query}}

# The raw request target of a server request, in origin form, split at its
# first `?` into `url.path` and `url.query` (law target_split).
def Target.split(+target: String) -> Target:
  Target.split.of(target, Text.cut(target, '?'))

# The path.
def Target.path(target: Target) -> String:
  match target:
    case Target{path, query}:
      path

# The query, if the target had one.
def Target.query(target: Target) -> Maybe<&2, String>:
  match target:
    case Target{path, query}:
      query

# The `url.query` attribute, redacted, when the target had a query.
def Target.attributes.query(keys: List<&2, String>, query: Maybe<&2, String>) -> List<&2, Api.Attribute>:
  match query:
    case None{}:
      Nil{}
    case Some{text}:
      [Api.Attribute{Semconv.Url.query(), Api.StringValue{Query.redact(keys, text)}}]

# `url.path` and `url.query` of a split target, the query redacted with the
# sensitive keys (law target_query_redacted).
def Target.attributes(keys: List<&2, String>, target: Target) -> List<&2, Api.Attribute>:
  match target:
    case Target{path, query}:
      Con{Api.Attribute{Semconv.Url.path(), Api.StringValue{path}}, Target.attributes.query(keys, query)}

# Forwarded headers
# =================
#
# A server behind a proxy learns the original request from `Forwarded`
# (RFC 7239) or the `X-Forwarded-*` headers: the scheme from `proto`, the
# host and port from `host` and the client from `for`, each read from the
# first header that carries it, `Forwarded` first; bend-kit exposes no peer
# address, so `client.address` is absent without them (the conventions, HTTP
# server span and "Setting server.address and server.port attributes").

# A `name=value` pair as a header: the name lowercased and the value
# unquoted, both trimmed; a piece without `=` is skipped.
def Forwarded.pair(cut: Maybe<&2, Cut>) -> List<&2, Header>:
  match cut:
    case None{}:
      Nil{}
    case Some{Cut{name, value}}:
      [Header{String.to_lower(String.trim(name)), Text.unquote(String.trim(value))}]

def Forwarded.pairs.go(pieces: List<&2, String>) -> List<&2, Header>:
  match pieces:
    case Nil{}:
      Nil{}
    case Con{piece, rest}:
      List.append(&2, Header, Forwarded.pair(Text.cut(piece, '=')), Forwarded.pairs.go(rest))

# The elements of a Forwarded value are separated by `,` and their pairs by
# `;`.
def Forwarded.pieces(elements: List<&2, String>) -> List<&2, String>:
  match elements:
    case Nil{}:
      Nil{}
    case Con{element, rest}:
      List.append(&2, String, String.split(element, ';'), Forwarded.pieces(rest))

def Forwarded.pairs.values(values: List<&2, String>) -> List<&2, Header>:
  match values:
    case Nil{}:
      Nil{}
    case Con{value, rest}:
      List.append(&2, Header, Forwarded.pairs.go(Forwarded.pieces(String.split(value, ','))), Forwarded.pairs.values(rest))

# The parameters of every Forwarded header, in order, as headers named by
# the parameter: `for`, `host`, `proto` and `by`, values unquoted.
def Forwarded.pairs(headers: List<&2, Header>) -> List<&2, Header>:
  Forwarded.pairs.values(Headers.values(headers, "forwarded"))

# The first value of a Forwarded parameter, if any header carries it.
def Forwarded.parameter(headers: List<&2, Header>, name: String) -> Maybe<&2, String>:
  Headers.first(Forwarded.pairs(headers), name)

# `url.scheme` of a server span: the `proto` of Forwarded, else
# X-Forwarded-Proto, each lowercased, else `http`, the scheme of bend-kit's
# server (law server_scheme).
def Server.scheme(+headers: List<&2, Header>) -> String:
  String.to_lower(Maybe.default(&2, String, Maybe.or(&2, String, Forwarded.parameter(headers, "proto"),
    Maybe.map(&2, String, String, Text.first_item, Headers.first(headers, "x-forwarded-proto"))), "http"))

# The host the client addressed: the `host` of Forwarded, else
# X-Forwarded-Host, else Host, the first item of each.
def Server.host(+headers: List<&2, Header>) -> Maybe<&2, String>:
  Maybe.or(&2, String, Forwarded.parameter(headers, "host"),
    Maybe.map(&2, String, String, Text.first_item,
      Maybe.or(&2, String, Headers.first(headers, "x-forwarded-host"), Headers.first(headers, "host"))))

def Server.address_attributes.of(host: Maybe<&2, String>) -> List<&2, Api.Attribute>:
  match host:
    case None{}:
      Nil{}
    case Some{text}:
      Address.attributes(HostPort.parse(Text.unquote(text)), None{})

# `server.address` and `server.port` of a server span, parsed from the host
# the client addressed; absent without a host, and the port absent when the
# host carries none (law server_address_port).
def Server.address_attributes(headers: List<&2, Header>) -> List<&2, Api.Attribute>:
  Server.address_attributes.of(Server.host(headers))

# A forwarded address loses its quotes, its brackets and its port; an empty
# one is no address.
def Server.client_address.host(host: String) -> Maybe<&2, String>:
  match host:
    case SNil{}:
      None{}
    case SCon{head, tail}:
      Some{SCon{head, tail}}

def Server.client_address.of(found: Maybe<&2, String>) -> Maybe<&2, String>:
  match found:
    case None{}:
      None{}
    case Some{text}:
      Server.client_address.host(HostPort.host(HostPort.parse(Text.unquote(text))))

# `client.address` of a server span: the `for` of Forwarded, else the first
# address of X-Forwarded-For, without its port; absent without them (law
# client_address).
def Server.client_address(+headers: List<&2, Header>) -> Maybe<&2, String>:
  Server.client_address.of(Maybe.or(&2, String, Forwarded.parameter(headers, "for"),
    Maybe.map(&2, String, String, Text.first_item, Headers.first(headers, "x-forwarded-for"))))

# `user_agent.original` of a server span: the User-Agent header, if any (law
# user_agent).
def Server.user_agent(headers: List<&2, Header>) -> Maybe<&2, String>:
  Headers.first(headers, "user-agent")

# Header capture
# ==============
#
# Capturing headers is opt-in and explicit: each configured name, lowercased,
# gives `http.request.header.<name>` or `http.response.header.<name>` with the
# header's values as an array of strings, one per field line (the
# conventions, `http.request.header.<key>`). Body sizes are opt-in too.

# One attribute for a header that is there, none for one that is not.
def Capture.attribute(prefix: String, lower: String, values: List<&2, String>) -> List<&2, Api.Attribute>:
  match values:
    case Nil{}:
      Nil{}
    case Con{value, rest}:
      [Api.Attribute{prefix ++ "." ++ lower, Api.AttributeValue.strings(Con{value, rest})}]

def Capture.headers.go(names: List<&2, String>, +prefix: String, +headers: List<&2, Header>) -> List<&2, Api.Attribute>:
  match names:
    case Nil{}:
      Nil{}
    case Con{name, rest}:
      +lower = String.to_lower(name)
      List.append(&2, Api.Attribute, Capture.attribute(prefix, lower, Headers.values.go(headers, lower)),
        Capture.headers.go(rest, prefix, headers))

# The captured headers under a prefix, the semconv package's
# `Http.Request.header()` or `Http.Response.header()`: for each configured
# name in order, the attribute `<prefix>.<name>` with the name lowercased
# and the values as a string array; a header the message lacks gives none
# (laws capture_literal, capture_nothing).
def Capture.headers(prefix: String, names: List<&2, String>, headers: List<&2, Header>) -> List<&2, Api.Attribute>:
  Capture.headers.go(names, prefix, headers)

# A declared length wins; the body's own length stands otherwise.
def Body.size.of(length: U32, declared: Maybe<&2, U32>) -> U32:
  match declared:
    case None{}:
      length
    case Some{number}:
      number

def Body.size.declared(found: Maybe<&2, String>) -> Maybe<&2, U32>:
  match found:
    case None{}:
      None{}
    case Some{text}:
      U32.read(String.trim(text))

# The size of a body in bytes: the Content-Length header when it is a
# number, else the length of the body (laws body_size_declared,
# body_size_length).
def Body.size(headers: List<&2, Header>, length: U32) -> U32:
  Body.size.of(length, Body.size.declared(Headers.first(headers, "content-length")))

# The body size attribute under a key, the semconv package's
# `Http.Request.Body.size()` or `Http.Response.Body.size()`, when sizes are
# captured; none otherwise.
def Capture.body_size(key: String, enabled: Bool, headers: List<&2, Header>, length: U32) -> List<&2, Api.Attribute>:
  match enabled:
    case True{}:
      [Api.Attribute{key, Api.IntValue{Api.Int64.from_u32(Body.size(headers, length))}}]
    case False{}:
      Nil{}

# Configuration
# =============
#
# Config.default holds the conventions' defaults; Config.from_variables
# applies the one variable, OTEL_INSTRUMENTATION_HTTP_KNOWN_METHODS, on top of
# them with the parsing rules of the SDK; the setters apply programmatic
# settings on top of either, so that code wins over the environment and the
# environment over the defaults.

# The query keys whose values are redacted by default: the five of the
# conventions at v1.44.0 (`X-Amz-Signature`, `X-Amz-Credential`,
# `X-Amz-Security-Token`, `sig`, `X-Goog-Signature`) and the two of their
# earlier versions, `AWSAccessKeyId` and `Signature`, which SigV2 presigned
# URLs still carry (law config_default).
def Config.sensitive_defaults() -> List<&2, String>:
  ["X-Amz-Signature", "X-Amz-Credential", "X-Amz-Security-Token", "AWSAccessKeyId", "Signature", "sig",
   "X-Goog-Signature"]

# The defaults: the known methods of the conventions, the sensitive query
# keys above, no header captured and no body size (law config_default).
def Config.default() -> Config:
  Config{Method.known_defaults(), Config.sensitive_defaults(), Nil{}, Nil{}, False{}}

# The methods that are known: any other is `_OTHER`.
def Config.known_methods(config: Config) -> List<&2, String>:
  match config:
    case Config{known_methods, sensitive_query_keys, request_headers, response_headers, body_sizes}:
      known_methods

# The query keys whose values `url.full` and `url.query` redact.
def Config.sensitive_query_keys(config: Config) -> List<&2, String>:
  match config:
    case Config{known_methods, sensitive_query_keys, request_headers, response_headers, body_sizes}:
      sensitive_query_keys

# The request headers to capture, by name.
def Config.request_headers(config: Config) -> List<&2, String>:
  match config:
    case Config{known_methods, sensitive_query_keys, request_headers, response_headers, body_sizes}:
      request_headers

# The response headers to capture, by name.
def Config.response_headers(config: Config) -> List<&2, String>:
  match config:
    case Config{known_methods, sensitive_query_keys, request_headers, response_headers, body_sizes}:
      response_headers

# Whether body sizes are captured.
def Config.body_sizes(config: Config) -> Bool:
  match config:
    case Config{known_methods, sensitive_query_keys, request_headers, response_headers, body_sizes}:
      body_sizes

# The configuration with another set of known methods, a full replacement
# (law config_setters_read_back).
def Config.with_known_methods(config: Config, known_methods: List<&2, String>) -> Config:
  match config:
    case Config{previous, sensitive_query_keys, request_headers, response_headers, body_sizes}:
      Config{known_methods, sensitive_query_keys, request_headers, response_headers, body_sizes}

# The configuration with other sensitive query keys, a full replacement.
def Config.with_sensitive_query_keys(config: Config, sensitive_query_keys: List<&2, String>) -> Config:
  match config:
    case Config{known_methods, previous, request_headers, response_headers, body_sizes}:
      Config{known_methods, sensitive_query_keys, request_headers, response_headers, body_sizes}

# The configuration capturing these request headers.
def Config.with_request_headers(config: Config, request_headers: List<&2, String>) -> Config:
  match config:
    case Config{known_methods, sensitive_query_keys, previous, response_headers, body_sizes}:
      Config{known_methods, sensitive_query_keys, request_headers, response_headers, body_sizes}

# The configuration capturing these response headers.
def Config.with_response_headers(config: Config, response_headers: List<&2, String>) -> Config:
  match config:
    case Config{known_methods, sensitive_query_keys, request_headers, previous, body_sizes}:
      Config{known_methods, sensitive_query_keys, request_headers, response_headers, body_sizes}

# The configuration capturing body sizes, or not.
def Config.with_body_sizes(config: Config, body_sizes: Bool) -> Config:
  match config:
    case Config{known_methods, sensitive_query_keys, request_headers, response_headers, previous}:
      Config{known_methods, sensitive_query_keys, request_headers, response_headers, body_sizes}

# The name of the one variable the instrumentation reads (the conventions,
# `http.request.method`).
def Config.variable_name() -> String:
  "OTEL_INSTRUMENTATION_HTTP_KNOWN_METHODS"

# A trimmed item that is empty is dropped.
def Env.methods.keep(item: String, rest: List<&2, String>) -> List<&2, String>:
  match item:
    case SNil{}:
      rest
    case SCon{head, tail}:
      Con{SCon{head, tail}, rest}

def Env.methods.go(pieces: List<&2, String>) -> List<&2, String>:
  match pieces:
    case Nil{}:
      Nil{}
    case Con{piece, rest}:
      Env.methods.keep(String.trim(piece), Env.methods.go(rest))

# The methods of a comma-separated list, each trimmed of surrounding white
# space and kept case-sensitive; empty items are dropped (law methods_literal).
def Env.read_methods(text: String) -> List<&2, String>:
  Env.methods.go(String.split(text, ','))

# The value of a variable found under the name, unless it is empty: an empty
# value is an unset variable, so the search goes on.
def Env.lookup.step(value: String, rest: Maybe<&2, String>, same: Bool) -> Maybe<&2, String>:
  match value:
    case SNil{}:
      rest
    case SCon{head, tail}:
      match same:
        case True{}:
          Some{SCon{head, tail}}
        case False{}:
          rest

# The non-empty value of the first variable with the name, if any.
def Env.lookup(variables: List<&2, Variable>, +name: String) -> Maybe<&2, String>:
  match variables:
    case Nil{}:
      None{}
    case Con{Variable{found, value}, rest}:
      Env.lookup.step(value, Env.lookup(rest, name), String.eq(found, name))

# A list with at least one method replaces the known methods; a value with
# none is unset.
def Config.from_variables.methods(config: Config, methods: List<&2, String>) -> Config:
  match methods:
    case Nil{}:
      config
    case Con{head, tail}:
      Config.with_known_methods(config, Con{head, tail})

def Config.from_variables.found(config: Config, found: Maybe<&2, String>) -> Config:
  match found:
    case None{}:
      config
    case Some{text}:
      Config.from_variables.methods(config, Env.read_methods(text))

# The configuration of an environment: the defaults, with the known methods
# replaced by those of OTEL_INSTRUMENTATION_HTTP_KNOWN_METHODS when it is set,
# not empty and names at least one method (laws config_unset_is_default,
# config_empty_is_unset, config_from_variables_literal). host.bend's
# Config.from_env reads the variable and calls it.
def Config.from_variables(variables: List<&2, Variable>) -> Config:
  Config.from_variables.found(Config.default(), Env.lookup(variables, Config.variable_name()))

# Spans
# =====
#
# The attribute collections of the two span kinds, in the order the
# conventions list the attributes that matter for sampling first. The server
# wrapper will set the request attributes at span creation and the response
# attributes before the span ends; the client wrapper likewise.

# The attributes of a server span at its start: `http.request.method` and
# the original method, `url.path`, `url.query` redacted, `url.scheme`,
# `server.address` and `server.port`, `client.address`, `user_agent.original`,
# `http.route` when the route is known, the captured request headers and the
# request body size when enabled (law server_request_literal).
def Server.request_attributes(config: Config, method: String, target: String, +headers: List<&2, Header>,
  route: Maybe<&2, String>, body_length: U32) -> Api.Attributes:
  match config:
    case Config{known_methods, sensitive_query_keys, request_headers, response_headers, body_sizes}:
      Api.Attributes.from_list(List.concat(&2, Api.Attribute, [
        Method.attributes(Method.normalize(known_methods, method)),
        Target.attributes(sensitive_query_keys, Target.split(target)),
        [Api.Attribute{Semconv.Url.scheme(), Api.StringValue{Server.scheme(headers)}}],
        Server.address_attributes(headers),
        Attribute.optional(Semconv.Client.address(), Server.client_address(headers)),
        Attribute.optional(Semconv.UserAgent.original(), Server.user_agent(headers)),
        Attribute.optional(Semconv.Http.route(), route),
        Capture.headers(Semconv.Http.Request.header(), request_headers, headers),
        Capture.body_size(Semconv.Http.Request.Body.size(), body_sizes, headers, body_length)]))

# The attributes of a server span at its end: `http.response.status_code`,
# `error.type` on 5xx, the captured response headers and the response body
# size when enabled (law server_response_literal).
def Server.response_attributes(config: Config, +status_code: U32, +headers: List<&2, Header>, body_length: U32) ->
  Api.Attributes:
  match config:
    case Config{known_methods, sensitive_query_keys, request_headers, response_headers, body_sizes}:
      Api.Attributes.from_list(List.concat(&2, Api.Attribute, [
        [Response.status_attribute(status_code)],
        Attribute.optional(Semconv.Error.type(), Server.error_type(status_code)),
        Capture.headers(Semconv.Http.Response.header(), response_headers, headers),
        Capture.body_size(Semconv.Http.Response.Body.size(), body_sizes, headers, body_length)]))

# The attributes of a client span at its start: `http.request.method` and
# the original method, `url.full` redacted, `server.address` and
# `server.port` from the URL, the captured request headers and the request
# body size when enabled (law client_request_literal).
def Client.request_attributes(config: Config, method: String, +url: String, +headers: List<&2, Header>,
  body_length: U32) -> Api.Attributes:
  match config:
    case Config{known_methods, sensitive_query_keys, request_headers, response_headers, body_sizes}:
      Api.Attributes.from_list(List.concat(&2, Api.Attribute, [
        Method.attributes(Method.normalize(known_methods, method)),
        [Api.Attribute{Semconv.Url.full(), Api.StringValue{Url.full(sensitive_query_keys, url)}}],
        Client.server_attributes(url),
        Capture.headers(Semconv.Http.Request.header(), request_headers, headers),
        Capture.body_size(Semconv.Http.Request.Body.size(), body_sizes, headers, body_length)]))

# A response gives its status code, `error.type` from 400 on, the captured
# response headers and the body size when enabled; a transport failure gives
# `error.type` alone.
def Client.response_attributes.of(outcome: Outcome, response_headers: List<&2, String>, body_sizes: Bool,
  +headers: List<&2, Header>, body_length: U32) -> List<&2, Api.Attribute>:
  match outcome:
    case Responded{+status_code}:
      List.concat(&2, Api.Attribute, [
        [Response.status_attribute(status_code)],
        Attribute.optional(Semconv.Error.type(), Client.error_type.responded(status_code)),
        Capture.headers(Semconv.Http.Response.header(), response_headers, headers),
        Capture.body_size(Semconv.Http.Response.Body.size(), body_sizes, headers, body_length)])
    case Failed{error_type, description}:
      [Api.Attribute{Semconv.Error.type(), Api.StringValue{error_type}}]

# The attributes of a client span at its end, from how the call ended (law
# client_response_literal).
def Client.response_attributes(config: Config, outcome: Outcome, headers: List<&2, Header>, body_length: U32) ->
  Api.Attributes:
  match config:
    case Config{known_methods, sensitive_query_keys, request_headers, response_headers, body_sizes}:
      Api.Attributes.from_list(Client.response_attributes.of(outcome, response_headers, body_sizes, headers, body_length))
