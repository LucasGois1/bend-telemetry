# Proofs: the configuration
# =========================
#
# The setters' laws hold for every configuration, so they hold for the one
# an environment produced, whatever it is: disabled_reads, sampler_reads and
# span_limits_reads open the record, and PROOF.bend applies them to
# Configured.config(Config.from_variables(variables)) for the law
# programmatic_wins. invalid_boolean_once proves the law of the same name:
# Config.from_variables passes the parser's result to Env.step, and `match`
# cannot inspect a computed value, so the proof rewrites that result with
# the law's hypothesis and lets the checker compute the rest, every other
# variable being absent from the one-variable environment.

import Base
import ../sdk.bend as Sdk
import bend-telemetry-api@0.1.0.0/api.bend as Api
import ./bools.bend as BoolsProof

# The disabled flag set on any configuration is read back.
law disabled_reads:
  for config: Sdk.Config
  for +disabled: Bool
  {Sdk.Config.disabled(Sdk.Config.with_disabled(config, disabled)) == disabled : Bool}

def disabled_reads(config, disabled):
  match config:
    case Sdk.Config{previous, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      {==}

# The sampler set on any configuration is read back.
law sampler_reads:
  for config: Sdk.Config
  for +sampler: Sdk.SamplerSelection
  {Sdk.Config.sampler(Sdk.Config.with_sampler(config, sampler)) == sampler : Sdk.SamplerSelection}

def sampler_reads(config, sampler):
  match config:
    case Sdk.Config{disabled, level, resource, service_name, resource_attributes, previous, sampler_arg, processors, batch, span_limits, exporter, otlp, shutdown_timeout, threshold_precision}:
      {==}

# The span limits set on any configuration are read back.
law span_limits_reads:
  for config: Sdk.Config
  for +span_limits: Api.SpanLimits
  {Sdk.Config.span_limits(Sdk.Config.with_span_limits(config, span_limits)) == span_limits : Api.SpanLimits}

def span_limits_reads(config, span_limits):
  match config:
    case Sdk.Config{disabled, level, resource, service_name, resource_attributes, sampler, sampler_arg, processors, batch, previous, exporter, otlp, shutdown_timeout, threshold_precision}:
      {==}

# A non-empty text that the Boolean parser refuses leaves the default
# configuration with exactly one diagnostic. An empty text contradicts
# `present`; for any other, the lookup of OTEL_SDK_DISABLED finds it, the
# other variables find nothing, and the parser's refusal is rewritten into
# the step.
law invalid_boolean_once:
  for +text: String
  for +reason: String
  for present: {String.is_empty(text) == False{} : Bool}
  for invalid: {Sdk.Env.read_bool(text) == Fail{reason} : Result<&2, &2, String, Bool>}
  {Sdk.Config.from_variables([Sdk.Variable{"OTEL_SDK_DISABLED", text}]) ==
    Sdk.Configured{Sdk.Config.default(), [Sdk.Diagnostic{Sdk.Warn{}, "config",
      String.concat(["OTEL_SDK_DISABLED=\"", text, "\" ", reason, "; the default is kept"])}]} : Sdk.Configured}

def invalid_boolean_once(text, reason, present, invalid):
  match text:
    case SNil{}:
      BoolsProof.absurd({Sdk.Config.from_variables([Sdk.Variable{"OTEL_SDK_DISABLED", SNil{}}]) ==
        Sdk.Configured{Sdk.Config.default(), [Sdk.Diagnostic{Sdk.Warn{}, "config",
          String.concat(["OTEL_SDK_DISABLED=\"", SNil{}, "\" ", reason, "; the default is kept"])}]} : Sdk.Configured},
        Equal.sym(Bool, True{}, False{}, present))
    case SCon{+head, +tail}:
      %Equal.sym(Result<&2, &2, String, Bool>, Sdk.Env.read_bool(SCon{head, tail}), Fail{reason}, invalid) :
        {Sdk.Env.step(Bool, "OTEL_SDK_DISABLED", Sdk.Configured{Sdk.Config.default(), Nil{}}, SCon{head, tail}, _,
          Sdk.Config.with_disabled) ==
          Sdk.Configured{Sdk.Config.default(), [Sdk.Diagnostic{Sdk.Warn{}, "config",
            String.concat(["OTEL_SDK_DISABLED=\"", SCon{head, tail}, "\" ", reason, "; the default is kept"])}]} : Sdk.Configured}
      {==}
