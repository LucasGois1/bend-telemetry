# bend-telemetry-sdk: the OpenTelemetry tracing SDK for Bend. Source: https://github.com/LucasGois1/bend-telemetry
import Base
import bend-telemetry-api@0.1.0.0/api.bend as Api

# The tracing SDK package: the pure core
# ======================================
#
# The OpenTelemetry tracing SDK for Bend: the package that an application
# installs to record spans. Its contract is the specification in
# https://github.com/LucasGois1/bend-telemetry/issues/11 ("spec #11" below).
# This file is the pure core of the package: it performs no effect, so that
# LAWS.bend and PROOF.bend beside it import it alone and the proof gate
# prints ALL PROOFS CHECK. host.bend, the package's entry on the hub, adds
# the effects on top of it: reading the environment and writing diagnostics
# to stderr. A program imports both by the package's BendHub name:
#
#   import bend-telemetry-sdk@0.1.0.0/sdk.bend as Sdk
#   import bend-telemetry-sdk@0.1.0.0/host.bend as Host
#
# Today the core holds the configuration (#12): the Config record with the
# specification's defaults, its readers and its pure setters; the parsers of
# the OTEL_* variables and Config.from_variables, which applies an
# environment's variables to the defaults and answers the configuration
# with its diagnostics; diagnostics as data with their levels; and the
# percent decoder that the resource's environment detector will use. The
# samplers, the resource operations, the span pipeline and the exporters
# follow in later tickets. README.md beside this file is the reference; the
# glossary of the repository's CONTEXT.md supplies the terms: diagnostic,
# sampler, span processor, span limits, resource, exporter, export budget,
# shutdown.
#
# Contents
#
#   Package            Package.name
#   Types              every public type, declared first
#   Diagnostics        Level.*, Diagnostic.*
#   Resource           Resource.*
#   Selections         SamplerSelection.show, ExporterSelection.show
#   Batch options      BatchOptions.*
#   Span limits        SpanLimits.with_*
#   Configuration      Config.default, readers, setters, Configured.*
#   Parsing            Env.read_*: the text of one variable to its value
#   Environment        Config.variable_names, Config.from_variables
#   Percent decoding   Percent.decode

# Package
# =======

# The package's BendHub name.
def Package.name() -> String:
  "bend-telemetry-sdk"

# Types
# =====

# The level of a diagnostic, and the level an operator configures with
# OTEL_LOG_LEVEL: a diagnostic below the configured level is dropped.
type Level is Data:
  Debug{}
  Info{}
  Warn{}
  Error{}

# A diagnostic: a message the SDK emits about its own operation, as data,
# with its level, the component that emits it (`config` for the
# configuration) and its message. It never fails the application.
type Diagnostic is Data:
  Diagnostic{level: Level, component: String, message: String}

# One variable of an environment: its name and its text. host.bend reads
# them; Config.from_variables applies them.
type Variable is Data:
  Variable{name: String, value: String}

# A resource: the description of the entity that produces the telemetry,
# as attributes plus a schema URL. Resource.create builds one; the merge and
# the detectors follow in the resource ticket.
type Resource is Data:
  Resource{attributes: Api.Attributes, schema_url: String}

# The sampler an operator selects with OTEL_TRACES_SAMPLER: the six samplers
# the specification names and this SDK provides. The sampler ticket builds
# the sampler from the selection and from the argument kept in the
# configuration.
type SamplerSelection is Data:
  AlwaysOn{}
  AlwaysOff{}
  TraceIdRatio{}
  ParentBasedAlwaysOn{}
  ParentBasedAlwaysOff{}
  ParentBasedTraceIdRatio{}

# The exporter a span processor sends to: the console exporter, none, or an
# external exporter named as OTEL_TRACES_EXPORTER names it (`otlp`, the
# default). Provider construction resolves a name against the exporter the
# provider was built with and reports a name it cannot serve.
type ExporterSelection is Data:
  ConsoleExporter{}
  NoExporter{}
  ExternalExporter{name: String}

# The options of a batch span processor: the most spans its queue holds, the
# milliseconds between scheduled exports, the export budget in milliseconds
# (absent: no limit) and the most spans per export.
type BatchOptions is Data:
  BatchOptions{queue_size: Nat, schedule_delay: Nat, export_timeout: Maybe<&2, Nat>, batch_size: Nat}

# A span processor configured in code: a simple processor, which exports
# each span as it ends, or a batch processor with its options; each with the
# exporter it sends to.
type ProcessorConfig is Data:
  SimpleProcessor{exporter: ExporterSelection}
  BatchProcessor{options: BatchOptions, exporter: ExporterSelection}

# The configuration of a tracer provider (spec #11, "Configuration"). The
# record is closed: build it with Config.default or Config.from_variables,
# read it with the readers and change it with the setters, never by
# constructing or matching it, so that a field added later breaks no caller.
# `processors` are the processors configured in code; when it is empty the
# provider builds the standard pipeline, one batch processor with `batch`
# and `exporter`. `otlp` keeps the OTEL_EXPORTER_OTLP_* values as text for
# the OTLP exporter package, under their variable names.
type Config is Data:
  Config{
    disabled: Bool,
    level: Level,
    resource: Resource,
    service_name: Maybe<&2, String>,
    resource_attributes: Maybe<&2, String>,
    sampler: SamplerSelection,
    sampler_arg: Maybe<&2, String>,
    processors: List<&2, ProcessorConfig>,
    batch: BatchOptions,
    span_limits: Api.SpanLimits,
    exporter: ExporterSelection,
    otlp: List<&2, Variable>,
    shutdown_timeout: Maybe<&2, Nat>,
    threshold_precision: Nat
  }

# A configuration read from an environment, with the diagnostics the
# reading produced, in the order of the variables, for the reporter to print
# once the provider exists.
type Configured is Data:
  Configured{config: Config, diagnostics: List<&2, Diagnostic>}

# A value of an enumeration under the name a variable takes for it: the
# tables of Env.read_level, Env.read_sampler and Env.read_exporter.
type Named<-A: Data> is Data:
  Named{name: String, value: A}

# Diagnostics
# ===========
#
# A diagnostic is data (spec #11, "Diagnostics"): the reporters of host.bend
# print it or drop it. Level.is_at_least is the reporter's decision, stated
# here so that it is proved.

# The rank of a level: debug is the lowest, error the highest.
def Level.rank(level: Level) -> Nat:
  match level:
    case Debug{}:
      0n
    case Info{}:
      1n
    case Warn{}:
      2n
    case Error{}:
      3n

# Whether a diagnostic at `level` is reported under the configured `floor`:
# it is at least as severe (laws level_reflexive and level_order).
def Level.is_at_least(level: Level, floor: Level) -> Bool:
  Nat.is_ge(Level.rank(level), Level.rank(floor))

# The lowercase name of a level, as OTEL_LOG_LEVEL takes it.
def Level.show(level: Level) -> String:
  match level:
    case Debug{}:
      "debug"
    case Info{}:
      "info"
    case Warn{}:
      "warn"
    case Error{}:
      "error"

