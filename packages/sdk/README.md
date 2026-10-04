# bend-telemetry-sdk

The OpenTelemetry tracing SDK for Bend: the package that an application
installs to record spans. Its contract is the tracing SDK specification,
[issue #11](https://github.com/LucasGois1/bend-telemetry/issues/11); the
terms are those of the repository's glossary,
[CONTEXT.md](../../CONTEXT.md): diagnostic, sampler, span processor, span
limits, resource, exporter, export budget, shutdown. This is a community
project; it is not part of, or endorsed by, the OpenTelemetry project.

**Status: in development.** This package holds its configuration and its
diagnostics ([#12](https://github.com/LucasGois1/bend-telemetry/issues/12)):
the `Config` record with the specification's defaults, its setters,
`Config.from_env` with the parsing rules of the `OTEL_*` variables,
`Diagnostic` with the stderr and the silent reporters, and the percent
decoder that the resource's environment detector will use. The samplers, the
resource, the span pipeline, the exporters and the provider follow in later
tickets, and nothing is published on BendHub yet.

The package has two modules, both imported by the package's BendHub name and
version, never by a relative path:

```bend
import Base
import bend-telemetry-api@0.1.0.0/api.bend as Api
import bend-telemetry-sdk@0.1.0.0/sdk.bend as Sdk
import bend-telemetry-sdk@0.1.0.0/host.bend as Host
```

- [sdk.bend](sdk.bend), `Sdk` below, is the pure core: every type, the
  configuration, the parsers, the diagnostics as data and the decoder. It
  performs no effect, and the package's laws import it alone.
- [host.bend](host.bend), `Host` below, adds the effects on the host:
  `Host.Config.from_env` reads the environment and the reporters write to
  stderr. It is the package's entry on the hub, since it imports everything
  the package publishes.

The repository's independent consumer of the SDK,
[tests/consumer/sdk_config.bend](../../tests/consumer/sdk_config.bend), is a
complete program over these definitions, run under the variables of
[sdk_config.env](../../tests/consumer/sdk_config.env) beside it, with its
exact output in [sdk_config.expected.txt](../../tests/consumer/sdk_config.expected.txt).

## Contents

- [Configuration](#configuration): `Config`, its defaults, readers and
  setters, and `Configured`
- [Environment variables](#environment-variables): every supported variable
  with its default and its parsing rule
- [Parsing rules](#parsing-rules): the kinds of value, empty values, invalid
  values and their diagnostics
- [Diagnostics](#diagnostics): `Level`, `Diagnostic` and the reporters
- [Percent decoding](#percent-decoding): `Percent.decode`
- [Lanes](#lanes)
- [Laws and proofs](#laws-and-proofs)
- [Writing Bend with the package](#writing-bend-with-the-package)

## Configuration

`Sdk.Config` is the configuration of a tracer provider: a closed `Data`
record. Build it with `Sdk.Config.default()` or read it from the environment
with `Host.Config.from_env()`, read it with its readers and change it with
its setters, never by constructing or matching it, so that a field added
later breaks no caller. Three sources compose, each winning over the one
before: the defaults, the environment and the setters (spec #11, user story
3).

| Field | Reader | Setter | Default |
| --- | --- | --- | --- |
| Whether the SDK is disabled: a disabled provider records nothing and starts no computation | `Config.disabled -> Bool` | `Config.with_disabled(config, flag)` | `False{}` |
| The level below which diagnostics are dropped | `Config.level -> Level` | `Config.with_level(config, level)` | `Info{}` |
| The resource the application supplies in code, merged last | `Config.resource -> Resource` | `Config.with_resource(config, resource)` | `Resource.empty()` |
| The service name of `OTEL_SERVICE_NAME` | `Config.service_name -> Maybe<&2, String>` | `Config.with_service_name(config, name)` | `None{}` |
| The raw text of `OTEL_RESOURCE_ATTRIBUTES`, for the resource's environment detector | `Config.resource_attributes -> Maybe<&2, String>` | `Config.with_resource_attributes(config, text)` | `None{}` |
| The selected sampler | `Config.sampler -> SamplerSelection` | `Config.with_sampler(config, selection)` | `ParentBasedAlwaysOn{}` |
| The raw text of `OTEL_TRACES_SAMPLER_ARG`, for the sampler | `Config.sampler_arg -> Maybe<&2, String>` | `Config.with_sampler_arg(config, text)` | `None{}` |
| The span processors configured in code; empty for the standard pipeline | `Config.processors -> List<&2, ProcessorConfig>` | `Config.with_processors(config, processors)` | `Nil{}` |
| The options of the standard pipeline's batch processor | `Config.batch -> BatchOptions` | `Config.with_batch(config, options)` | `BatchOptions.default()` |
| The span limits the provider gives every span | `Config.span_limits -> Api.SpanLimits` | `Config.with_span_limits(config, limits)` | `Api.SpanLimits.default()` |
| The exporter of the standard pipeline | `Config.exporter -> ExporterSelection` | `Config.with_exporter(config, selection)` | `ExternalExporter{"otlp"}` |
| The `OTEL_EXPORTER_OTLP_*` values, as text under their variable names | `Config.otlp -> List<&2, Variable>`, `Config.otlp_value(config, name) -> Maybe<&2, String>` | `Config.with_otlp(config, values)`, `Config.with_otlp_value(config, name, value)` | `Nil{}` |
| The milliseconds a shutdown waits for the pipeline, absent for no limit | `Config.shutdown_timeout -> Maybe<&2, Nat>` | `Config.with_shutdown_timeout(config, timeout)` | `Some{10000n}` |
| The hexadecimal digits of precision of the ratio sampler's threshold | `Config.threshold_precision -> Nat` | `Config.with_threshold_precision(config, digits)` | `4n` |

The defaults are the specification's (law `config_default`). The shutdown
timeout has no variable; it defaults to 10 s, one export budget, the OTLP
exporter's timeout of [#19](https://github.com/LucasGois1/bend-telemetry/issues/19),
as the graceful shutdown specification
([#38](https://github.com/LucasGois1/bend-telemetry/issues/38)) says.

The types the fields hold:

- `Level`: `Debug{}`, `Info{}`, `Warn{}`, `Error{}`; see
  [Diagnostics](#diagnostics).
- `Resource{attributes: Api.Attributes, schema_url: String}`: attributes
  plus a schema URL, built with `Resource.empty()` or
  `Resource.create(attributes, schema_url)` and read with
  `Resource.attributes` and `Resource.schema_url`. The merge and the
  detectors come with the resource ticket.
- `SamplerSelection`: `AlwaysOn{}`, `AlwaysOff{}`, `TraceIdRatio{}`,
  `ParentBasedAlwaysOn{}`, `ParentBasedAlwaysOff{}` and
  `ParentBasedTraceIdRatio{}`, the six samplers this SDK provides;
  `SamplerSelection.show` answers the name `OTEL_TRACES_SAMPLER` takes. The
  sampler ticket builds the sampler from the selection and the argument.
- `ExporterSelection`: `ConsoleExporter{}`, `NoExporter{}` or
  `ExternalExporter{name}`, an exporter named as `OTEL_TRACES_EXPORTER`
  names it; `ExporterSelection.show` answers the name. Provider construction
  resolves a name against the exporter the provider was built with, and
  reports a name it cannot serve, which then resolves to none.
- `BatchOptions{queue_size, schedule_delay, export_timeout, batch_size}`: the
  most spans the queue holds, the milliseconds between scheduled exports, the
  export budget in milliseconds (`None{}` for no limit) and the most spans
  per export; `BatchOptions.default()` is 2048, 5000, `Some{30000n}` and 512
  (law `batch_default`), and each field has a reader and a setter
  (`BatchOptions.with_queue_size` and so on).
- `ProcessorConfig`: `SimpleProcessor{exporter}` or
  `BatchProcessor{options, exporter}`, a span processor configured in code
  with the exporter it sends to. When `Config.processors` is empty, the
  provider builds the standard pipeline: one batch processor with
  `Config.batch` and `Config.exporter`.
- `Variable{name, value}`: one variable of an environment and its text.

`SpanLimits.with_attribute_count`, `with_attribute_value_length`,
`with_event_count`, `with_link_count`, `with_attribute_per_event_count` and
`with_attribute_per_link_count` build the API's span limits record with one
limit changed (`Some{count}`, or `None{}` for no limit), since the API has
readers and no setters.

A configuration read from the environment comes as `Sdk.Configured`, with
`Configured.config(configured)` and `Configured.diagnostics(configured)`: the
configuration and the diagnostics the reading produced, one per invalid
value, for the reporter to print. An application reads the environment, pins
what must not change, and reports the diagnostics at the level it ends with:

```bend
def configure() -> IO(Sdk.Config):
  do IO<Sdk.Config>:
    +configured : Sdk.Configured <- Host.Config.from_env()
    +config : Sdk.Config = Sdk.Config.with_sampler(Sdk.Configured.config(configured), Sdk.AlwaysOn{})
    Host.Reporter.each(~Host.Reporter.stderr, Sdk.Config.level(config), Sdk.Configured.diagnostics(configured))
    return config
```

Each setter is read back by its reader whatever the configuration held, so
a setter applied after `from_env` wins over the environment (laws
`setters_read_back` and `programmatic_wins`).

## Environment variables

`Host.Config.from_env()` reads every variable below, applies the ones that
are set and not empty to the defaults, in this order, and answers the
configuration with its diagnostics. It never fails: an unset or empty
variable changes nothing, and an invalid value is reported once and leaves
the default (the rules are under [Parsing rules](#parsing-rules)).
`Sdk.Config.variable_names()` is this list, in this order.

| Variable | Sets | Default | Rule |
| --- | --- | --- | --- |
| `OTEL_SDK_DISABLED` | `Config.disabled` | `false` | Boolean |
| `OTEL_LOG_LEVEL` | `Config.level` | `info` | enumeration: `debug`, `info`, `warn`, `error` |
| `OTEL_SERVICE_NAME` | `Config.service_name` | unset | text |
| `OTEL_RESOURCE_ATTRIBUTES` | `Config.resource_attributes` | unset | text, kept raw for the resource's environment detector, which decodes it with `Percent.decode` |
| `OTEL_TRACES_SAMPLER` | `Config.sampler` | `parentbased_always_on` | enumeration: `always_on`, `always_off`, `traceidratio`, `parentbased_always_on`, `parentbased_always_off`, `parentbased_traceidratio`; `jaeger_remote`, `parentbased_jaeger_remote` and `xray` are reported as samplers this SDK does not provide |
| `OTEL_TRACES_SAMPLER_ARG` | `Config.sampler_arg` | unset | text, kept raw for the sampler |
| `OTEL_TRACES_EXPORTER` | `Config.exporter` | `otlp` | `console`, `none`, or one name of an external exporter, resolved when the provider is built; a list of names is reported |
| `OTEL_BSP_SCHEDULE_DELAY` | `Config.batch`, `schedule_delay` | `5000` | duration |
| `OTEL_BSP_EXPORT_TIMEOUT` | `Config.batch`, `export_timeout` | `30000` | timeout: `0` is no limit |
| `OTEL_BSP_MAX_QUEUE_SIZE` | `Config.batch`, `queue_size` | `2048` | size |
| `OTEL_BSP_MAX_EXPORT_BATCH_SIZE` | `Config.batch`, `batch_size` | `512` | size |
| `OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT` | `Config.span_limits`, `attribute_value_length` | no limit | count; `OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT`, when set and valid, wins over it |
| `OTEL_ATTRIBUTE_COUNT_LIMIT` | `Config.span_limits`: `attribute_count`, `attribute_per_event_count` and `attribute_per_link_count` | `128` | count, for every record; the specific variable of each field, when set and valid, wins over it for that field |
| `OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT` | `Config.span_limits`, `attribute_value_length` | no limit | count; wins over the general value length |
| `OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT` | `Config.span_limits`, `attribute_count` | `128` | count; wins over the general count for a span's attributes |
| `OTEL_SPAN_EVENT_COUNT_LIMIT` | `Config.span_limits`, `event_count` | `128` | count |
| `OTEL_SPAN_LINK_COUNT_LIMIT` | `Config.span_limits`, `link_count` | `128` | count |
| `OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT` | `Config.span_limits`, `attribute_per_event_count` | `128` | count; wins over the general count for an event's attributes |
| `OTEL_LINK_ATTRIBUTE_COUNT_LIMIT` | `Config.span_limits`, `attribute_per_link_count` | `128` | count; wins over the general count for a link's attributes |
| `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_INSECURE`, `OTEL_EXPORTER_OTLP_CERTIFICATE`, `OTEL_EXPORTER_OTLP_CLIENT_KEY`, `OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE`, `OTEL_EXPORTER_OTLP_HEADERS`, `OTEL_EXPORTER_OTLP_COMPRESSION`, `OTEL_EXPORTER_OTLP_TIMEOUT`, `OTEL_EXPORTER_OTLP_PROTOCOL`, and each with `_TRACES_` in place of the second underscore after `OTLP` (`OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` and so on) | `Config.otlp`, under the variable's name | unset | text, kept raw: the OTLP exporter package gives each its meaning and reads the traces-specific variable before the general one |

The general attribute limits apply per record, as the specification defines
them and the Java SDK documents them: `OTEL_ATTRIBUTE_COUNT_LIMIT` bounds
the attributes of spans, events and links alike, and
`OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT` their values. A specific variable that is
set and valid wins over the general one for its own field, whatever the
order of the variables; one that is invalid is reported and leaves the
general value (law `specific_limits_win`). A limit from the environment is
always a bound: no variable sets a limit to "no limit".

`OTEL_PROPAGATORS` belongs to the propagation specification
([#26](https://github.com/LucasGois1/bend-telemetry/issues/26)); the OTLP
variables' meaning belongs to the OTLP exporter specification
([#19](https://github.com/LucasGois1/bend-telemetry/issues/19)).

## Parsing rules

The rules are those of the OpenTelemetry SDK environment variables
specification, applied to the text of each variable:

| Kind | Parser | Accepts | Refuses |
| --- | --- | --- | --- |
| Boolean | `Env.read_bool` | `true` in any case as true, `false` in any case as false | any other text (`yes`, `1`, `on`, a surrounding space) |
| count | `Env.read_count` | decimal digits from `0` to `2147483647`, leading zeros accepted | a sign, a point, an exponent, a space, letters, a separator, a value past the bound |
| size | `Env.read_size` | a count of at least `1` | `0` and what a count refuses |
| duration | `Env.read_duration` | a count, in milliseconds | a unit suffix, a fraction, what a count refuses |
| timeout | `Env.read_timeout` | a duration, where `0` means no limit (`None{}`) | what a duration refuses |
| enumeration | `Env.read_level`, `Env.read_sampler`, `Env.read_exporter` | the names of the enumeration, in any case | any other name |
| text | `Env.read_text` | any text | nothing |

Each parser answers `Done{value}` or `Fail{reason}` of
`Result<&2, &2, String, A>`, the reason being the text of its diagnostic.
Then:

- An empty value is an unset variable: it changes nothing and produces no
  diagnostic (law `empty_is_unset`).
- An invalid value leaves the default and produces exactly one diagnostic,
  a warning of the `config` component:
  `OTEL_SDK_DISABLED="yes" is not a Boolean (true or false); the value is
  ignored` (laws `invalid_boolean_once` and `invalid_literal`). The field
  keeps what it held: the default, or the value of a general limit.
- A size of zero is invalid: a queue or a batch holds at least one span.
  Provider construction checks the relation between programmatic sizes
  (spec #11, "Provider construction"); the environment never fails it.
- The largest accepted integer, 2147483647, is read at run time; the
  consumer prints it as a link count.

`Sdk.Config.from_variables(variables)` is the pure core of `from_env`: it
takes a `List<&2, Variable>` and answers the same `Configured`, so that
tests and laws state the reading on literal environments without touching
the process's environment. `from_env` reads `Config.variable_names()` with
`IO.get_env`, keeps the variables that are set and calls it.

## Diagnostics

A diagnostic is data: `Sdk.Diagnostic{level: Level, component: String,
message: String}`, read with `Diagnostic.level`, `Diagnostic.component` and
`Diagnostic.message`, and shown by `Diagnostic.show` as `[warn] config: the
message`. The levels order `Debug{}`, `Info{}`, `Warn{}`, `Error{}`;
`Level.show` gives the lowercase name `OTEL_LOG_LEVEL` takes, and
`Level.is_at_least(level, floor)` says whether a diagnostic at `level` is
reported under the configured `floor` (laws `level_reflexive` and
`level_order`).

A reporter is a definition from the configured level and a diagnostic to an
effect; the SDK's slots will take one as a template argument.

| Reporter | Does |
| --- | --- |
| `Host.Reporter.stderr(level, diagnostic)` | Writes one line to stderr, the fixed prefix `bend-telemetry-sdk ` followed by `Diagnostic.show`, when the diagnostic's level is at least the configured one; drops it otherwise |
| `Host.Reporter.silent(level, diagnostic)` | Drops every diagnostic, for tests |
| `Host.Reporter.each(~report, level, diagnostics)` | Reports each diagnostic of a list in turn with the reporter given as a template argument, such as `~Host.Reporter.stderr` |

Diagnostics never fail the application: a reporter answers `IO(Unit)` and
the configuration's reading answers them as data.

## Percent decoding

`OTEL_RESOURCE_ATTRIBUTES` carries percent-encoded values, as W3C Baggage
does. `Sdk.Percent.decode(text) -> Maybe<&2, String>` answers the decoded
text, or `None{}` when the text is not a well-formed encoding, in which case
the resource's environment detector discards the whole value with a warning
(spec #11, "Resource"):

- A `%XX` escape, with hexadecimal digits in either case, is one byte; any
  other character is kept as it is (`a%20b` is `a b`, `%2541` is `%41`).
- The bytes of a UTF-8 sequence of two, three or four bytes are reassembled
  into one character (`caf%C3%A9` is `café`, `%F0%9F%98%80` is one
  character, U+1F600).
- Refused: a percent sign not followed by two hexadecimal digits (`%`,
  `%4`, `%G1`, `%%41`), a lead byte without its continuation bytes (`%C3`),
  a continuation byte out of place (`%80`, `a%A9`, `%C3%28`), an overlong
  encoding (`%C0%AF`), a surrogate (`%ED%A0%80`) and a code point above
  U+10FFFF (`%F4%90%80%80`).

A text without a percent sign decodes to itself (law `decode_plain`); the
other rules are laws on literal texts (`decode_literal`,
`decode_multibyte`, `decode_refuses`).

## Lanes

The package runs natively and on the JavaScript lane, the Bun embedded in the
pinned compiler. `Host.Config.from_env` reads variables that may be unset,
and reading an unset variable loads `bun:ffi`, which node does not have: a
program that calls it runs natively and in-process with `./bend file.bend`,
never as a `-o file.js` build under node. The consumer's row in
[tests/lanes/programs.txt](../../tests/lanes/programs.txt) names the lanes
`native` and `javascript`. The pure core, `sdk.bend`, performs no effect and
runs wherever Bend runs, node included: `Config.from_variables` on a list of
variables a program holds is the way to configure under node.

## Laws and proofs

[LAWS.bend](LAWS.bend) states the package's claims and
[PROOF.bend](PROOF.bend) proves them; `./scripts/validate.sh` runs
`./bend packages/sdk/PROOF.bend --check-only` against the local hub, which
serves the API the core imports, and the check prints `ALL PROOFS CHECK`
only when every law holds and nothing the proofs import relies on `@unsafe`
or foreign code. The laws import `sdk.bend` alone, never `host.bend`.

The universal laws say that the defaults are the specification's; that each
setter is read back, on any configuration and on the one an environment
produced; that an empty value is an unset variable, whatever the name and
the other variables; that any text the Boolean parser refuses leaves the
default and yields exactly one diagnostic; that a text kept raw is kept
whole; that every level reaches itself; and that a text without a percent
sign decodes to itself. The literal laws state each parser on its texts, a
whole environment, the exact messages of invalid values, the precedence of
the span-specific limits, the OTLP values kept in order, the level table and
the decoder's round trips, multi-byte sequences and refusals. The checker
evaluates `Nat` in unary, so the bound 2147483647 is stated as the refusal
of the text past it, and the consumer reads the bound itself at run time.

## Writing Bend with the package

`bend guide` explains the language; these points come up with this package:

- Every type of this package is `Data`: a configuration or a `Configured`
  used twice is bound with `+`, as in `+config : Sdk.Config = ...`, and so
  is a value bound from an effect, `+configured : Sdk.Configured <-
  Host.Config.from_env()`.
- A `match` inspects a parameter or a variable bound by a pattern, never a
  computed value: give the result of `Sdk.Config.service_name` or
  `Sdk.Percent.decode` to a helper `def` that matches on its parameter, or
  print it with `Maybe.show(~&2, ~String, ~(text => text), value)`.
- The reporter slot of `Host.Reporter.each` is a template argument: write
  `~Host.Reporter.stderr`, a top-level definition, and never a local
  closure, which is affine and could be called once only.
- A `Nat` literal stops at `4294967295n`, and the checker computes `Nat` in
  unary: state laws on small numbers and leave the bounds to run-time tests.
