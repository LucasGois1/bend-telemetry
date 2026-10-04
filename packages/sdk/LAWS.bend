import Base
import ./sdk.bend as Sdk
import bend-telemetry-api@0.1.0.0/api.bend as Api

# The laws of bend-telemetry-sdk
# ==============================
#
# This file is the package's statement of claims. Each `law` below is a
# property the Bend checker must prove for every value it quantifies over,
# or, where it quantifies over nothing, a fact about literal values that the
# checker computes. PROOF.bend proves each law with a def of the same name
# (`law empty_is_unset` is proved by `def Laws.empty_is_unset`), and
#
#   ./bend packages/sdk/PROOF.bend --check-only
#
# prints "ALL PROOFS CHECK" only when every law in this file is proved and no
# definition PROOF.bend imports relies on `@unsafe` or foreign code. The laws
# import sdk.bend, the pure core, alone: host.bend, which reads the
# environment and writes to stderr, is never imported by a law.
# scripts/validate.sh runs that gate. The project owner reviews and owns
# these statements; the proofs may change freely as long as the statements
# hold.
#
# Every law is documented with the same headings:
#
#   Claim        what the law says, in plain words.
#   Requirement  the rule it enforces: a section of the OpenTelemetry
#                specification ("OTel" below: SDK Configuration, Environment
#                Variables; Trace SDK, Span limits), a decision of the
#                tracing SDK specification (issue #11, "spec #11") or of the
#                ticket #12.
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
#                              holds or that a parser refused a text.
#     {a == b : T}             the conclusion: a and b are the same value of
#                              type T.
#     P & Q                    both P and Q hold.
#
#   `+x` is a resource annotation: `+x` may be used several times. It never
#   changes what a law means. A law with no `for` line is a fact about the
#   literal values it names, proved by computation: a legitimate law, used
#   where the universal statement is beyond what the checker computes (the
#   checker evaluates Nat in unary, so the integers it reads here stay small,
#   and the largest accepted integer, 2147483647, is exercised by the
#   consumer rather than stated here).
#
# Values that appear in the statements:
#
#   Some{v}, None{}            a present and an absent optional value (Maybe).
#   Done{v}, Fail{reason}      a parsed value and a refusal (Result): every
#                              parser of the environment answers one, the
#                              refusal carrying the reason of its diagnostic.
#   True{}, False{}            Booleans.
#   0n, 128n                   natural numbers (Nat).
#   "text", [a, b], Nil{}      strings, lists and the empty list.
#   Sdk.Variable{name, value}  one variable of an environment, as the pure
#                              core receives it from host.bend.
#   Sdk.Name                   a definition of the package, from sdk.bend;
#                              Sdk.Warn{}, Sdk.AlwaysOff{} and the other
#                              constructors build its values.
#
# Definitions made in this file with `def` (`has_percent`, `names_distinct`,
# `name_among`) are independent specifications used to state the laws. They
# are deliberately not taken from the package, so each law compares the
# package with a second, simpler description of the rule.
#
# Contents
# --------
#
#   1. Package            name
#   2. Defaults           config_default, batch_default, resource_empty
#   3. Setters            setters_read_back ... programmatic_wins
#   4. Diagnostics        level_reflexive ... diagnostic_show
#   5. Parsing            bool_literal ... text_kept
#   6. Environment        variable_names ... otlp_kept
#   7. Percent decoding   decode_plain ... decode_refuses

# 1. Package
# ==========

# LAW name
#   Claim: the package answers its own BendHub name.
#   Proof: Laws.name, by computation.
law name:
  {Sdk.Package.name() == "bend-telemetry-sdk" : String}

# 2. Defaults
# ===========
#
# Config.default holds the specification's defaults and binds no exporter
# (spec #11, "Configuration"); the environment and the setters change it from
# there.

# LAW config_default
#   Claim: the default configuration is not disabled, reports at the info
#     level, has an empty user resource, no service name and no raw resource
#     attributes, the parent-based always-on sampler with no argument, no
#     programmatic processors, the batch options' defaults, the API's default
#     span limits, the `otlp` exporter selection, no OTLP values, a shutdown
#     timeout of 30000 milliseconds and a threshold precision of four digits.
#   Requirement: OTel, Environment Variables, General SDK Configuration
#     (OTEL_SDK_DISABLED false, OTEL_LOG_LEVEL info,
#     OTEL_TRACES_SAMPLER parentbased_always_on, OTEL_TRACES_EXPORTER otlp);
#     spec #11, "Configuration" ("Config.default has the specification's
#     defaults and no exporter") and "Samplers" ("rounded to four hex digits
#     of precision by default"); the shutdown timeout is this package's
#     choice, the export timeout's default, since a shutdown runs one last
#     export.
#   Why: an application that configures nothing must behave as any
#     OpenTelemetry SDK does.
#   Proof: Laws.config_default, by computation.
law config_default:
  {Sdk.Config.disabled(Sdk.Config.default()) == False{} : Bool} &
  {Sdk.Config.level(Sdk.Config.default()) == Sdk.Info{} : Sdk.Level} &
  {Sdk.Config.resource(Sdk.Config.default()) == Sdk.Resource.empty() : Sdk.Resource} &
  {Sdk.Config.service_name(Sdk.Config.default()) == None{} : Maybe<&2, String>} &
  {Sdk.Config.resource_attributes(Sdk.Config.default()) == None{} : Maybe<&2, String>} &
  {Sdk.Config.sampler(Sdk.Config.default()) == Sdk.ParentBasedAlwaysOn{} : Sdk.SamplerSelection} &
  {Sdk.Config.sampler_arg(Sdk.Config.default()) == None{} : Maybe<&2, String>} &
  {Sdk.Config.processors(Sdk.Config.default()) == Nil{} : List<&2, Sdk.ProcessorConfig>} &
  {Sdk.Config.batch(Sdk.Config.default()) == Sdk.BatchOptions.default() : Sdk.BatchOptions} &
  {Sdk.Config.span_limits(Sdk.Config.default()) == Api.SpanLimits.default() : Api.SpanLimits} &
  {Sdk.Config.exporter(Sdk.Config.default()) == Sdk.ExternalExporter{"otlp"} : Sdk.ExporterSelection} &
  {Sdk.Config.otlp(Sdk.Config.default()) == Nil{} : List<&2, Sdk.Variable>} &
  {Sdk.Config.shutdown_timeout(Sdk.Config.default()) == Some{30000n} : Maybe<&2, Nat>} &
  {Sdk.Config.threshold_precision(Sdk.Config.default()) == 4n : Nat}