# The level of a diagnostic.
def Diagnostic.level(diagnostic: Diagnostic) -> Level:
  match diagnostic:
    case Diagnostic{level, component, message}:
      level

# The component that emitted a diagnostic.
def Diagnostic.component(diagnostic: Diagnostic) -> String:
  match diagnostic:
    case Diagnostic{level, component, message}:
      component

# The message of a diagnostic.
def Diagnostic.message(diagnostic: Diagnostic) -> String:
  match diagnostic:
    case Diagnostic{level, component, message}:
      message

# The text of a diagnostic: `[warn] config: the message`. The stderr
# reporter writes it after its fixed prefix.
def Diagnostic.show(diagnostic: Diagnostic) -> String:
  match diagnostic:
    case Diagnostic{level, component, message}:
      "[" ++ Level.show(level) ++ "] " ++ component ++ ": " ++ message

# Resource
# ========

# The resource with no attributes and no schema URL.
def Resource.empty() -> Resource:
  Resource{Api.Attributes.empty(), ""}

# A resource of attributes and a schema URL, an empty text when there is
# none.
def Resource.create(attributes: Api.Attributes, schema_url: String) -> Resource:
  Resource{attributes, schema_url}

# The attributes of a resource.
def Resource.attributes(resource: Resource) -> Api.Attributes:
  match resource:
    case Resource{attributes, schema_url}:
      attributes

# The schema URL of a resource.
def Resource.schema_url(resource: Resource) -> String:
  match resource:
    case Resource{attributes, schema_url}:
      schema_url

# Selections
# ==========

# The name of a sampler selection, as OTEL_TRACES_SAMPLER takes it.
def SamplerSelection.show(selection: SamplerSelection) -> String:
  match selection:
    case AlwaysOn{}:
      "always_on"
    case AlwaysOff{}:
      "always_off"
    case TraceIdRatio{}:
      "traceidratio"
    case ParentBasedAlwaysOn{}:
      "parentbased_always_on"
    case ParentBasedAlwaysOff{}:
      "parentbased_always_off"
    case ParentBasedTraceIdRatio{}:
      "parentbased_traceidratio"

# The name of an exporter selection, as OTEL_TRACES_EXPORTER takes it.
def ExporterSelection.show(selection: ExporterSelection) -> String:
  match selection:
    case ConsoleExporter{}:
      "console"
    case NoExporter{}:
      "none"
    case ExternalExporter{name}:
      name

# Batch options
# =============

# The specification's defaults: a queue of 2048 spans, an export every 5000
# milliseconds, an export budget of 30000 milliseconds and batches of 512
# spans (law batch_default).
def BatchOptions.default() -> BatchOptions:
  BatchOptions{2048n, 5000n, Some{30000n}, 512n}

# The most spans the queue holds.
def BatchOptions.queue_size(options: BatchOptions) -> Nat:
  match options:
    case BatchOptions{queue_size, schedule_delay, export_timeout, batch_size}:
      queue_size

# The milliseconds between scheduled exports.
def BatchOptions.schedule_delay(options: BatchOptions) -> Nat:
  match options:
    case BatchOptions{queue_size, schedule_delay, export_timeout, batch_size}:
      schedule_delay

# The export budget in milliseconds, absent when an export has no limit.
def BatchOptions.export_timeout(options: BatchOptions) -> Maybe<&2, Nat>:
  match options:
    case BatchOptions{queue_size, schedule_delay, export_timeout, batch_size}:
      export_timeout

# The most spans per export.
def BatchOptions.batch_size(options: BatchOptions) -> Nat:
  match options:
    case BatchOptions{queue_size, schedule_delay, export_timeout, batch_size}:
      batch_size

# The options with another queue size.
def BatchOptions.with_queue_size(options: BatchOptions, queue_size: Nat) -> BatchOptions:
  match options:
    case BatchOptions{previous, schedule_delay, export_timeout, batch_size}:
      BatchOptions{queue_size, schedule_delay, export_timeout, batch_size}

# The options with another schedule delay.
def BatchOptions.with_schedule_delay(options: BatchOptions, schedule_delay: Nat) -> BatchOptions:
  match options:
    case BatchOptions{queue_size, previous, export_timeout, batch_size}:
      BatchOptions{queue_size, schedule_delay, export_timeout, batch_size}

# The options with another export budget, or none.
def BatchOptions.with_export_timeout(options: BatchOptions, export_timeout: Maybe<&2, Nat>) -> BatchOptions:
  match options:
    case BatchOptions{queue_size, schedule_delay, previous, batch_size}:
      BatchOptions{queue_size, schedule_delay, export_timeout, batch_size}

# The options with another batch size.
def BatchOptions.with_batch_size(options: BatchOptions, batch_size: Nat) -> BatchOptions:
  match options:
    case BatchOptions{queue_size, schedule_delay, export_timeout, previous}:
      BatchOptions{queue_size, schedule_delay, export_timeout, batch_size}

# Span limits
# ===========
#
# The API's span limits record has readers and no setters; these build the
# record with one limit changed, for the environment's variables and for
# programs that start from Api.SpanLimits.default().

# The limits with another attribute count.
def SpanLimits.with_attribute_count(limits: Api.SpanLimits, count: Maybe<&2, Nat>) -> Api.SpanLimits:
  match limits:
    case Api.SpanLimits{previous, attribute_value_length, event_count, link_count, attribute_per_event_count, attribute_per_link_count}:
      Api.SpanLimits{count, attribute_value_length, event_count, link_count, attribute_per_event_count, attribute_per_link_count}

# The limits with another attribute value length.
def SpanLimits.with_attribute_value_length(limits: Api.SpanLimits, length: Maybe<&2, Nat>) -> Api.SpanLimits:
  match limits:
    case Api.SpanLimits{attribute_count, previous, event_count, link_count, attribute_per_event_count, attribute_per_link_count}:
      Api.SpanLimits{attribute_count, length, event_count, link_count, attribute_per_event_count, attribute_per_link_count}

# The limits with another event count.
def SpanLimits.with_event_count(limits: Api.SpanLimits, count: Maybe<&2, Nat>) -> Api.SpanLimits:
  match limits:
    case Api.SpanLimits{attribute_count, attribute_value_length, previous, link_count, attribute_per_event_count, attribute_per_link_count}:
      Api.SpanLimits{attribute_count, attribute_value_length, count, link_count, attribute_per_event_count, attribute_per_link_count}

# The limits with another link count.
def SpanLimits.with_link_count(limits: Api.SpanLimits, count: Maybe<&2, Nat>) -> Api.SpanLimits:
  match limits:
    case Api.SpanLimits{attribute_count, attribute_value_length, event_count, previous, attribute_per_event_count, attribute_per_link_count}:
      Api.SpanLimits{attribute_count, attribute_value_length, event_count, count, attribute_per_event_count, attribute_per_link_count}

