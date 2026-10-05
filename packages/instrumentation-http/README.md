# bend-telemetry-instrumentation-http

OpenTelemetry HTTP instrumentation for Bend: spans and context propagation
for HTTP on [bend-kit](https://github.com/paymog/bend-kit). Its contract is
the HTTP instrumentation specification,
[issue #27](https://github.com/LucasGois1/bend-telemetry/issues/27), and the
OpenTelemetry semantic conventions for HTTP spans at v1.44.0, whose attribute
names and values come from the semconv package
([packages/semconv](../semconv/README.md)); the terms are those of the
repository's glossary, [CONTEXT.md](../../CONTEXT.md): instrumentation, route,
attribute, status, lane. This is a community project; it is not part of, or
endorsed by, the OpenTelemetry project.

**Status: in development.** This package holds the pure core of the
instrumentation ([#34](https://github.com/LucasGois1/bend-telemetry/issues/34)):
given a method, a raw request target or a full URL, a header list and a
status code or a transport failure, it answers the span name, the attributes
and the status that the conventions require, with credentials and sensitive
query values redacted; and its configuration, from code and from
`OTEL_INSTRUMENTATION_HTTP_KNOWN_METHODS`. The server and client wrappers
over bend-kit-http, which start the spans and propagate context, follow in
[#35](https://github.com/LucasGois1/bend-telemetry/issues/35) and
[#36](https://github.com/LucasGois1/bend-telemetry/issues/36), and nothing is
published on BendHub yet.

The package has two modules, both imported by the package's BendHub name and
version, never by a relative path:

```bend
import Base
import bend-telemetry-api@0.1.0.0/api.bend as Api
import bend-telemetry-instrumentation-http@0.1.0.0/core.bend as HttpCore
import bend-telemetry-instrumentation-http@0.1.0.0/host.bend as HttpHost
```

- [core.bend](core.bend), `HttpCore` below, is the pure core: every type and
  every derivation rule, and the configuration with `Config.from_variables`.
  It performs no effect and imports nothing of bend-kit, so the package's
  laws import it alone and the rules are proved without the HTTP client.
- [host.bend](host.bend), `HttpHost` below, adds the effect on the host:
  `HttpHost.Config.from_env` reads the environment. It is the package's
  entry on the hub, since it imports everything the package publishes.

The results are values of the API: `Api.Attributes` collections and
`Api.Attribute` lists with `Api.AttributeValue` values, and the span status
as `Api.Status`. The repository's
independent consumers, [tests/consumer/http_core.bend](../../tests/consumer/http_core.bend)
and [tests/consumer/http_config.bend](../../tests/consumer/http_config.bend),
are complete programs over these definitions, with their exact output
beside them.

## Contents

- [Headers](#headers): the header list the core reads, and the bridge from
  bend-kit's header map
- [Methods](#methods): the known methods and `http.request.method`
- [Span names](#span-names)
- [Status and `error.type`](#status-and-errortype): both tables
- [`url.full`](#urlfull): credentials and sensitive query values redacted
- [Server spans](#server-spans): `url.path`, `url.query`, `url.scheme`,
  `server.address`, `server.port`, `client.address`, `user_agent.original`
- [Client spans](#client-spans): `server.address` and `server.port` from
  the URL
- [Header capture and body sizes](#header-capture-and-body-sizes)
- [Configuration](#configuration): `Config` and its variable
- [What the wrappers add](#what-the-wrappers-add)
- [Lanes](#lanes)
- [Laws and proofs](#laws-and-proofs)
- [Writing Bend with the package](#writing-bend-with-the-package)

## Headers

The core reads headers as a list of `HttpCore.Header{name: String, value:
String}`, one per field line in arrival order. Every lookup compares names
without regard to case (RFC 9110, section 5.1), so `Host`, `host` and the
lowercase names bend-kit hands over are one header.

| Definition | Answers |
| --- | --- |
| `Headers.first(headers, name) -> Maybe<&2, String>` | the value of the first header with the name, if any |
| `Headers.values(headers, name) -> List<&2, String>` | the values of every header with the name, in arrival order |
| `Headers.from_map(map: Map<&2, List<&2, String>>) -> List<&2, Header>` | the header list of a header map with one list of values per name, as bend-kit-http's `Req` and `Res` hold their headers: one header per value |

Status codes, ports and body sizes are `U32`, as bend-kit-http holds them.

## Methods

The conventions define the known methods as those of RFC 9110, PATCH and
QUERY, compared exactly and case-sensitively; any other method is `_OTHER`,
with the text as sent kept in `http.request.method_original`; and the known
set is overridable as a full replacement, never an addition.

| Definition | Answers |
| --- | --- |
| `Method.known_defaults() -> List<&2, String>` | `CONNECT`, `DELETE`, `GET`, `HEAD`, `OPTIONS`, `PATCH`, `POST`, `PUT`, `TRACE`, `QUERY`, from the semconv package's enumeration |
| `Method.normalize(known: List<&2, String>, method: String) -> Method` | `KnownMethod{method}` when the text is exactly one of `known`, `OtherMethod{method}` otherwise |
| `Method.name(method) -> String` | the value of `http.request.method`: the known name, or `_OTHER` |
| `Method.original(method) -> Maybe<&2, String>` | the value of `http.request.method_original`: the original text of an `_OTHER` method, none for a known one |
| `Method.attributes(method) -> List<&2, Api.Attribute>` | `http.request.method`, and `http.request.method_original` only when the method is `_OTHER` |

Under the defaults, `GET` is known, and `GeT`, `get` and `ACL` are `_OTHER`;
under the override `["ACL"]`, `ACL` is known and `GET` is `_OTHER` (laws
`method_listed`, `method_unlisted`, `method_literal`).

## Span names

`Span.name(method: Method, route: Maybe<&2, String>) -> String` follows the
conventions' "Name" section: `{method} {route}` when a route is known,
`{method}` otherwise, where `{method}` is the known method or `HTTP` when the
method is `_OTHER`. A path never names a span: the route is the
low-cardinality pattern the server matched, and the wrappers take it from a
route slot the application fills.

| Method | Route | Span name |
| --- | --- | --- |
| `KnownMethod{"GET"}` | `Some{"/users/:id"}` | `GET /users/:id` |
| `KnownMethod{"GET"}` | `None{}` | `GET` |
| `OtherMethod{"GeT"}` | `Some{"/users/:id"}` | `HTTP /users/:id` |
| `OtherMethod{"GeT"}` | `None{}` | `HTTP` |

## Status and `error.type`

The core answers the API's span status, `Api.Status`: `Api.Unset{}`, or
`Api.Error{description}` with the description empty when the status code
already says the reason, as the conventions ask. The HTTP rules never answer
`Api.Ok{}`; the wrappers set the status on the span with
`Api.Span.set_status`.

A client call ends in an `HttpCore.Outcome`: `Responded{status_code: U32}`,
or `Failed{error_type: String, description: String}` for a transport failure
named by a low-cardinality identifier (the client wrapper names bend-kit's
`Http.Err` variant, such as `ErrDns`) and described by its message, empty
when there is none.

| Response | Server span: `Server.status(code)`, `Server.error_type(code)` | Client span: `Client.status(outcome)`, `Client.error_type(outcome)` |
| --- | --- | --- |
| 1xx, 2xx, 3xx | `Api.Unset{}`, none | `Api.Unset{}`, none |
| 4xx | `Api.Unset{}`, none | `Api.Error{""}`, the code as text (`"404"`) |
| 5xx | `Api.Error{""}`, the code as text (`"503"`) | `Api.Error{""}`, the code as text |
| transport failure | not applicable: the server always answers | `Api.Error{description}`, the failure's identifier (`"ErrDns"`) |

The boundaries are universal laws (`server_status_low`, `server_status_error`,
`client_status_low`, `client_status_error`, `client_status_failed`, and the
`error_type` laws beside them); `status_literal` and `error_type_literal`
are the tables on literal codes. `error.type` is never set on success.
`Response.status_attribute(code)` is the `http.response.status_code`
attribute, an integer.

## `url.full`

`Url.full(keys: List<&2, String>, url: String) -> String` is the value of
`url.full` for a client's URL text, in two steps:

1. The userinfo of the authority, everything between `//` and the last `@`
   before the first `/`, `?` or `#`, is replaced by `REDACTED:REDACTED`,
   before anything else is read, so that a password never leaves the
   process: `https://user:secret@example.com/path?x=1` becomes
   `https://REDACTED:REDACTED@example.com/path?x=1`, and so does a URL with
   a user alone or a scheme-relative one. An `@` outside the authority, as
   in `?email=a@b.example`, is kept.
2. In the query, from the first `?` to the `#` or the end, the value of
   every parameter whose key is one of `keys`, compared exactly and
   case-sensitively, is replaced by `REDACTED`; the key stays, a key without
   `=` has no value and stays whole, and every other parameter and the
   fragment are untouched: `?sigma=1&sig=2&Signature2=3` becomes
   `?sigma=1&sig=REDACTED&Signature2=3`.

The keys are `Config.sensitive_query_keys(config)`: by default the five the
conventions list at v1.44.0, `X-Amz-Signature`, `X-Amz-Credential`,
`X-Amz-Security-Token`, `sig` and `X-Goog-Signature`, and the two of their
earlier versions, `AWSAccessKeyId` and `Signature`, which SigV2 presigned
URLs still carry; the list is a full override. `Query.redact(keys, query)`
is the second step alone, which `url.query` shares. Laws
`url_full_credentials`, `url_full_sensitive_keys`,
`url_full_key_without_value`, `url_full_prefix_key` and `url_full_override`.

## Server spans

`Server.request_attributes(config, method, target, headers, route, body_length)`
answers the attributes of a server span at its start, in the order the
conventions list the ones that matter for sampling first, and
`Server.response_attributes(config, status_code, headers, body_length)` the
attributes at its end. Each rule is a definition of its own:

| Attribute | Definition | Rule |
| --- | --- | --- |
| `http.request.method`, `http.request.method_original` | `Method.attributes(Method.normalize(known, method))` | [Methods](#methods) |
| `url.path`, `url.query` | `Target.split(target) -> Target{path, query}`, `Target.attributes(keys, target)` | the raw request target, in origin form, split at its first `?`: the path, and the query when there is a `?` (empty after a bare `?`), redacted as [`url.full`](#urlfull) redacts a query |
| `url.scheme` | `Server.scheme(headers) -> String` | the `proto` of `Forwarded`, else `X-Forwarded-Proto`, lowercased, else `http`: bend-kit's server speaks plain HTTP |
| `server.address`, `server.port` | `Server.address_attributes(headers)` | the `host` of `Forwarded`, else `X-Forwarded-Host`, else `Host`, parsed with `HostPort.parse`: a bracketed IPv6 address loses its brackets and may carry `:port`; any other host has its port after its only colon. No `server.port` when the host carries none; nothing without a host |
| `client.address` | `Server.client_address(headers) -> Maybe<&2, String>` | the `for` of `Forwarded`, else the first address of `X-Forwarded-For`, without quotes, brackets or port; absent without them, since bend-kit exposes no peer address |
| `user_agent.original` | `Server.user_agent(headers) -> Maybe<&2, String>` | the `User-Agent` header |
| `http.route` | the `route` argument | the route the wrapper's route slot answered, if any |
| `http.request.header.<name>` | `Capture.headers(Semconv.Http.Request.header(), names, headers)` | [Header capture](#header-capture-and-body-sizes) |
| `http.request.body.size` | `Capture.body_size(Semconv.Http.Request.Body.size(), enabled, headers, body_length)` | when enabled: `Content-Length`, else the body's length |
| `http.response.status_code` | `Response.status_attribute(status_code)` | the code, as an integer |
| `error.type` | `Server.error_type(status_code)` | [Status](#status-and-errortype) |
| `http.response.header.<name>`, `http.response.body.size` | as the request's, with the response prefixes | |

`Forwarded` is read element by element and parameter by parameter (RFC
7239: elements separated by `,`, parameters by `;`, names compared without
regard to case, values unquoted); `Forwarded.parameter(headers, name)` is
the first value of a parameter across every `Forwarded` header. The
`Forwarded` parameters win over the `X-Forwarded-*` headers, and those over
`Host`. Of the `X-Forwarded-*` values, the first comma-separated item is read.

For a request `GET /users/42?sig=abc&x=1` through a proxy writing
`Forwarded: for=192.0.2.60;proto=https;host="example.com:8443"` and
`User-Agent: curl/8.4.0`, with the route `/users/:id`, the attributes are
`http.request.method=GET`, `url.path=/users/42`, `url.query=sig=REDACTED&x=1`,
`url.scheme=https`, `server.address=example.com`, `server.port=8443`,
`client.address=192.0.2.60`, `user_agent.original=curl/8.4.0` and
`http.route=/users/:id`, in that order (laws `server_scheme`,
`server_address_port`, `client_address`, `user_agent`, `target_split`,
`target_query_redacted`, `server_request_literal`, `server_response_literal`).

## Client spans

`Client.request_attributes(config, method, url, headers, body_length)`
answers the attributes of a client span at its start, and
`Client.response_attributes(config, outcome, headers, body_length)` the
attributes at its end: the status code and `error.type` of a response, the
captured response headers and the body size when enabled, or `error.type`
alone for a transport failure, which has no response.

| Attribute | Definition | Rule |
| --- | --- | --- |
| `http.request.method`, `http.request.method_original` | `Method.attributes(Method.normalize(known, method))` | [Methods](#methods) |
| `url.full` | `Url.full(keys, url)` | [`url.full`](#urlfull), on the URL as the application gave it: one span per bend-kit call, so the original URL before any redirect |
| `server.address`, `server.port` | `Client.server_attributes(url)` | the host of the URL's authority after any userinfo, the brackets of an IPv6 address dropped, and its port, or the scheme's default when the URL names none: 80 for `http`, 443 for `https`. A scheme without a default gives the address alone; a URL without an authority gives nothing |
| `http.request.header.<name>`, `http.request.body.size`, `http.response.*`, `error.type` | as on the [server](#server-spans) | |

`Url.scheme(url)`, `Url.host_port(url)` and `Url.default_port(scheme)` are
the parts. For `https://user:secret@api.example.com/v1/items?sig=abc&page=2`
sent with the method `get`, the attributes are `http.request.method=_OTHER`,
`http.request.method_original=get`,
`url.full=https://REDACTED:REDACTED@api.example.com/v1/items?sig=REDACTED&page=2`,
`server.address=api.example.com` and `server.port=443` (laws
`client_server_attributes`, `client_request_literal`,
`client_response_literal`).

## Header capture and body sizes

Capture is opt-in and explicit, as the conventions require: nothing is
captured by default.

- `Capture.headers(prefix, names, headers)`: for each configured name in
  order, lowercased, the attribute `<prefix>.<name>` with the header's
  values as a string array, one per field line, when the message carries
  the header; none when it does not. The prefix is the semconv package's
  `Http.Request.header()` or `Http.Response.header()`, so `Content-Type`
  configured and sent as `application/json` gives
  `http.request.header.content-type=["application/json"]` (laws
  `capture_literal`, `capture_nothing`).
- `Body.size(headers, length) -> U32`: the `Content-Length` header when it
  is a number, else the length of the body the wrapper measured;
  `Capture.body_size(key, enabled, headers, length)` is the attribute under
  `Http.Request.Body.size()` or `Http.Response.Body.size()` when sizes are
  captured (laws `body_size_declared`, `body_size_length`).

## Configuration

`HttpCore.Config` is the configuration of the instrumentation: a closed
`Data` record. Build it with `Config.default()` or read it from the
environment with `HttpHost.Config.from_env()`, read it with its readers and
change it with its setters, never by constructing or matching it, so that a
field added later breaks no caller. Three sources compose, each winning over
the one before: the defaults, the environment and the setters.

| Field | Reader | Setter | Default |
| --- | --- | --- | --- |
| The known methods; any other is `_OTHER` | `Config.known_methods -> List<&2, String>` | `Config.with_known_methods(config, methods)` | `Method.known_defaults()` |
| The query keys whose values `url.full` and `url.query` redact | `Config.sensitive_query_keys -> List<&2, String>` | `Config.with_sensitive_query_keys(config, keys)` | the seven keys of [`url.full`](#urlfull) |
| The request headers to capture, by name | `Config.request_headers -> List<&2, String>` | `Config.with_request_headers(config, names)` | `Nil{}` |
| The response headers to capture, by name | `Config.response_headers -> List<&2, String>` | `Config.with_response_headers(config, names)` | `Nil{}` |
| Whether body sizes are captured | `Config.body_sizes -> Bool` | `Config.with_body_sizes(config, flag)` | `False{}` |

Each setter is read back by its reader whatever the configuration held, so a
setter applied after `from_env` wins over the environment (law
`config_setters_read_back`); the lists are full replacements.

`HttpHost.Config.from_env()` reads the one variable the conventions name:

| Variable | Sets | Default | Rule |
| --- | --- | --- | --- |
| `OTEL_INSTRUMENTATION_HTTP_KNOWN_METHODS` | `Config.known_methods` | the conventions' known methods | a comma-separated list of case-sensitive methods, each trimmed of surrounding spaces, empty items dropped; a full override of the defaults. An empty value, or one that names no method, is unset |

It never fails: an unset variable leaves the defaults.
`HttpCore.Config.from_variables(variables)` is its pure core: it takes a
`List<&2, HttpCore.Variable>` of `Variable{name, value}` and answers the
configuration, so that laws and tests state the reading on literal
environments; `Env.read_methods(text)` is the list parser (laws
`methods_literal`, `config_unset_is_default`, `config_empty_is_unset`,
`config_from_variables_literal`). The instrumentation depends on the API and
the semconv package, not on the SDK, as OpenTelemetry requires of
instrumentation libraries, so the parsing rules of the SDK's `OTEL_*`
variables are implemented here for this one variable: an empty value is
unset, and a list is split on commas.

```bend
def configure() -> IO(HttpCore.Config):
  do IO<HttpCore.Config>:
    +config : HttpCore.Config <- HttpHost.Config.from_env()
    return HttpCore.Config.with_request_headers(config, ["Content-Type"])
```

## What the wrappers add

The core computes; the wrappers of [#35](https://github.com/LucasGois1/bend-telemetry/issues/35)
and [#36](https://github.com/LucasGois1/bend-telemetry/issues/36) import
bend-kit-http and act: the server wrapper starts a `SERVER` span per request
named by `Span.name` and the route slot, extracts the context from the
headers with the provider's propagator, sets `Server.request_attributes` at
creation and `Server.response_attributes` and `Server.status` before the end;
the client combinator starts a `CLIENT` span, injects the context, calls the
bend-kit function the application chose, and sets `Client.response_attributes`
and `Client.status` from the outcome. They hand the core bend-kit's headers
through `Headers.from_map`, measure body lengths, and map `Http.Err` to the
failure's identifier. The limits of bend-kit stand in the core's rules:
no peer address, so `client.address` needs a forwarded header; no protocol
version, so `network.protocol.version` is never set; one span per bend-kit
call, redirects and retries inside it, so `url.full` is the original URL and
`http.request.resend_count` is not set.

## Lanes

The core, `core.bend`, performs no effect and runs wherever Bend runs:
natively, in-process on the JavaScript lane (the Bun embedded in the pinned
compiler) and under node; the consumer `tests/consumer/http_core.bend` runs
on all three in [tests/lanes/programs.txt](../../tests/lanes/programs.txt).
`HttpHost.Config.from_env` reads a variable that may be unset, and reading an
unset variable loads `bun:ffi`, which node does not have: a program that
calls it runs natively and in-process with `./bend file.bend`, never as a
`-o file.js` build under node, as `tests/consumer/http_config.bend` does.
`Config.from_variables` on a list a program holds is the way to configure
under node.

## Laws and proofs

[LAWS.bend](LAWS.bend) states the package's claims and
[PROOF.bend](PROOF.bend) proves them; `./scripts/validate.sh` runs
`./bend packages/instrumentation-http/PROOF.bend --check-only` against the
local hub, which serves the API and the semconv package the core imports,
and the check prints `ALL PROOFS CHECK` only when every law holds and nothing
the proofs import relies on `@unsafe` or foreign code. The laws import
`core.bend` alone, never `host.bend`.

The universal laws say that a method among the known methods is known and
any other is `_OTHER` with its original text, whatever the known set; that
span names are `{method} {route}`, `{method}` and `HTTP`; that a server span
is unset below 500 and an error from 500 on, a client span unset below 400
and an error from 400 on and on every transport failure, with `error.type`
the code as text exactly when the status is an error and the failure's
identifier on a failure; that nothing is captured without a configured name
and that a body without `Content-Length` has its own length; and that each
setter is read back and an empty variable is unset, whatever the
configuration and the environment. The literal laws state the rules on text,
which the checker compares character by character: every sensitive key,
credentials in each position, a key without a value and a key that extends
another, target splitting, each header derivation with and without forwarded
headers, the client URL's address and default ports, header capture, the
variable's list syntax and the whole attribute collections of a server span
and a client span. Each law quotes the section of the conventions it
enforces.

## Writing Bend with the package

`bend guide` explains the language; these points come up with this package:

- Every type of this package is `Data`: a header list, a configuration or a
  method used twice is bound with `+`, as in `+known : List<&2, String> =
  HttpCore.Method.known_defaults()`.
- A `match` inspects a parameter or a variable bound by a pattern, never a
  computed value: give the result of `HttpCore.Server.client_address` or
  `HttpCore.Client.error_type` to a helper `def` that matches on its
  parameter, or print it with `Maybe.show(~&2, ~String, ~(text => text), value)`.
- Status codes, ports and sizes are `U32`, as bend-kit-http holds them;
  `Api.Int64.from_u32` is how they become attribute values, and `U32.show`
  how a code becomes `error.type`.
- The attribute names are the semconv package's: write
  `Semconv.Http.Request.header()` for a capture prefix, never the text.