# LAW batch_default
#   Claim: the default batch options are a queue of 2048 spans, a schedule
#     delay of 5000 milliseconds, an export timeout of 30000 milliseconds and
#     batches of 512 spans.
#   Requirement: OTel, Environment Variables, Batch Span Processor: the
#     defaults of OTEL_BSP_MAX_QUEUE_SIZE, OTEL_BSP_SCHEDULE_DELAY,
#     OTEL_BSP_EXPORT_TIMEOUT and OTEL_BSP_MAX_EXPORT_BATCH_SIZE; spec #11,
#     user story 11.
#   Proof: Laws.batch_default, by computation.
law batch_default:
  {Sdk.BatchOptions.queue_size(Sdk.BatchOptions.default()) == 2048n : Nat} &
  {Sdk.BatchOptions.schedule_delay(Sdk.BatchOptions.default()) == 5000n : Nat} &
  {Sdk.BatchOptions.export_timeout(Sdk.BatchOptions.default()) == Some{30000n} : Maybe<&2, Nat>} &
  {Sdk.BatchOptions.batch_size(Sdk.BatchOptions.default()) == 512n : Nat}

# LAW resource_empty
#   Claim: the empty resource has no attributes and an empty schema URL, and
#     a created resource answers what it was created from.
#   Requirement: spec #11, "Resource": "A resource is attributes plus a
#     schema URL. Operations: empty, create".
#   Proof: Laws.resource_empty, by computation.
law resource_empty:
  for attributes: Api.Attributes
  for schema_url: String
  {Sdk.Resource.attributes(Sdk.Resource.empty()) == Api.Attributes.empty() : Api.Attributes} &
  {Sdk.Resource.schema_url(Sdk.Resource.empty()) == "" : String} &
  {Sdk.Resource.attributes(Sdk.Resource.create(attributes, schema_url)) == attributes : Api.Attributes} &
  {Sdk.Resource.schema_url(Sdk.Resource.create(attributes, schema_url)) == schema_url : String}

# 3. Setters
# ==========
#
# The pure setters apply programmatic settings on top of any configuration
# (spec #11, "Configuration": "Pure setters apply programmatic settings on
# top"). Each one changes its field and nothing else.

# LAW setters_read_back
#   Claim: after a setter, the field's reader answers the value set, whatever
#     the configuration held before.
#   Requirement: ticket #12, "Pure setters for programmatic configuration".
#   Proof: Laws.setters_read_back, by opening the record.
law setters_read_back:
  for config: Sdk.Config
  for disabled: Bool
  for level: Sdk.Level
  for resource: Sdk.Resource
  for service_name: String
  for resource_attributes: String
  for sampler: Sdk.SamplerSelection
  for sampler_arg: String
  for processors: List<&2, Sdk.ProcessorConfig>
  for batch: Sdk.BatchOptions
  for span_limits: Api.SpanLimits
  for exporter: Sdk.ExporterSelection
  for shutdown_timeout: Maybe<&2, Nat>
  for threshold_precision: Nat
  {Sdk.Config.disabled(Sdk.Config.with_disabled(config, disabled)) == disabled : Bool} &
  {Sdk.Config.level(Sdk.Config.with_level(config, level)) == level : Sdk.Level} &
  {Sdk.Config.resource(Sdk.Config.with_resource(config, resource)) == resource : Sdk.Resource} &
  {Sdk.Config.service_name(Sdk.Config.with_service_name(config, service_name)) == Some{service_name} : Maybe<&2, String>} &
  {Sdk.Config.resource_attributes(Sdk.Config.with_resource_attributes(config, resource_attributes)) ==
    Some{resource_attributes} : Maybe<&2, String>} &
  {Sdk.Config.sampler(Sdk.Config.with_sampler(config, sampler)) == sampler : Sdk.SamplerSelection} &
  {Sdk.Config.sampler_arg(Sdk.Config.with_sampler_arg(config, sampler_arg)) == Some{sampler_arg} : Maybe<&2, String>} &
  {Sdk.Config.processors(Sdk.Config.with_processors(config, processors)) == processors : List<&2, Sdk.ProcessorConfig>} &
  {Sdk.Config.batch(Sdk.Config.with_batch(config, batch)) == batch : Sdk.BatchOptions} &
  {Sdk.Config.span_limits(Sdk.Config.with_span_limits(config, span_limits)) == span_limits : Api.SpanLimits} &
  {Sdk.Config.exporter(Sdk.Config.with_exporter(config, exporter)) == exporter : Sdk.ExporterSelection} &
  {Sdk.Config.shutdown_timeout(Sdk.Config.with_shutdown_timeout(config, shutdown_timeout)) == shutdown_timeout : Maybe<&2, Nat>} &
  {Sdk.Config.threshold_precision(Sdk.Config.with_threshold_precision(config, threshold_precision)) == threshold_precision : Nat}

# LAW batch_setters_read_back
#   Claim: each batch option's setter is read back by its reader.
#   Proof: Laws.batch_setters_read_back, by opening the record.
law batch_setters_read_back:
  for options: Sdk.BatchOptions
  for queue_size: Nat
  for schedule_delay: Nat
  for export_timeout: Maybe<&2, Nat>
  for batch_size: Nat
  {Sdk.BatchOptions.queue_size(Sdk.BatchOptions.with_queue_size(options, queue_size)) == queue_size : Nat} &
  {Sdk.BatchOptions.schedule_delay(Sdk.BatchOptions.with_schedule_delay(options, schedule_delay)) == schedule_delay : Nat} &
  {Sdk.BatchOptions.export_timeout(Sdk.BatchOptions.with_export_timeout(options, export_timeout)) == export_timeout : Maybe<&2, Nat>} &
  {Sdk.BatchOptions.batch_size(Sdk.BatchOptions.with_batch_size(options, batch_size)) == batch_size : Nat}

# LAW otlp_value_set
#   Claim: an OTLP value set on a configuration is read back by its name, a
#     name never set reads none, and setting a name again replaces its value
#     in place: literal cases.
#   Requirement: spec #11, "Configuration": the OTLP option values are read
#     and kept as text for the OTLP exporter package.
#   Proof: Laws.otlp_value_set, by computation.
law otlp_value_set:
  {Sdk.Config.otlp_value(Sdk.Config.with_otlp_value(Sdk.Config.default(), "OTEL_EXPORTER_OTLP_ENDPOINT", "http://a"),
    "OTEL_EXPORTER_OTLP_ENDPOINT") == Some{"http://a"} : Maybe<&2, String>} &
  {Sdk.Config.otlp_value(Sdk.Config.with_otlp_value(Sdk.Config.default(), "OTEL_EXPORTER_OTLP_ENDPOINT", "http://a"),
    "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT") == None{} : Maybe<&2, String>} &
  {Sdk.Config.otlp(Sdk.Config.with_otlp_value(Sdk.Config.with_otlp_value(Sdk.Config.default(),
    "OTEL_EXPORTER_OTLP_ENDPOINT", "http://a"), "OTEL_EXPORTER_OTLP_ENDPOINT", "http://b")) ==
    [Sdk.Variable{"OTEL_EXPORTER_OTLP_ENDPOINT", "http://b"}] : List<&2, Sdk.Variable>}