# The limits with another attribute count per event.
def SpanLimits.with_attribute_per_event_count(limits: Api.SpanLimits, count: Maybe<&2, Nat>) -> Api.SpanLimits:
  match limits:
    case Api.SpanLimits{attribute_count, attribute_value_length, event_count, link_count, previous, attribute_per_link_count}:
      Api.SpanLimits{attribute_count, attribute_value_length, event_count, link_count, count, attribute_per_link_count}

# The limits with another attribute count per link.
def SpanLimits.with_attribute_per_link_count(limits: Api.SpanLimits, count: Maybe<&2, Nat>) -> Api.SpanLimits:
  match limits:
    case Api.SpanLimits{attribute_count, attribute_value_length, event_count, link_count, attribute_per_event_count, previous}:
      Api.SpanLimits{attribute_count, attribute_value_length, event_count, link_count, attribute_per_event_count, count}

# Configuration
# =============
#
# Config.default holds the specification's defaults; Config.from_variables
# applies an environment on top of them; the setters apply programmatic
# settings on top of either, so that code wins over the environment and the
# environment over the defaults (spec #11, user story 3).

# The defaults (law config_default): tracing on, diagnostics from the info
# level, an empty user resource, no service name and no resource attributes
# from the environment, the parent-based always-on sampler with no argument,
# no processors in code, the batch options' defaults, the API's span limits,
# the `otlp` exporter selection, no OTLP values, a shutdown timeout of 30000
# milliseconds and a sampling threshold of four hexadecimal digits.
def Config.default() -> Config:
  Config{False{}, Info{}, Resource.empty(), None{}, None{}, ParentBasedAlwaysOn{}, None{}, Nil{}, BatchOptions.default(),
    Api.SpanLimits.default(), ExternalExporter{"otlp"}, Nil{}, Some{30000n}, 4n}

# Whether the SDK is disabled: a disabled provider records nothing and
# starts no computation.
def Config.disabled(config: Config) -> Bool:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      disabled

# The level below which diagnostics are dropped.
def Config.level(config: Config) -> Level:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      level

# The resource the application supplies in code, merged last.
def Config.resource(config: Config) -> Resource:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      resource

# The service name of OTEL_SERVICE_NAME, if set.
def Config.service_name(config: Config) -> Maybe<&2, String>:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      service_name

# The raw text of OTEL_RESOURCE_ATTRIBUTES, if set, for the resource's
# environment detector to decode.
def Config.resource_attributes(config: Config) -> Maybe<&2, String>:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      resource_attributes

# The selected sampler.
def Config.sampler(config: Config) -> SamplerSelection:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      sampler

# The raw text of OTEL_TRACES_SAMPLER_ARG, if set, for the sampler to parse.
def Config.sampler_arg(config: Config) -> Maybe<&2, String>:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      sampler_arg

# The processors configured in code; empty for the standard pipeline.
def Config.processors(config: Config) -> List<&2, ProcessorConfig>:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      processors

# The options of the standard pipeline's batch processor.
def Config.batch(config: Config) -> BatchOptions:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      batch

# The span limits the provider gives every span.
def Config.span_limits(config: Config) -> Api.SpanLimits:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      span_limits

# The exporter of the standard pipeline.
def Config.exporter(config: Config) -> ExporterSelection:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      exporter

# The OTEL_EXPORTER_OTLP_* values, as text under their variable names, in
# the order of Config.variable_names.
def Config.otlp(config: Config) -> List<&2, Variable>:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      otlp

# The milliseconds a shutdown waits for the pipeline, absent for no limit.
def Config.shutdown_timeout(config: Config) -> Maybe<&2, Nat>:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      shutdown_timeout

# The hexadecimal digits of precision of the ratio sampler's threshold.
def Config.threshold_precision(config: Config) -> Nat:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      threshold_precision

# The configuration with tracing disabled or enabled.
def Config.with_disabled(config: Config, disabled: Bool) -> Config:
  match config:
    case Config{previous, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}

# The configuration with another diagnostics level.
def Config.with_level(config: Config, level: Level) -> Config:
  match config:
    case Config{disabled, previous, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}

# The configuration with the application's resource.
def Config.with_resource(config: Config, resource: Resource) -> Config:
  match config:
    case Config{disabled, level, previous, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}

# The configuration with a service name.
def Config.with_service_name(config: Config, service_name: String) -> Config:
  match config:
    case Config{disabled, level, resource, previous, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      Config{disabled, level, resource, Some{service_name}, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}

# The configuration with the raw text of resource attributes, in the form of
# OTEL_RESOURCE_ATTRIBUTES.
def Config.with_resource_attributes(config: Config, resource_attributes: String) -> Config:
  match config:
    case Config{disabled, level, resource, service_name, previous, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      Config{disabled, level, resource, service_name, Some{resource_attributes}, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}

# The configuration with another sampler.
def Config.with_sampler(config: Config, sampler: SamplerSelection) -> Config:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, previous, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}

# The configuration with the sampler's argument, in the form of
# OTEL_TRACES_SAMPLER_ARG.
def Config.with_sampler_arg(config: Config, sampler_arg: String) -> Config:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, previous, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      Config{disabled, level, resource, service_name, resource_attributes, sampler, Some{sampler_arg}, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}

# The configuration with processors configured in code.
def Config.with_processors(config: Config, processors: List<&2, ProcessorConfig>) -> Config:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, previous, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}

# The configuration with other batch options.
def Config.with_batch(config: Config, batch: BatchOptions) -> Config:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, previous, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}

# The configuration with other span limits.
def Config.with_span_limits(config: Config, span_limits: Api.SpanLimits) -> Config:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, previous, exporter, otlp, shutdown_timeout, threshold_precision}:
      Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}

# The configuration with another exporter for the standard pipeline.
def Config.with_exporter(config: Config, exporter: ExporterSelection) -> Config:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, previous, otlp, shutdown_timeout, threshold_precision}:
      Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}

# The configuration with the OTLP values given.
def Config.with_otlp(config: Config, otlp: List<&2, Variable>) -> Config:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, previous, shutdown_timeout, threshold_precision}:
      Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}

# The configuration with another shutdown timeout, or none.
def Config.with_shutdown_timeout(config: Config, shutdown_timeout: Maybe<&2, Nat>) -> Config:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, previous, threshold_precision}:
      Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}

# The configuration with another threshold precision.
def Config.with_threshold_precision(config: Config, threshold_precision: Nat) -> Config:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, previous}:
      Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}

# The name of a variable.
def Variable.name(variable: Variable) -> String:
  match variable:
    case Variable{name, value}:
      name

# The text of a variable.
def Variable.value(variable: Variable) -> String:
  match variable:
    case Variable{name, value}:
      value

# The entry whose name compared equal takes the new value and keeps its
# place; any other entry stays, followed by the rest with the value set.
def Config.with_otlp_value.step(head: Variable, tail: List<&2, Variable>, rest: List<&2, Variable>, value: String,
  same: Bool) -> List<&2, Variable>:
  match same:
    case True{}:
      Con{Variable{Variable.name(head), value}, tail}
    case False{}:
      Con{head, rest}

# The values with the name set: replaced in place when it is there, appended
# last otherwise.
def Config.with_otlp_value.go(values: List<&2, Variable>, +name: String, +value: String) -> List<&2, Variable>:
  match values:
    case Nil{}:
      [Variable{name, value}]
    case Con{+head, +tail}:
      Config.with_otlp_value.step(head, tail, Config.with_otlp_value.go(tail, name, value), value,
        String.eq(Variable.name(head), name))

# The configuration with one OTLP value set under its variable name, such as
# OTEL_EXPORTER_OTLP_TRACES_ENDPOINT (law otlp_value_set).
def Config.with_otlp_value(+config: Config, name: String, value: String) -> Config:
  Config.with_otlp(config, Config.with_otlp_value.go(Config.otlp(config), name, value))

# The value of the entry whose name compared equal, or what the rest gave.
def Config.otlp_value.step(entry: Variable, rest: Maybe<&2, String>, same: Bool) -> Maybe<&2, String>:
  match same:
    case True{}:
      Some{Variable.value(entry)}
    case False{}:
      rest

# The value of the first entry with the name, if any.
def Config.otlp_value.go(values: List<&2, Variable>, +name: String) -> Maybe<&2, String>:
  match values:
    case Nil{}:
      None{}
    case Con{+head, tail}:
      Config.otlp_value.step(head, Config.otlp_value.go(tail, name), String.eq(Variable.name(head), name))

# The OTLP value kept under a variable name, if any: the OTLP exporter
# package reads the traces-specific variable and then the general one.
def Config.otlp_value(config: Config, name: String) -> Maybe<&2, String>:
  Config.otlp_value.go(Config.otlp(config), name)

# The configuration an environment produced.
def Configured.config(configured: Configured) -> Config:
  match configured:
    case Configured{config, diagnostics}:
      config

# The diagnostics an environment produced, one per invalid value, in the
# order of Config.variable_names.
def Configured.diagnostics(configured: Configured) -> List<&2, Diagnostic>:
  match configured:
    case Configured{config, diagnostics}:
      diagnostics

# Parsing
# =======
#
# Each parser reads the text of one kind of variable (OTel, SDK
# Configuration, Environment Variables: Boolean value, Numeric value,
# Duration, Timeout, Enum value) and answers Done with the value or Fail
# with the reason that its diagnostic carries. The texts they receive are
# never empty: an empty value is an unset variable, decided before parsing.
# An enumeration is read by a search of its table with String.eq, since a
# `match` on long string literals costs the checker a deep stack.

# The value whose name compared equal, or what the rest of the table gave.
def Env.find.step(-A: Data, value: A, rest: Maybe<&2, A>, same: Bool) -> Maybe<&2, A>:
  match same:
    case True{}:
      Some{value}
    case False{}:
      rest

# The value of the first entry of a table named `lower`, if any.
def Env.find(-A: Data, entries: List<&2, Named<A>>, +lower: String) -> Maybe<&2, A>:
  match entries:
    case Nil{}:
      None{}
    case Con{Named{name, value}, rest}:
      Env.find.step(A, value, Env.find(A, rest, lower), String.eq(name, lower))

# Whether a name is among a list of names.
def Env.listed(names: List<&2, String>, +lower: String) -> Bool:
  match names:
    case Nil{}:
      False{}
    case Con{name, rest}:
      Bool.or(String.eq(name, lower), Env.listed(rest, lower))

# Whether every character is a decimal digit.
def Env.digits(text: String) -> Bool:
  match text:
    case SNil{}:
      True{}
    case SCon{char, rest}:
      Bool.and(Char.is_digit(char), Env.digits(rest))

# The digits without their leading zeros.
def Env.strip_zeros(text: String) -> String:
  match text:
    case SCon{'0', rest}:
      Env.strip_zeros(rest)
    case other:
      other

# Whether a text of digits without leading zeros is at most 2147483647: fewer
# than ten digits, or ten digits that compare at most the bound as text. The
# bound is decided on the text because the checker evaluates Nat in unary.
def Env.fits(+stripped: String) -> Bool:
  +length = String.length(stripped)
  Bool.or(Nat.is_lt(length, 10n), Bool.and(Nat.is_eq(length, 10n), String.is_le(stripped, "2147483647")))

# The number of a text that passed the checks, read natively.
def Env.read_integer.gate(text: String, ok: Bool) -> Maybe<&2, Nat>:
  match ok:
    case True{}:
      Nat.read(text)
    case False{}:
      None{}

# The number of a text of decimal digits from 0 to 2147483647, leading zeros
# accepted; None for any other text.
def Env.read_integer(text: String) -> Maybe<&2, Nat>:
  match text:
    case SNil{}:
      None{}
    case SCon{+head, +rest}:
      Env.read_integer.gate(SCon{head, rest}, Bool.and(Env.digits(SCon{head, rest}), Env.fits(Env.strip_zeros(SCon{head, rest}))))

# A Boolean, once the text is lowercase: true for `true`, false for
# `false`, refused otherwise.
def Env.read_bool.of(is_true: Bool, is_false: Bool) -> Result<&2, &2, String, Bool>:
  match is_true:
    case True{}:
      Done{True{}}
    case False{}:
      match is_false:
        case True{}:
          Done{False{}}
        case False{}:
          Fail{"is not a Boolean (true or false)"}

# A Boolean value: true only for a case-insensitive `true`, false for a
# case-insensitive `false`, and refused for any other text (law
# bool_literal).
def Env.read_bool(text: String) -> Result<&2, &2, String, Bool>:
  +lower = String.to_lower(text)
  Env.read_bool.of(String.eq(lower, "true"), String.eq(lower, "false"))

# A count, once the integer was read or refused.
def Env.read_count.of(integer: Maybe<&2, Nat>) -> Result<&2, &2, String, Nat>:
  match integer:
    case Some{count}:
      Done{count}
    case None{}:
      Fail{"is not an integer from 0 to 2147483647"}

# A numeric value: a non-negative integer up to 2147483647 (law
# count_literal), such as a span limit.
def Env.read_count(text: String) -> Result<&2, &2, String, Nat>:
  Env.read_count.of(Env.read_integer(text))

# A size, once the integer was read or refused: zero is not a size.
def Env.read_size.of(integer: Maybe<&2, Nat>) -> Result<&2, &2, String, Nat>:
  match integer:
    case Some{0n}:
      Fail{"is not an integer from 1 to 2147483647"}
    case Some{1n+less}:
      Done{1n+less}
    case None{}:
      Fail{"is not an integer from 1 to 2147483647"}

# A size: a positive integer up to 2147483647 (law size_literal), such as a
# queue size or a batch size.
def Env.read_size(text: String) -> Result<&2, &2, String, Nat>:
  Env.read_size.of(Env.read_integer(text))