# LAW programmatic_wins
#   Claim: a setter applied to a configuration read from any environment
#     answers the value set: programmatic settings win over the environment.
#   Requirement: spec #11, user story 3: "programmatic settings to win over
#     the environment, and the environment over the defaults".
#   Why: a deployment's variables must not override what the application
#     pinned in code.
#   Proof: Laws.programmatic_wins, via proofs/config.bend: the setter's law
#     holds for the configuration the environment produced, whatever it is.
law programmatic_wins:
  for +variables: List<&2, Sdk.Variable>
  for +disabled: Bool
  for +sampler: Sdk.SamplerSelection
  for +span_limits: Api.SpanLimits
  {Sdk.Config.disabled(Sdk.Config.with_disabled(Sdk.Configured.config(Sdk.Config.from_variables(variables)), disabled)) ==
    disabled : Bool} &
  {Sdk.Config.sampler(Sdk.Config.with_sampler(Sdk.Configured.config(Sdk.Config.from_variables(variables)), sampler)) ==
    sampler : Sdk.SamplerSelection} &
  {Sdk.Config.span_limits(Sdk.Config.with_span_limits(Sdk.Configured.config(Sdk.Config.from_variables(variables)), span_limits)) ==
    span_limits : Api.SpanLimits}

# 4. Diagnostics
# ==============
#
# A diagnostic is data: a level, a component and a message (spec #11,
# "Diagnostics"). The reporter drops a diagnostic whose level is below the
# configured one; Level.is_at_least is that decision.

# LAW level_reflexive
#   Claim: every level reaches itself: a diagnostic at the configured level
#     is reported.
#   Requirement: spec #11, "Diagnostics": "drops diagnostics below the
#     configured level".
#   Proof: Laws.level_reflexive, by cases on the level.
law level_reflexive:
  for +level: Sdk.Level
  {Sdk.Level.is_at_least(level, level) == True{} : Bool}

# LAW level_order
#   Claim: the levels order debug, info, warn, error: a level below the
#     configured one does not reach it, and a level above does.
#   Requirement: as level_reflexive; OTel, Environment Variables,
#     OTEL_LOG_LEVEL.
#   Why: an operator who sets `warn` must not see info lines, and must see
#     every error.
#   Proof: Laws.level_order, by computation.
law level_order:
  {Sdk.Level.is_at_least(Sdk.Debug{}, Sdk.Info{}) == False{} : Bool} &
  {Sdk.Level.is_at_least(Sdk.Info{}, Sdk.Warn{}) == False{} : Bool} &
  {Sdk.Level.is_at_least(Sdk.Warn{}, Sdk.Error{}) == False{} : Bool} &
  {Sdk.Level.is_at_least(Sdk.Debug{}, Sdk.Error{}) == False{} : Bool} &
  {Sdk.Level.is_at_least(Sdk.Info{}, Sdk.Debug{}) == True{} : Bool} &
  {Sdk.Level.is_at_least(Sdk.Warn{}, Sdk.Info{}) == True{} : Bool} &
  {Sdk.Level.is_at_least(Sdk.Error{}, Sdk.Warn{}) == True{} : Bool} &
  {Sdk.Level.is_at_least(Sdk.Error{}, Sdk.Debug{}) == True{} : Bool}

# LAW level_text
#   Claim: the text of each level is its lowercase name, which the
#     enumeration parser reads back.
#   Proof: Laws.level_text, by computation.
law level_text:
  {Sdk.Level.show(Sdk.Debug{}) == "debug" : String} &
  {Sdk.Level.show(Sdk.Info{}) == "info" : String} &
  {Sdk.Level.show(Sdk.Warn{}) == "warn" : String} &
  {Sdk.Level.show(Sdk.Error{}) == "error" : String} &
  {Sdk.Env.read_level(Sdk.Level.show(Sdk.Debug{})) == Done{Sdk.Debug{}} : Result<&2, &2, String, Sdk.Level>} &
  {Sdk.Env.read_level(Sdk.Level.show(Sdk.Error{})) == Done{Sdk.Error{}} : Result<&2, &2, String, Sdk.Level>}

# LAW diagnostic_readers
#   Claim: the readers of a diagnostic answer its level, component and
#     message.
#   Proof: Laws.diagnostic_readers, by computation.
law diagnostic_readers:
  for +level: Sdk.Level
  for +component: String
  for +message: String
  {Sdk.Diagnostic.level(Sdk.Diagnostic{level, component, message}) == level : Sdk.Level} &
  {Sdk.Diagnostic.component(Sdk.Diagnostic{level, component, message}) == component : String} &
  {Sdk.Diagnostic.message(Sdk.Diagnostic{level, component, message}) == message : String}

# LAW diagnostic_show
#   Claim: the text of a diagnostic is its level in brackets, its component
#     and its message.
#   Requirement: spec #11, user story 15: diagnostics an operator reads on
#     stderr.
#   Proof: Laws.diagnostic_show, by computation.
law diagnostic_show:
  {Sdk.Diagnostic.show(Sdk.Diagnostic{Sdk.Warn{}, "config", "a message"}) == "[warn] config: a message" : String}

# 5. Parsing
# ==========
#
# Each parser reads the text of one kind of variable and answers the value
# or the reason of its refusal (OTel, Environment Variables, "Boolean value",
# "Numeric value", "Duration", "Timeout", "Enum value"; spec #11,
# "Configuration", parsing rules). The laws state them on literal texts.