# A duration, once the integer was read or refused.
def Env.read_duration.of(integer: Maybe<&2, Nat>) -> Result<&2, &2, String, Nat>:
  match integer:
    case Some{milliseconds}:
      Done{milliseconds}
    case None{}:
      Fail{"is not a duration in milliseconds, an integer from 0 to 2147483647"}

# A duration: a non-negative integer of milliseconds (law duration_literal).
def Env.read_duration(text: String) -> Result<&2, &2, String, Nat>:
  Env.read_duration.of(Env.read_integer(text))

# A timeout, once the integer was read or refused: zero means no limit.
def Env.read_timeout.of(integer: Maybe<&2, Nat>) -> Result<&2, &2, String, Maybe<&2, Nat>>:
  match integer:
    case Some{0n}:
      Done{None{}}
    case Some{1n+less}:
      Done{Some{1n+less}}
    case None{}:
      Fail{"is not a timeout in milliseconds, an integer from 0 (no limit) to 2147483647"}

# A timeout: a duration where zero means no limit (law timeout_literal).
def Env.read_timeout(text: String) -> Result<&2, &2, String, Maybe<&2, Nat>>:
  Env.read_timeout.of(Env.read_integer(text))

# The levels under the names OTEL_LOG_LEVEL takes.
def Env.levels() -> List<&2, Named<Level>>:
  [Named{"debug", Debug{}}, Named{"info", Info{}}, Named{"warn", Warn{}}, Named{"error", Error{}}]

# A level, once the table was searched.
def Env.read_level.of(found: Maybe<&2, Level>) -> Result<&2, &2, String, Level>:
  match found:
    case Some{level}:
      Done{level}
    case None{}:
      Fail{"is not a level: debug, info, warn or error"}

# A level of OTEL_LOG_LEVEL: one of the four names, in any case (law
# level_literal).
def Env.read_level(text: String) -> Result<&2, &2, String, Level>:
  Env.read_level.of(Env.find(Level, Env.levels(), String.to_lower(text)))

# The six samplers this SDK provides, under the names OTEL_TRACES_SAMPLER
# takes.
def Env.samplers() -> List<&2, Named<SamplerSelection>>:
  [Named{"always_on", AlwaysOn{}}, Named{"always_off", AlwaysOff{}}, Named{"traceidratio", TraceIdRatio{}},
   Named{"parentbased_always_on", ParentBasedAlwaysOn{}}, Named{"parentbased_always_off", ParentBasedAlwaysOff{}},
   Named{"parentbased_traceidratio", ParentBasedTraceIdRatio{}}]

# The samplers the specification names and this SDK does not provide.
def Env.unprovided_samplers() -> List<&2, String>:
  ["jaeger_remote", "parentbased_jaeger_remote", "xray"]

# A sampler selection, once the tables were searched: a sampler this SDK
# does not provide is refused with its own reason.
def Env.read_sampler.of(found: Maybe<&2, SamplerSelection>, unprovided: Bool) -> Result<&2, &2, String, SamplerSelection>:
  match found:
    case Some{selection}:
      Done{selection}
    case None{}:
      match unprovided:
        case True{}:
          Fail{"names a sampler this SDK does not provide"}
        case False{}:
          Fail{"is not a sampler: always_on, always_off, traceidratio, parentbased_always_on, parentbased_always_off or parentbased_traceidratio"}

# A sampler of OTEL_TRACES_SAMPLER, in any case (law sampler_literal).
def Env.read_sampler(text: String) -> Result<&2, &2, String, SamplerSelection>:
  +lower = String.to_lower(text)
  Env.read_sampler.of(Env.find(SamplerSelection, Env.samplers(), lower), Env.listed(Env.unprovided_samplers(), lower))

# Whether a text has a comma: a list of exporters.
def Env.has_comma(text: String) -> Bool:
  match text:
    case SNil{}:
      False{}
    case SCon{char, rest}:
      Bool.or(Char.is_eq(char, ','), Env.has_comma(rest))

# The two built-in exporter selections, under the names OTEL_TRACES_EXPORTER
# takes.
def Env.exporters() -> List<&2, Named<ExporterSelection>>:
  [Named{"console", ConsoleExporter{}}, Named{"none", NoExporter{}}]

# A text that names no built-in exporter: an external exporter by name, or
# no name at all.
def Env.read_exporter.external(lower: String) -> Result<&2, &2, String, ExporterSelection>:
  match lower:
    case SNil{}:
      Fail{"names no exporter; this SDK takes one: console, none or the name of the exporter the provider is built with"}
    case SCon{head, tail}:
      Done{ExternalExporter{SCon{head, tail}}}

# An exporter selection, once the table was searched and the text is known
# to name one exporter.
def Env.read_exporter.of(lower: String, found: Maybe<&2, ExporterSelection>) -> Result<&2, &2, String, ExporterSelection>:
  match found:
    case Some{selection}:
      Done{selection}
    case None{}:
      Env.read_exporter.external(lower)

# A list of names, which this SDK does not take, or one name.
def Env.read_exporter.single(lower: String, found: Maybe<&2, ExporterSelection>, list: Bool) ->
  Result<&2, &2, String, ExporterSelection>:
  match list:
    case True{}:
      Fail{"names several exporters; this SDK takes one: console, none or the name of the exporter the provider is built with"}
    case False{}:
      Env.read_exporter.of(lower, found)

# An exporter of OTEL_TRACES_EXPORTER: `console`, `none` or the name of an
# external exporter, in any case; a list of names is refused (law
# exporter_literal). Provider construction resolves the name.
def Env.read_exporter(text: String) -> Result<&2, &2, String, ExporterSelection>:
  +lower = String.to_lower(text)
  Env.read_exporter.single(lower, Env.find(ExporterSelection, Env.exporters(), lower), Env.has_comma(lower))

# A text kept as it is (law text_kept): OTEL_SERVICE_NAME,
# OTEL_RESOURCE_ATTRIBUTES, OTEL_TRACES_SAMPLER_ARG and the OTLP values.
def Env.read_text(text: String) -> Result<&2, &2, String, String>:
  Done{text}

# Environment
# ===========
#
# Config.from_variables applies the supported variables of an environment to
# the defaults, in the order of Config.variable_names: a variable that is
# absent or empty changes nothing; a valid value is set; an invalid value is
# reported once and leaves the default (spec #11, "Configuration").
# host.bend's Config.from_env reads the variables and calls it.

# The variables read into the configuration's own fields, in the order they
# are applied: the span-specific limits come after the general attribute
# limits, so that they win.
def Env.general_names() -> List<&2, String>:
  ["OTEL_SDK_DISABLED", "OTEL_LOG_LEVEL", "OTEL_SERVICE_NAME", "OTEL_RESOURCE_ATTRIBUTES", "OTEL_TRACES_SAMPLER",
   "OTEL_TRACES_SAMPLER_ARG", "OTEL_TRACES_EXPORTER", "OTEL_BSP_SCHEDULE_DELAY", "OTEL_BSP_EXPORT_TIMEOUT",
   "OTEL_BSP_MAX_QUEUE_SIZE", "OTEL_BSP_MAX_EXPORT_BATCH_SIZE", "OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT",
   "OTEL_ATTRIBUTE_COUNT_LIMIT", "OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT", "OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT",
   "OTEL_SPAN_EVENT_COUNT_LIMIT", "OTEL_SPAN_LINK_COUNT_LIMIT", "OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT",
   "OTEL_LINK_ATTRIBUTE_COUNT_LIMIT"]

# The variables kept as text for the OTLP exporter package: the general
# option and its traces-specific variant, option by option.
def Env.otlp_names() -> List<&2, String>:
  ["OTEL_EXPORTER_OTLP_ENDPOINT", "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "OTEL_EXPORTER_OTLP_INSECURE",
   "OTEL_EXPORTER_OTLP_TRACES_INSECURE", "OTEL_EXPORTER_OTLP_CERTIFICATE", "OTEL_EXPORTER_OTLP_TRACES_CERTIFICATE",
   "OTEL_EXPORTER_OTLP_CLIENT_KEY", "OTEL_EXPORTER_OTLP_TRACES_CLIENT_KEY", "OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE",
   "OTEL_EXPORTER_OTLP_TRACES_CLIENT_CERTIFICATE", "OTEL_EXPORTER_OTLP_HEADERS", "OTEL_EXPORTER_OTLP_TRACES_HEADERS",
   "OTEL_EXPORTER_OTLP_COMPRESSION", "OTEL_EXPORTER_OTLP_TRACES_COMPRESSION", "OTEL_EXPORTER_OTLP_TIMEOUT",
   "OTEL_EXPORTER_OTLP_TRACES_TIMEOUT", "OTEL_EXPORTER_OTLP_PROTOCOL", "OTEL_EXPORTER_OTLP_TRACES_PROTOCOL"]

# The names of every supported variable, in the order Config.from_variables
# applies them and Config.from_env reads them (law variable_names).
def Config.variable_names() -> List<&2, String>:
  List.append(&2, String, Env.general_names(), Env.otlp_names())

# The value of a variable found under the name, unless it is empty: an
# empty value is an unset variable, so the search goes on.
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
    case Con{Variable{+found, value}, rest}:
      Env.lookup.step(value, Env.lookup(rest, name), String.eq(found, name))

# The message of an invalid value: the variable, its text, the parser's
# reason and what follows.
def Env.message(name: String, text: String, reason: String) -> String:
  String.concat([name, "=\"", text, "\" ", reason, "; the default is kept"])

# A parsed value is set with the setter; a refusal keeps the configuration
# and adds one warning of the config component.
def Env.step(-A: Data, +name: String, state: Configured, +text: String, parsed: Result<&2, &2, String, A>,
  set: Config -> A -> Config) -> Configured:
  match state parsed:
    case Configured{config, diagnostics} Done{value}:
      Configured{set(config, value), diagnostics}
    case Configured{config, diagnostics} Fail{reason}:
      Configured{config, List.append(&2, Diagnostic, diagnostics, [Diagnostic{Warn{}, "config", Env.message(name, text, reason)}])}

# A value that was found: parsed and applied.
def Env.apply.found(-A: Data, name: String, state: Configured, found: Maybe<&2, String>,
  read: String -> Result<&2, &2, String, A>, set: Config -> A -> Config) -> Configured:
  match found:
    case None{}:
      state
    case Some{+text}:
      Env.step(A, name, state, text, read(text), set)

# Apply one variable: look its name up, parse the value with `read` and set
# it with `set`, or report it.
def Env.apply(-A: Data, state: Configured, +variables: List<&2, Variable>, +name: String,
  read: String -> Result<&2, &2, String, A>, set: Config -> A -> Config) -> Configured:
  Env.apply.found(A, name, state, Env.lookup(variables, name), read, set)

# The setters of the batch options and the span limits, for Env.apply: each
# changes one option of the batch, or one limit, through the two helpers
# below, which open the record once.

# The configuration with its batch options changed by `update`.
def Env.update_batch(config: Config, update: BatchOptions -> BatchOptions) -> Config:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, update(batch), span_limits, exporter, otlp, shutdown_timeout, threshold_precision}

# The configuration with its span limits changed by `update`.
def Env.update_limits(config: Config, update: Api.SpanLimits -> Api.SpanLimits) -> Config:
  match config:
    case Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, update(span_limits), exporter, otlp, shutdown_timeout, threshold_precision}

def Env.set_schedule_delay(config: Config, milliseconds: Nat) -> Config:
  Env.update_batch(config, options => BatchOptions.with_schedule_delay(options, milliseconds))

def Env.set_export_timeout(config: Config, timeout: Maybe<&2, Nat>) -> Config:
  Env.update_batch(config, options => BatchOptions.with_export_timeout(options, timeout))

def Env.set_queue_size(config: Config, size: Nat) -> Config:
  Env.update_batch(config, options => BatchOptions.with_queue_size(options, size))

def Env.set_batch_size(config: Config, size: Nat) -> Config:
  Env.update_batch(config, options => BatchOptions.with_batch_size(options, size))

def Env.set_attribute_value_length(config: Config, length: Nat) -> Config:
  Env.update_limits(config, limits => SpanLimits.with_attribute_value_length(limits, Some{length}))

def Env.set_attribute_count(config: Config, count: Nat) -> Config:
  Env.update_limits(config, limits => SpanLimits.with_attribute_count(limits, Some{count}))

def Env.set_event_count(config: Config, count: Nat) -> Config:
  Env.update_limits(config, limits => SpanLimits.with_event_count(limits, Some{count}))

def Env.set_link_count(config: Config, count: Nat) -> Config:
  Env.update_limits(config, limits => SpanLimits.with_link_count(limits, Some{count}))

def Env.set_attribute_per_event_count(config: Config, count: Nat) -> Config:
  Env.update_limits(config, limits => SpanLimits.with_attribute_per_event_count(limits, Some{count}))

def Env.set_attribute_per_link_count(config: Config, count: Nat) -> Config:
  Env.update_limits(config, limits => SpanLimits.with_attribute_per_link_count(limits, Some{count}))

# The setter of one OTLP value, under its variable name.
def Env.set_otlp_value(name: String) -> Config -> String -> Config:
  config => value => Config.with_otlp_value(config, name, value)

# Keep each OTLP variable as text, the names first so that the recursion is
# on them.
def Env.keep_all(names: List<&2, String>, state: Configured, +variables: List<&2, Variable>) -> Configured:
  match names:
    case Nil{}:
      state
    case Con{+name, rest}:
      Env.keep_all(rest, Env.apply(String, state, variables, name, Env.read_text, Env.set_otlp_value(name)), variables)