# LAW bool_literal
#   Claim: a Boolean is true for `true` in any case, false for `false` in any
#     case, and refused for any other text: `yes`, `1`, `0`, `on`, `t`, a
#     surrounding space and the empty text.
#   Requirement: OTel, Environment Variables, Boolean value: "set to true
#     only by the case-insensitive string true ... any value other than a
#     true value, case-insensitive string false, empty, or unset ... a
#     warning SHOULD be logged"; spec #11, "a Boolean is true only for a
#     case-insensitive `true`, with a warning for any other non-empty text".
#   Why: `OTEL_SDK_DISABLED=1` must not switch tracing off silently, and
#     must not fail the application either.
#   Proof: Laws.bool_literal, by computation.
law bool_literal:
  {Sdk.Env.read_bool("true") == Done{True{}} : Result<&2, &2, String, Bool>} &
  {Sdk.Env.read_bool("TRUE") == Done{True{}} : Result<&2, &2, String, Bool>} &
  {Sdk.Env.read_bool("True") == Done{True{}} : Result<&2, &2, String, Bool>} &
  {Sdk.Env.read_bool("false") == Done{False{}} : Result<&2, &2, String, Bool>} &
  {Sdk.Env.read_bool("FALSE") == Done{False{}} : Result<&2, &2, String, Bool>} &
  {Sdk.Env.read_bool("yes") == Fail{"is not a Boolean (true or false)"} : Result<&2, &2, String, Bool>} &
  {Result.is_fail(&2, &2, String, Bool, Sdk.Env.read_bool("1")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Bool, Sdk.Env.read_bool("0")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Bool, Sdk.Env.read_bool("on")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Bool, Sdk.Env.read_bool("t")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Bool, Sdk.Env.read_bool(" true")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Bool, Sdk.Env.read_bool("true ")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Bool, Sdk.Env.read_bool("")) == True{} : Bool}

# LAW count_literal
#   Claim: a count is a text of decimal digits, leading zeros accepted, from
#     0 to 2147483647: zero, small values and 512 are read; the value just
#     past the bound, 2^32, a 20-digit number, a sign, a point, an exponent,
#     a hexadecimal prefix, a space on either side, letters, a separator and
#     the empty text are refused.
#   Requirement: OTel, Environment Variables, Numeric value: "MUST be an
#     integer. The value is non-negative"; spec #11, "integers are
#     non-negative and at most 2^31 - 1".
#   Reading: the bound is checked on the text, so the checker refuses
#     2147483648 without computing it; the consumer reads 2147483647 at run
#     time.
#   Proof: Laws.count_literal, by computation.
law count_literal:
  {Sdk.Env.read_count("0") == Done{0n} : Result<&2, &2, String, Nat>} &
  {Sdk.Env.read_count("1") == Done{1n} : Result<&2, &2, String, Nat>} &
  {Sdk.Env.read_count("0042") == Done{42n} : Result<&2, &2, String, Nat>} &
  {Sdk.Env.read_count("128") == Done{128n} : Result<&2, &2, String, Nat>} &
  {Sdk.Env.read_count("512") == Done{512n} : Result<&2, &2, String, Nat>} &
  {Sdk.Env.read_count("2147483648") == Fail{"is not an integer from 0 to 2147483647"} : Result<&2, &2, String, Nat>} &
  {Result.is_fail(&2, &2, String, Nat, Sdk.Env.read_count("4294967296")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Nat, Sdk.Env.read_count("99999999999999999999")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Nat, Sdk.Env.read_count("-1")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Nat, Sdk.Env.read_count("+1")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Nat, Sdk.Env.read_count("1.0")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Nat, Sdk.Env.read_count("1e3")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Nat, Sdk.Env.read_count("0x10")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Nat, Sdk.Env.read_count(" 1")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Nat, Sdk.Env.read_count("1 ")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Nat, Sdk.Env.read_count("abc")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Nat, Sdk.Env.read_count("1,000")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Nat, Sdk.Env.read_count("")) == True{} : Bool}

# LAW size_literal
#   Claim: a size is a count of at least one: zero is refused with the
#     reason that names the range, and one, 16 and 512 are read.
#   Requirement: OTel, Environment Variables, Batch Span Processor: the queue
#     and batch sizes count spans; spec #11, "Provider construction":
#     non-positive sizes are a configuration error for programmatic settings,
#     and environment parsing never produces an error, so a zero from the
#     environment is reported and leaves the default.
#   Proof: Laws.size_literal, by computation.
law size_literal:
  {Sdk.Env.read_size("1") == Done{1n} : Result<&2, &2, String, Nat>} &
  {Sdk.Env.read_size("16") == Done{16n} : Result<&2, &2, String, Nat>} &
  {Sdk.Env.read_size("512") == Done{512n} : Result<&2, &2, String, Nat>} &
  {Sdk.Env.read_size("0") == Fail{"is not an integer from 1 to 2147483647"} : Result<&2, &2, String, Nat>} &
  {Result.is_fail(&2, &2, String, Nat, Sdk.Env.read_size("000")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Nat, Sdk.Env.read_size("2147483648")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Nat, Sdk.Env.read_size("-1")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Nat, Sdk.Env.read_size("12x")) == True{} : Bool}

# LAW duration_literal
#   Claim: a duration is a count of milliseconds: zero, 250 and 1000 are
#     read; a unit suffix, a fraction and a negative number are refused.
#   Requirement: OTel, Environment Variables, Duration: "an integer
#     representing a number of milliseconds. The value is non-negative";
#     spec #11, "durations are integer milliseconds".
#   Proof: Laws.duration_literal, by computation.
law duration_literal:
  {Sdk.Env.read_duration("0") == Done{0n} : Result<&2, &2, String, Nat>} &
  {Sdk.Env.read_duration("250") == Done{250n} : Result<&2, &2, String, Nat>} &
  {Sdk.Env.read_duration("1000") == Done{1000n} : Result<&2, &2, String, Nat>} &
  {Sdk.Env.read_duration("5s") == Fail{"is not a duration in milliseconds, an integer from 0 to 2147483647"} :
    Result<&2, &2, String, Nat>} &
  {Result.is_fail(&2, &2, String, Nat, Sdk.Env.read_duration("1.5")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Nat, Sdk.Env.read_duration("-5")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Nat, Sdk.Env.read_duration("2147483648")) == True{} : Bool}

# LAW timeout_literal
#   Claim: a timeout is a duration where zero means no limit: `0` reads as
#     none, 1000 as that many milliseconds, and the refusals are those of a
#     duration.
#   Requirement: OTel, Environment Variables, Timeout: an integer of
#     milliseconds; spec #11, "a timeout of zero means no limit".
#   Why: an operator who wants an export never cut short writes
#     `OTEL_BSP_EXPORT_TIMEOUT=0`, as in other SDKs.
#   Proof: Laws.timeout_literal, by computation.
law timeout_literal:
  {Sdk.Env.read_timeout("0") == Done{None{}} : Result<&2, &2, String, Maybe<&2, Nat>>} &
  {Sdk.Env.read_timeout("000") == Done{None{}} : Result<&2, &2, String, Maybe<&2, Nat>>} &
  {Sdk.Env.read_timeout("1000") == Done{Some{1000n}} : Result<&2, &2, String, Maybe<&2, Nat>>} &
  {Sdk.Env.read_timeout("abc") == Fail{"is not a timeout in milliseconds, an integer from 0 (no limit) to 2147483647"} :
    Result<&2, &2, String, Maybe<&2, Nat>>} &
  {Result.is_fail(&2, &2, String, Maybe<&2, Nat>, Sdk.Env.read_timeout("-1")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Maybe<&2, Nat>, Sdk.Env.read_timeout("2147483648")) == True{} : Bool}

# LAW level_literal
#   Claim: the level names are read in any case; `warning`, `verbose`, a
#     trailing space and the empty text are refused with a reason that lists
#     the names.
#   Requirement: OTel, Environment Variables, Enum value: "case-insensitive
#     ... an unknown value SHOULD be reported as a warning and the default
#     value used"; OTEL_LOG_LEVEL's values are this SDK's four levels.
#   Proof: Laws.level_literal, by computation.
law level_literal:
  {Sdk.Env.read_level("debug") == Done{Sdk.Debug{}} : Result<&2, &2, String, Sdk.Level>} &
  {Sdk.Env.read_level("INFO") == Done{Sdk.Info{}} : Result<&2, &2, String, Sdk.Level>} &
  {Sdk.Env.read_level("Warn") == Done{Sdk.Warn{}} : Result<&2, &2, String, Sdk.Level>} &
  {Sdk.Env.read_level("error") == Done{Sdk.Error{}} : Result<&2, &2, String, Sdk.Level>} &
  {Sdk.Env.read_level("verbose") == Fail{"is not a level: debug, info, warn or error"} : Result<&2, &2, String, Sdk.Level>} &
  {Result.is_fail(&2, &2, String, Sdk.Level, Sdk.Env.read_level("warning")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Sdk.Level, Sdk.Env.read_level("info ")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Sdk.Level, Sdk.Env.read_level("")) == True{} : Bool}

# LAW sampler_literal
#   Claim: the six sampler names are read in any case; the samplers this SDK
#     does not provide (`jaeger_remote`, `parentbased_jaeger_remote`,
#     `xray`) and unknown names are refused, each with its reason.
#   Requirement: OTel, Environment Variables, General SDK Configuration,
#     OTEL_TRACES_SAMPLER; spec #11, "Configuration": "`jaeger_remote`,
#     `parentbased_jaeger_remote`, `xray` and unknown values are reported and
#     ignored".
#   Proof: Laws.sampler_literal, by computation.
law sampler_literal:
  {Sdk.Env.read_sampler("always_on") == Done{Sdk.AlwaysOn{}} : Result<&2, &2, String, Sdk.SamplerSelection>} &
  {Sdk.Env.read_sampler("ALWAYS_OFF") == Done{Sdk.AlwaysOff{}} : Result<&2, &2, String, Sdk.SamplerSelection>} &
  {Sdk.Env.read_sampler("TraceIdRatio") == Done{Sdk.TraceIdRatio{}} : Result<&2, &2, String, Sdk.SamplerSelection>} &
  {Sdk.Env.read_sampler("parentbased_always_on") == Done{Sdk.ParentBasedAlwaysOn{}} : Result<&2, &2, String, Sdk.SamplerSelection>} &
  {Sdk.Env.read_sampler("parentbased_always_off") == Done{Sdk.ParentBasedAlwaysOff{}} : Result<&2, &2, String, Sdk.SamplerSelection>} &
  {Sdk.Env.read_sampler("parentbased_traceidratio") == Done{Sdk.ParentBasedTraceIdRatio{}} :
    Result<&2, &2, String, Sdk.SamplerSelection>} &
  {Sdk.Env.read_sampler("xray") == Fail{"names a sampler this SDK does not provide"} : Result<&2, &2, String, Sdk.SamplerSelection>} &
  {Result.is_fail(&2, &2, String, Sdk.SamplerSelection, Sdk.Env.read_sampler("jaeger_remote")) == True{} : Bool} &
  {Result.is_fail(&2, &2, String, Sdk.SamplerSelection, Sdk.Env.read_sampler("parentbased_jaeger_remote")) == True{} : Bool} &
  {Sdk.Env.read_sampler("always-on") == Fail{"is not a sampler: always_on, always_off, traceidratio, parentbased_always_on, parentbased_always_off or parentbased_traceidratio"} :
    Result<&2, &2, String, Sdk.SamplerSelection>} &
  {Result.is_fail(&2, &2, String, Sdk.SamplerSelection, Sdk.Env.read_sampler("")) == True{} : Bool}

# LAW exporter_literal
#   Claim: `console` and `none` select the built-in choices in any case, any
#     other single name selects the external exporter of that name in
#     lowercase, to be resolved when the provider is built, and a list of
#     names is refused.
#   Requirement: OTel, Environment Variables, Exporter Selection,
#     OTEL_TRACES_EXPORTER; spec #11, "Configuration": "accepts `console`,
#     `none` and the name of the external exporter the provider was built
#     with; `otlp` (also the default) without an OTLP-built provider,
#     `zipkin`, lists and unknown values are reported and resolve to none".
#   Reading: a name is kept here and judged at provider construction, which
#     alone knows the external exporter's name; a list cannot be served and
#     is refused at once.
#   Proof: Laws.exporter_literal, by computation.
law exporter_literal:
  {Sdk.Env.read_exporter("console") == Done{Sdk.ConsoleExporter{}} : Result<&2, &2, String, Sdk.ExporterSelection>} &
  {Sdk.Env.read_exporter("NONE") == Done{Sdk.NoExporter{}} : Result<&2, &2, String, Sdk.ExporterSelection>} &
  {Sdk.Env.read_exporter("otlp") == Done{Sdk.ExternalExporter{"otlp"}} : Result<&2, &2, String, Sdk.ExporterSelection>} &
  {Sdk.Env.read_exporter("Zipkin") == Done{Sdk.ExternalExporter{"zipkin"}} : Result<&2, &2, String, Sdk.ExporterSelection>} &
  {Sdk.Env.read_exporter("console,otlp") ==
    Fail{"names several exporters; this SDK takes one: console, none or the name of the exporter the provider is built with"} :
    Result<&2, &2, String, Sdk.ExporterSelection>} &
  {Result.is_fail(&2, &2, String, Sdk.ExporterSelection, Sdk.Env.read_exporter("")) == True{} : Bool}

# LAW text_kept
#   Claim: a variable kept as text is read as it is, whatever it holds.
#   Requirement: ticket #12: OTEL_RESOURCE_ATTRIBUTES and
#     OTEL_TRACES_SAMPLER_ARG are kept as raw text for the resource and
#     sampler tickets; spec #11: the OTLP option values are read as text.
#   Proof: Laws.text_kept, by computation.
law text_kept:
  for +text: String
  {Sdk.Env.read_text(text) == Done{text} : Result<&2, &2, String, String>}

# 6. Environment
# ==============
#
# Config.from_variables is the pure core of Config.from_env: it starts from
# the defaults, applies every supported variable of the list it is given and
# answers the configuration with the diagnostics of the invalid values.
# host.bend reads the variables and calls it.