# The configuration of an environment: the defaults with every supported
# variable applied, and the diagnostics of the invalid values (laws
# unset_is_default, empty_is_unset, environment_literal,
# invalid_boolean_once, specific_limits_win and otlp_kept).
def Config.from_variables(+variables: List<&2, Variable>) -> Configured:
  s0 = {Configured{Config.default(), Nil{}} : Configured}
  s1 = Env.apply(Bool, s0, variables, "OTEL_SDK_DISABLED", Env.read_bool, Config.with_disabled)
  s2 = Env.apply(Level, s1, variables, "OTEL_LOG_LEVEL", Env.read_level, Config.with_level)
  s3 = Env.apply(String, s2, variables, "OTEL_SERVICE_NAME", Env.read_text, Config.with_service_name)
  s4 = Env.apply(String, s3, variables, "OTEL_RESOURCE_ATTRIBUTES", Env.read_text, Config.with_resource_attributes)
  s5 = Env.apply(SamplerSelection, s4, variables, "OTEL_TRACES_SAMPLER", Env.read_sampler, Config.with_sampler)
  s6 = Env.apply(String, s5, variables, "OTEL_TRACES_SAMPLER_ARG", Env.read_text, Config.with_sampler_arg)
  s7 = Env.apply(ExporterSelection, s6, variables, "OTEL_TRACES_EXPORTER", Env.read_exporter, Config.with_exporter)
  s8 = Env.apply(Nat, s7, variables, "OTEL_BSP_SCHEDULE_DELAY", Env.read_duration, Env.set_schedule_delay)
  s9 = Env.apply(Maybe<&2, Nat>, s8, variables, "OTEL_BSP_EXPORT_TIMEOUT", Env.read_timeout, Env.set_export_timeout)
  s10 = Env.apply(Nat, s9, variables, "OTEL_BSP_MAX_QUEUE_SIZE", Env.read_size, Env.set_queue_size)
  s11 = Env.apply(Nat, s10, variables, "OTEL_BSP_MAX_EXPORT_BATCH_SIZE", Env.read_size, Env.set_batch_size)
  s12 = Env.apply(Nat, s11, variables, "OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT", Env.read_count, Env.set_attribute_value_length)
  s13 = Env.apply(Nat, s12, variables, "OTEL_ATTRIBUTE_COUNT_LIMIT", Env.read_count, Env.set_attribute_count)
  s14 = Env.apply(Nat, s13, variables, "OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT", Env.read_count, Env.set_attribute_value_length)
  s15 = Env.apply(Nat, s14, variables, "OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", Env.read_count, Env.set_attribute_count)
  s16 = Env.apply(Nat, s15, variables, "OTEL_SPAN_EVENT_COUNT_LIMIT", Env.read_count, Env.set_event_count)
  s17 = Env.apply(Nat, s16, variables, "OTEL_SPAN_LINK_COUNT_LIMIT", Env.read_count, Env.set_link_count)
  s18 = Env.apply(Nat, s17, variables, "OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT", Env.read_count, Env.set_attribute_per_event_count)
  s19 = Env.apply(Nat, s18, variables, "OTEL_LINK_ATTRIBUTE_COUNT_LIMIT", Env.read_count, Env.set_attribute_per_link_count)
  Env.keep_all(Env.otlp_names(), s19, variables)

# Percent decoding
# ================
#
# OTEL_RESOURCE_ATTRIBUTES carries percent-encoded values, as W3C Baggage
# does. Percent.decode answers the text of a percent-encoded text, or None
# when an escape is not a percent sign and two hexadecimal digits or the
# escaped bytes are not UTF-8 (RFC 3629): a bad escape refuses the whole
# text, which the resource's environment detector then discards with a
# warning (spec #11, "Resource"). The decoder reads the text from its end:
# a percent sign takes the two characters after it, and a UTF-8 lead byte
# takes the continuation bytes after it, so that every decision is on a
# value already computed. The types Piece, Decoding and ByteClass are its
# representation, not a contract.

# One piece of a percent-encoded text: a character kept as it is, or the
# byte of an escape.
type Piece is Data:
  RawPiece{char: Char}
  BytePiece{value: U32}

# The text decoded after a position, and the continuation bytes before it
# that still await their lead byte, in order.
type Decoding is Data:
  Decoding{text: String, pending: List<&2, U32>}

# The class of a byte in UTF-8: ASCII, a continuation byte, the lead byte of
# a sequence of two, three or four bytes with its payload bits, or a byte no
# sequence starts with.
type ByteClass is Data:
  AsciiByte{}
  ContinuationByte{}
  Lead2{bits: U32}
  Lead3{bits: U32}
  Lead4{bits: U32}
  InvalidByte{}

# The value of a hexadecimal digit, once its range is known.
def Percent.hex.of(code: U32, digit: Bool, upper: Bool, lower: Bool) -> Maybe<&2, U32>:
  match digit:
    case True{}:
      Some{U32.sub(code, 48)}
    case False{}:
      match upper:
        case True{}:
          Some{U32.sub(code, 55)}
        case False{}:
          match lower:
            case True{}:
              Some{U32.sub(code, 87)}
            case False{}:
              None{}

# The value of a hexadecimal digit, in either case; None for any other
# character.
def Percent.hex(char: Char) -> Maybe<&2, U32>:
  match char:
    case Chr{+code}:
      Percent.hex.of(code, Bool.and(U32.is_ge(code, 48), U32.is_le(code, 57)),
        Bool.and(U32.is_ge(code, 65), U32.is_le(code, 70)), Bool.and(U32.is_ge(code, 97), U32.is_le(code, 102)))

# The byte of an escape whose two digits were read, in front of the pieces
# after it; None when a digit was not hexadecimal.
def Percent.scan.byte(high: Maybe<&2, U32>, low: Maybe<&2, U32>, after: List<&2, Piece>) -> Maybe<&2, List<&2, Piece>>:
  match high low:
    case Some{h} Some{l}:
      Some{Con{BytePiece{U32.add(U32.mul(h, 16), l)}, after}}
    case _ _:
      None{}

# A percent sign takes the two characters after it, which must both be
# characters still: a percent sign before fewer than two characters, or
# before a character that another escape took, is a bad escape.
def Percent.scan.escape(pieces: Maybe<&2, List<&2, Piece>>) -> Maybe<&2, List<&2, Piece>>:
  match pieces:
    case Some{Con{RawPiece{high}, Con{RawPiece{low}, after}}}:
      Percent.scan.byte(Percent.hex(high), Percent.hex(low), after)
    case other:
      None{}

# Any other character is kept, in front of the pieces after it.
def Percent.scan.keep(char: Char, pieces: Maybe<&2, List<&2, Piece>>) -> Maybe<&2, List<&2, Piece>>:
  match pieces:
    case Some{after}:
      Some{Con{RawPiece{char}, after}}
    case None{}:
      None{}

# One character, in front of the pieces of the text after it.
def Percent.scan.step(char: Char, pieces: Maybe<&2, List<&2, Piece>>, escape: Bool) -> Maybe<&2, List<&2, Piece>>:
  match escape:
    case True{}:
      Percent.scan.escape(pieces)
    case False{}:
      Percent.scan.keep(char, pieces)