# Whether a name is among the names of a list: an ordinary search.
def name_among(+name: String, names: List<&2, String>) -> Bool:
  match names:
    case Nil{}:
      False{}
    case Con{other, rest}:
      Bool.or(String.eq(name, other), name_among(name, rest))

# No two names are the same: no name appears among the names after it.
def names_distinct(names: List<&2, String>) -> Bool:
  match names:
    case Nil{}:
      True{}
    case Con{name, +rest}:
      Bool.and(Bool.not(name_among(name, rest)), names_distinct(rest))

# LAW variable_names
#   Claim: the supported variables are 37 distinct names, and the first and
#     the last are OTEL_SDK_DISABLED and OTEL_EXPORTER_OTLP_TRACES_PROTOCOL.
#   Requirement: spec #11, "Configuration", "Supported variables".
#   Why: Config.from_env reads exactly this list; a duplicate would read a
#     variable twice and a missing name would never be read.
#   Proof: Laws.variable_names, by computation.
law variable_names:
  {List.length(&2, String, Sdk.Config.variable_names()) == 37n : Nat} &
  {names_distinct(Sdk.Config.variable_names()) == True{} : Bool} &
  {List.head(&2, String, Sdk.Config.variable_names()) == Some{"OTEL_SDK_DISABLED"} : Maybe<&2, String>} &
  {List.last(&2, String, Sdk.Config.variable_names()) == Some{"OTEL_EXPORTER_OTLP_TRACES_PROTOCOL"} : Maybe<&2, String>}

# LAW unset_is_default
#   Claim: an empty environment gives the default configuration and no
#     diagnostic.
#   Requirement: spec #11, "Configuration": "starts from the defaults".
#   Proof: Laws.unset_is_default, by computation.
law unset_is_default:
  {Sdk.Config.from_variables(Nil{}) == Sdk.Configured{Sdk.Config.default(), Nil{}} : Sdk.Configured}

# LAW empty_is_unset
#   Claim: a variable with an empty value changes nothing, whatever its name
#     and whatever the other variables: an empty value is an unset variable.
#   Requirement: OTel, Environment Variables, Parsing empty value: "The SDK
#     MUST interpret an empty value of an environment variable the same way
#     as when the variable is unset"; spec #11, "an empty value is unset".
#   Why: a deployment template that leaves `OTEL_SERVICE_NAME=` blank must
#     behave as one that omits it, with no warning.
#   Proof: Laws.empty_is_unset, by computation: the lookup of every variable
#     passes over an empty value.
law empty_is_unset:
  for +name: String
  for +variables: List<&2, Sdk.Variable>
  {Sdk.Config.from_variables(Con{Sdk.Variable{name, ""}, variables}) == Sdk.Config.from_variables(variables) : Sdk.Configured}

# An environment as an operator sets one: every kind of variable, in an
# order of its own, with an empty value among them.
def example() -> List<&2, Sdk.Variable>:
  [Sdk.Variable{"OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "20"}, Sdk.Variable{"OTEL_SDK_DISABLED", "True"},
   Sdk.Variable{"OTEL_LOG_LEVEL", "DEBUG"}, Sdk.Variable{"OTEL_SERVICE_NAME", "shop"},
   Sdk.Variable{"OTEL_RESOURCE_ATTRIBUTES", "team=a%20b"}, Sdk.Variable{"OTEL_TRACES_SAMPLER", "traceidratio"},
   Sdk.Variable{"OTEL_TRACES_SAMPLER_ARG", "0.25"}, Sdk.Variable{"OTEL_TRACES_EXPORTER", "Console"},
   Sdk.Variable{"OTEL_BSP_SCHEDULE_DELAY", "250"}, Sdk.Variable{"OTEL_BSP_EXPORT_TIMEOUT", "0"},
   Sdk.Variable{"OTEL_BSP_MAX_QUEUE_SIZE", "16"}, Sdk.Variable{"OTEL_BSP_MAX_EXPORT_BATCH_SIZE", "8"},
   Sdk.Variable{"OTEL_ATTRIBUTE_COUNT_LIMIT", "10"}, Sdk.Variable{"OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT", "64"},
   Sdk.Variable{"OTEL_SPAN_EVENT_COUNT_LIMIT", "7"}, Sdk.Variable{"OTEL_SPAN_LINK_COUNT_LIMIT", "3"},
   Sdk.Variable{"OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT", "5"}, Sdk.Variable{"OTEL_LINK_ATTRIBUTE_COUNT_LIMIT", "6"},
   Sdk.Variable{"OTEL_EXPORTER_OTLP_ENDPOINT", ""},
   Sdk.Variable{"OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "http://collector:4318/v1/traces"}]

# LAW environment_literal
#   Claim: a literal environment is read as the parsing rules say: the
#     disabled flag, the level, the service name, the raw resource
#     attributes, the sampler and its raw argument, the exporter, the four
#     batch options with a timeout of zero as no limit, the span limits with
#     the span-specific count over the general one, and one OTLP value, the
#     empty one unset, with no diagnostic.
#   Requirement: spec #11, "Configuration", the supported variables and
#     their rules.
#   Proof: Laws.environment_literal, by computation.
law environment_literal:
  {Sdk.Configured.diagnostics(Sdk.Config.from_variables(example())) == Nil{} : List<&2, Sdk.Diagnostic>} &
  {Sdk.Config.disabled(Sdk.Configured.config(Sdk.Config.from_variables(example()))) == True{} : Bool} &
  {Sdk.Config.level(Sdk.Configured.config(Sdk.Config.from_variables(example()))) == Sdk.Debug{} : Sdk.Level} &
  {Sdk.Config.service_name(Sdk.Configured.config(Sdk.Config.from_variables(example()))) == Some{"shop"} : Maybe<&2, String>} &
  {Sdk.Config.resource_attributes(Sdk.Configured.config(Sdk.Config.from_variables(example()))) ==
    Some{"team=a%20b"} : Maybe<&2, String>} &
  {Sdk.Config.sampler(Sdk.Configured.config(Sdk.Config.from_variables(example()))) == Sdk.TraceIdRatio{} : Sdk.SamplerSelection} &
  {Sdk.Config.sampler_arg(Sdk.Configured.config(Sdk.Config.from_variables(example()))) == Some{"0.25"} : Maybe<&2, String>} &
  {Sdk.Config.exporter(Sdk.Configured.config(Sdk.Config.from_variables(example()))) == Sdk.ConsoleExporter{} : Sdk.ExporterSelection} &
  {Sdk.Config.batch(Sdk.Configured.config(Sdk.Config.from_variables(example()))) ==
    Sdk.BatchOptions{16n, 250n, None{}, 8n} : Sdk.BatchOptions} &
  {Sdk.Config.span_limits(Sdk.Configured.config(Sdk.Config.from_variables(example()))) ==
    Api.SpanLimits{Some{20n}, Some{64n}, Some{7n}, Some{3n}, Some{5n}, Some{6n}} : Api.SpanLimits} &
  {Sdk.Config.otlp(Sdk.Configured.config(Sdk.Config.from_variables(example()))) ==
    [Sdk.Variable{"OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "http://collector:4318/v1/traces"}] : List<&2, Sdk.Variable>} &
  {Sdk.Config.otlp_value(Sdk.Configured.config(Sdk.Config.from_variables(example())), "OTEL_EXPORTER_OTLP_ENDPOINT") ==
    None{} : Maybe<&2, String>}

# LAW invalid_boolean_once
#   Claim: any non-empty text that the Boolean parser refuses leaves the
#     default configuration and yields exactly one diagnostic: a warning of
#     the config component naming the variable, the text and the reason.
#   Requirement: spec #11, "Configuration": "any invalid value leaves the
#     default"; user story 4: "a warning and the default, never a failure";
#     ticket #12: "an invalid value leaves the default and produces exactly
#     one diagnostic".
#   Why: a typo in a deployment must be visible once and change nothing
#     else.
#   Reading: `present` says the text is not empty (an empty text is unset)
#     and `invalid` that the parser refused it with `reason`; the diagnostic
#     is the one Env.message builds from the three.
#   Proof: Laws.invalid_boolean_once, via proofs/config.bend: the parser's
#     refusal is rewritten into the step that applies the variable.
law invalid_boolean_once:
  for +text: String
  for +reason: String
  for present: {String.is_empty(text) == False{} : Bool}
  for invalid: {Sdk.Env.read_bool(text) == Fail{reason} : Result<&2, &2, String, Bool>}
  {Sdk.Config.from_variables([Sdk.Variable{"OTEL_SDK_DISABLED", text}]) ==
    Sdk.Configured{Sdk.Config.default(), [Sdk.Diagnostic{Sdk.Warn{}, "config",
      String.concat(["OTEL_SDK_DISABLED=\"", text, "\" ", reason, "; the default is kept"])}]} : Sdk.Configured}

# LAW invalid_literal
#   Claim: an invalid integer, an unknown enumeration value and an invalid
#     Boolean each leave their default and yield one diagnostic, in the order
#     of the variables, while the valid variables beside them apply: literal
#     cases with the exact messages.
#   Requirement: as invalid_boolean_once, for the other kinds.
#   Proof: Laws.invalid_literal, by computation.
law invalid_literal:
  {Sdk.Config.from_variables([Sdk.Variable{"OTEL_BSP_MAX_QUEUE_SIZE", "12x"}, Sdk.Variable{"OTEL_LOG_LEVEL", "debug"}]) ==
    Sdk.Configured{Sdk.Config.with_level(Sdk.Config.default(), Sdk.Debug{}),
      [Sdk.Diagnostic{Sdk.Warn{}, "config", "OTEL_BSP_MAX_QUEUE_SIZE=\"12x\" is not an integer from 1 to 2147483647; the default is kept"}]} :
    Sdk.Configured} &
  {Sdk.Config.from_variables([Sdk.Variable{"OTEL_TRACES_SAMPLER", "xray"}, Sdk.Variable{"OTEL_SDK_DISABLED", "yes"}]) ==
    Sdk.Configured{Sdk.Config.default(),
      [Sdk.Diagnostic{Sdk.Warn{}, "config", "OTEL_SDK_DISABLED=\"yes\" is not a Boolean (true or false); the default is kept"},
       Sdk.Diagnostic{Sdk.Warn{}, "config", "OTEL_TRACES_SAMPLER=\"xray\" names a sampler this SDK does not provide; the default is kept"}]} :
    Sdk.Configured}

# LAW specific_limits_win
#   Claim: a span-specific limit wins over the general attribute limit it
#     overlaps, whichever is listed first; the general limit applies when the
#     specific one is unset, and the per-event and per-link counts are not
#     touched by the general count.
#   Requirement: OTel, Environment Variables, Span Limits and Attribute
#     Limits: the span-specific limits take precedence over the general
#     attribute limits; spec #11, "Span limits from the environment fill the
#     API's span limits record, with the span-specific variables winning over
#     the general attribute limits".
#   Why: an operator who bounds every attribute at 10 and spans at 20 gets
#     20 attributes on a span.
#   Proof: Laws.specific_limits_win, by computation.
law specific_limits_win:
  {Api.SpanLimits.attribute_count(Sdk.Config.span_limits(Sdk.Configured.config(Sdk.Config.from_variables(
    [Sdk.Variable{"OTEL_ATTRIBUTE_COUNT_LIMIT", "10"}, Sdk.Variable{"OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "20"}])))) ==
    Some{20n} : Maybe<&2, Nat>} &
  {Api.SpanLimits.attribute_count(Sdk.Config.span_limits(Sdk.Configured.config(Sdk.Config.from_variables(
    [Sdk.Variable{"OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "20"}, Sdk.Variable{"OTEL_ATTRIBUTE_COUNT_LIMIT", "10"}])))) ==
    Some{20n} : Maybe<&2, Nat>} &
  {Api.SpanLimits.attribute_value_length(Sdk.Config.span_limits(Sdk.Configured.config(Sdk.Config.from_variables(
    [Sdk.Variable{"OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT", "10"}, Sdk.Variable{"OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT", "20"}])))) ==
    Some{20n} : Maybe<&2, Nat>} &
  {Sdk.Config.span_limits(Sdk.Configured.config(Sdk.Config.from_variables(
    [Sdk.Variable{"OTEL_ATTRIBUTE_COUNT_LIMIT", "10"}, Sdk.Variable{"OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT", "12"}]))) ==
    Api.SpanLimits{Some{10n}, Some{12n}, Some{128n}, Some{128n}, Some{128n}, Some{128n}} : Api.SpanLimits}

# LAW otlp_kept
#   Claim: the OTLP variables are kept as text under their own names, the
#     general and the traces-specific one apart, in the order of the
#     supported list.
#   Requirement: spec #11, "Configuration": "the OTEL_EXPORTER_OTLP_* family
#     with their _TRACES_ variants (values read and kept; semantics in G7)".
#   Why: the OTLP exporter package decides the precedence and the meaning of
#     each option, and the endpoint's meaning depends on which variable set
#     it.
#   Proof: Laws.otlp_kept, by computation.
law otlp_kept:
  {Sdk.Config.otlp(Sdk.Configured.config(Sdk.Config.from_variables(
    [Sdk.Variable{"OTEL_EXPORTER_OTLP_TRACES_HEADERS", "x-token=abc"}, Sdk.Variable{"OTEL_EXPORTER_OTLP_ENDPOINT", "http://a:4318"},
     Sdk.Variable{"OTEL_EXPORTER_OTLP_TIMEOUT", "not checked here"}]))) ==
    [Sdk.Variable{"OTEL_EXPORTER_OTLP_ENDPOINT", "http://a:4318"}, Sdk.Variable{"OTEL_EXPORTER_OTLP_TRACES_HEADERS", "x-token=abc"},
     Sdk.Variable{"OTEL_EXPORTER_OTLP_TIMEOUT", "not checked here"}] : List<&2, Sdk.Variable>} &
  {Sdk.Configured.diagnostics(Sdk.Config.from_variables([Sdk.Variable{"OTEL_EXPORTER_OTLP_TIMEOUT", "not checked here"}])) ==
    Nil{} : List<&2, Sdk.Diagnostic>}

# 7. Percent decoding
# ===================
#
# OTEL_RESOURCE_ATTRIBUTES carries percent-encoded values, as W3C Baggage
# does (spec #11, "Resource": "decoded with the SDK's own percent decoder
# that reassembles UTF-8, a decoding error discarding the whole value").
# Percent.decode answers the decoded text, or none when an escape is not two
# hexadecimal digits or the bytes are not UTF-8.

# Whether a text has a percent sign: an ordinary walk over its characters.
def has_percent(text: String) -> Bool:
  match text:
    case SNil{}:
      False{}
    case SCon{char, rest}:
      Bool.or(Char.is_eq(char, '%'), has_percent(rest))

# LAW decode_plain
#   Claim: a text without a percent sign decodes to itself.
#   Requirement: RFC 3986, section 2.1: only a percent sign starts an
#     escape.
#   Why: a resource attribute written in plain text must arrive unchanged.
#   Proof: Laws.decode_plain, via proofs/percent.bend, by induction on the
#     text.
law decode_plain:
  for +text: String
  for plain: {has_percent(text) == False{} : Bool}
  {Sdk.Percent.decode(text) == Some{text} : Maybe<&2, String>}

# LAW decode_literal
#   Claim: escapes decode to their bytes, in either case of hexadecimal
#     digit, beside plain characters: a space, a slash, an encoded percent
#     sign that is not decoded again, and the digits after it kept as they
#     are.
#   Requirement: RFC 3986, section 2.1: "%" followed by two hexadecimal
#     digits, case-insensitive.
#   Proof: Laws.decode_literal, by computation.
law decode_literal:
  {Sdk.Percent.decode("a%20b") == Some{"a b"} : Maybe<&2, String>} &
  {Sdk.Percent.decode("%2F%2f") == Some{"//"} : Maybe<&2, String>} &
  {Sdk.Percent.decode("%41%42") == Some{"AB"} : Maybe<&2, String>} &
  {Sdk.Percent.decode("%25%41") == Some{"%A"} : Maybe<&2, String>} &
  {Sdk.Percent.decode("%2541") == Some{"%41"} : Maybe<&2, String>} &
  {Sdk.Percent.decode("") == Some{""} : Maybe<&2, String>}

# LAW decode_multibyte
#   Claim: the bytes of a two-, three- and four-byte UTF-8 sequence are
#     reassembled into one character, beside plain characters and escaped
#     ASCII: é, the euro sign, a check mark and an emoji.
#   Requirement: spec #11, "Resource": "reassembles UTF-8"; RFC 3629.
#   Why: `OTEL_RESOURCE_ATTRIBUTES=team=caf%C3%A9` must give the attribute
#     `café`, not two characters of garbage.
#   Reading: a character is its Unicode code point: 233 is é, 8364 is €,
#     10003 is ✓ and 128512 is the grinning face.
#   Proof: Laws.decode_multibyte, by computation.
law decode_multibyte:
  {Sdk.Percent.decode("caf%C3%A9") == Some{SCon{'c', SCon{'a', SCon{'f', SCon{Chr{233}, SNil{}}}}}} : Maybe<&2, String>} &
  {Sdk.Percent.decode("%E2%82%AC1") == Some{SCon{Chr{8364}, SCon{'1', SNil{}}}} : Maybe<&2, String>} &
  {Sdk.Percent.decode("%e2%9c%93") == Some{SCon{Chr{10003}, SNil{}}} : Maybe<&2, String>} &
  {Sdk.Percent.decode("%F0%9F%98%80%41") == Some{SCon{Chr{128512}, SCon{'A', SNil{}}}} : Maybe<&2, String>}

# LAW decode_refuses
#   Claim: a bad escape refuses the whole text: a percent sign at the end,
#     one followed by a single digit, a digit that is not hexadecimal, a
#     percent sign where a digit should be, a lead byte without its
#     continuation, a continuation that is not one, a continuation without
#     a lead byte, an overlong encoding, a surrogate and a code point above
#     U+10FFFF.
#   Requirement: spec #11, "Resource": "refusing bad escapes" and "a
#     decoding error discarding the whole value"; RFC 3629, section 3: the
#     overlong, surrogate and out-of-range sequences are ill-formed.
#   Why: a partly decoded value would silently corrupt a resource.
#   Proof: Laws.decode_refuses, by computation.
law decode_refuses:
  {Sdk.Percent.decode("%") == None{} : Maybe<&2, String>} &
  {Sdk.Percent.decode("a%") == None{} : Maybe<&2, String>} &
  {Sdk.Percent.decode("%4") == None{} : Maybe<&2, String>} &
  {Sdk.Percent.decode("%G1") == None{} : Maybe<&2, String>} &
  {Sdk.Percent.decode("%%41") == None{} : Maybe<&2, String>} &
  {Sdk.Percent.decode("%4%41") == None{} : Maybe<&2, String>} &
  {Sdk.Percent.decode("%C3") == None{} : Maybe<&2, String>} &
  {Sdk.Percent.decode("%C3%28") == None{} : Maybe<&2, String>} &
  {Sdk.Percent.decode("%80") == None{} : Maybe<&2, String>} &
  {Sdk.Percent.decode("a%A9") == None{} : Maybe<&2, String>} &
  {Sdk.Percent.decode("%C0%AF") == None{} : Maybe<&2, String>} &
  {Sdk.Percent.decode("%E0%80%80") == None{} : Maybe<&2, String>} &
  {Sdk.Percent.decode("%ED%A0%80") == None{} : Maybe<&2, String>} &
  {Sdk.Percent.decode("%F4%90%80%80") == None{} : Maybe<&2, String>} &
  {Sdk.Percent.decode("%F8%80%80%80") == None{} : Maybe<&2, String>}