# The pieces of a text, from its end: characters and the bytes of its
# escapes, in order; None at the first bad escape.
def Percent.scan(text: String) -> Maybe<&2, List<&2, Piece>>:
  match text:
    case SNil{}:
      Some{Nil{}}
    case SCon{+char, rest}:
      Percent.scan.step(char, Percent.scan(rest), Char.is_eq(char, '%'))

# The class of a byte, once its range is known.
def Percent.classify.of(code: U32, ascii: Bool, continuation: Bool, two: Bool, three: Bool, four: Bool) -> ByteClass:
  match ascii:
    case True{}:
      AsciiByte{}
    case False{}:
      match continuation:
        case True{}:
          ContinuationByte{}
        case False{}:
          match two:
            case True{}:
              Lead2{U32.and(code, 31)}
            case False{}:
              match three:
                case True{}:
                  Lead3{U32.and(code, 15)}
                case False{}:
                  match four:
                    case True{}:
                      Lead4{U32.and(code, 7)}
                    case False{}:
                      InvalidByte{}

# The class of a byte: below 128 ASCII, below 192 a continuation byte, below
# 224, 240 and 248 the lead byte of two, three and four bytes, and no lead
# byte from 248 on.
def Percent.classify(+code: U32) -> ByteClass:
  Percent.classify.of(code, U32.is_lt(code, 128), U32.is_lt(code, 192), U32.is_lt(code, 224), U32.is_lt(code, 240),
    U32.is_lt(code, 248))

# The code point so far followed by the six payload bits of a continuation
# byte.
def Percent.join(bits: U32, continuation: U32) -> U32:
  U32.or(U32.shln(bits, 6n), U32.and(continuation, 63))

# Whether a code point is the scalar value of a well-formed sequence: at
# least the minimum of its length, so that the encoding is the shortest, not
# a surrogate, and at most U+10FFFF.
def Percent.scalar(+code: U32, minimum: U32) -> Bool:
  Bool.and(U32.is_ge(code, minimum),
    Bool.and(Bool.not(Bool.and(U32.is_ge(code, 55296), U32.is_le(code, 57343))), U32.is_le(code, 1114111)))

# A completed character in front of the text, when its sequence was
# well-formed.
def Percent.emit(code: U32, text: String, valid: Bool) -> Maybe<&2, Decoding>:
  match valid:
    case True{}:
      Some{Decoding{SCon{Chr{code}, text}, Nil{}}}
    case False{}:
      None{}

# A continuation byte waits for its lead byte; a fourth one belongs to no
# sequence.
def Percent.assemble.pending(code: U32, text: String, pending: List<&2, U32>) -> Maybe<&2, Decoding>:
  match pending:
    case Con{first, Con{second, Con{third, more}}}:
      None{}
    case fewer:
      Some{Decoding{text, Con{code, fewer}}}

# A lead byte of two takes exactly one pending continuation byte.
def Percent.assemble.lead2(bits: U32, text: String, pending: List<&2, U32>) -> Maybe<&2, Decoding>:
  match pending:
    case Con{first, Nil{}}:
      +code = Percent.join(bits, first)
      Percent.emit(code, text, Percent.scalar(code, 128))
    case other:
      None{}

# A lead byte of three takes exactly two.
def Percent.assemble.lead3(bits: U32, text: String, pending: List<&2, U32>) -> Maybe<&2, Decoding>:
  match pending:
    case Con{first, Con{second, Nil{}}}:
      +code = Percent.join(Percent.join(bits, first), second)
      Percent.emit(code, text, Percent.scalar(code, 2048))
    case other:
      None{}

# A lead byte of four takes exactly three.
def Percent.assemble.lead4(bits: U32, text: String, pending: List<&2, U32>) -> Maybe<&2, Decoding>:
  match pending:
    case Con{first, Con{second, Con{third, Nil{}}}}:
      +code = Percent.join(Percent.join(Percent.join(bits, first), second), third)
      Percent.emit(code, text, Percent.scalar(code, 65536))
    case other:
      None{}

# A byte in front of what was decoded after it: ASCII is a character when
# no continuation byte is pending, a continuation byte waits, a lead byte
# completes its sequence, and anything else is refused.
def Percent.assemble.byte(class: ByteClass, code: U32, decoded: Maybe<&2, Decoding>) -> Maybe<&2, Decoding>:
  match class decoded:
    case AsciiByte{} Some{Decoding{text, Nil{}}}:
      Some{Decoding{SCon{Chr{code}, text}, Nil{}}}
    case ContinuationByte{} Some{Decoding{text, pending}}:
      Percent.assemble.pending(code, text, pending)
    case Lead2{bits} Some{Decoding{text, pending}}:
      Percent.assemble.lead2(bits, text, pending)
    case Lead3{bits} Some{Decoding{text, pending}}:
      Percent.assemble.lead3(bits, text, pending)
    case Lead4{bits} Some{Decoding{text, pending}}:
      Percent.assemble.lead4(bits, text, pending)
    case _ _:
      None{}

# A character kept as it is, in front of what was decoded after it; a
# continuation byte pending after it belongs to no sequence.
def Percent.assemble.raw(char: Char, decoded: Maybe<&2, Decoding>) -> Maybe<&2, Decoding>:
  match decoded:
    case Some{Decoding{text, Nil{}}}:
      Some{Decoding{SCon{char, text}, Nil{}}}
    case other:
      None{}

# One piece in front of what was decoded after it.
def Percent.assemble.piece(piece: Piece, decoded: Maybe<&2, Decoding>) -> Maybe<&2, Decoding>:
  match piece:
    case RawPiece{char}:
      Percent.assemble.raw(char, decoded)
    case BytePiece{+code}:
      Percent.assemble.byte(Percent.classify(code), code, decoded)

# The decoding of the pieces, from their end.
def Percent.assemble(pieces: List<&2, Piece>) -> Maybe<&2, Decoding>:
  match pieces:
    case Nil{}:
      Some{Decoding{SNil{}, Nil{}}}
    case Con{piece, rest}:
      Percent.assemble.piece(piece, Percent.assemble(rest))

# The decoding of the pieces a scan gave, when it gave some.
def Percent.decode.assembled(pieces: Maybe<&2, List<&2, Piece>>) -> Maybe<&2, Decoding>:
  match pieces:
    case Some{list}:
      Percent.assemble(list)
    case None{}:
      None{}

# The decoded text, when every continuation byte found its lead byte.
def Percent.decode.finish(decoded: Maybe<&2, Decoding>) -> Maybe<&2, String>:
  match decoded:
    case Some{Decoding{text, Nil{}}}:
      Some{text}
    case other:
      None{}

# The text of a percent-encoded text: each `%XX` escape, in either case of
# digit, is a byte, and the bytes of UTF-8 sequences are reassembled into
# their characters; None when an escape is incomplete or not hexadecimal,
# or the bytes are not well-formed UTF-8 (laws decode_plain, decode_literal,
# decode_multibyte and decode_refuses).
def Percent.decode(text: String) -> Maybe<&2, String>:
  Percent.decode.finish(Percent.decode.assembled(Percent.scan(text)))
