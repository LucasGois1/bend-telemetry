import Base
import bend-telemetry-api@0.1.0.0/api.bend as Api
import bend-telemetry-sdk@0.1.0.0/sdk.bend as Sdk
import bend-telemetry-sdk@0.1.0.0/host.bend as Host

# The independent consumer of the SDK's configuration (#12): an application
# that depends on the published packages by their BendHub names and versions,
# reads the OTEL_* variables of its environment through Host.Config.from_env
# and prints the configuration and the diagnostics. This file belongs to the
# application, not to the packages; scripts/test-consumer.sh runs it against a
# clean clone served by the local hub, with the variables of sdk_config.env
# beside this file set, and compares its output with sdk_config.expected.txt.
#
# The environment has a sampler and its argument, a level, limits (a general
# attribute count, which fills the count per link, with the span and the
# event counts winning over it, and the largest accepted integer), an
# invalid Boolean and an invalid integer, a timeout of zero, an empty
# variable, the console exporter, a service name, raw resource attributes
# and two OTLP values. Then the program shows the reporter's
# decision, that a setter wins over the environment, the defaults, the pure
# core on literal variables and the percent decoder. It runs natively and
# in-process on the JavaScript lane, never under node: reading a variable
# that is unset needs the embedded Bun (tests/lanes/programs.txt).

# An optional text, as Maybe.show prints it.
def show_text(value: Maybe<&2, String>) -> String:
  Maybe.show(~&2, ~String, ~(text => text), value)

# An optional count.
def show_count(value: Maybe<&2, Nat>) -> String:
  Maybe.show(~&2, ~Nat, ~Nat.show, value)

# Each variable as NAME=value.
def show_variables(variables: List<&2, Sdk.Variable>) -> List<&2, String>:
  match variables:
    case Nil{}:
      Nil{}
    case Con{Sdk.Variable{name, value}, rest}:
      Con{name ++ "=" ++ value, show_variables(rest)}

# Each diagnostic as the reporter would write it, without the prefix.
def show_diagnostics(diagnostics: List<&2, Sdk.Diagnostic>) -> List<&2, String>:
  match diagnostics:
    case Nil{}:
      Nil{}
    case Con{diagnostic, rest}:
      Con{Sdk.Diagnostic.show(diagnostic), show_diagnostics(rest)}

# The six span limits.
def show_limits(+limits: Api.SpanLimits) -> String:
  "attributes " ++ show_count(Api.SpanLimits.attribute_count(limits))
    ++ ", length " ++ show_count(Api.SpanLimits.attribute_value_length(limits))
    ++ ", events " ++ show_count(Api.SpanLimits.event_count(limits))
    ++ ", links " ++ show_count(Api.SpanLimits.link_count(limits))
    ++ ", per event " ++ show_count(Api.SpanLimits.attribute_per_event_count(limits))
    ++ ", per link " ++ show_count(Api.SpanLimits.attribute_per_link_count(limits))

# The four batch options.
def show_batch(+options: Sdk.BatchOptions) -> String:
  "queue " ++ Nat.show(Sdk.BatchOptions.queue_size(options))
    ++ ", delay " ++ Nat.show(Sdk.BatchOptions.schedule_delay(options))
    ++ "ms, export timeout " ++ show_count(Sdk.BatchOptions.export_timeout(options))
    ++ ", batch " ++ Nat.show(Sdk.BatchOptions.batch_size(options))

# Every field of a configuration, one per line.
def show_config(+config: Sdk.Config) -> List<&2, String>:
  ["disabled: " ++ Bool.show(Sdk.Config.disabled(config)),
   "level: " ++ Sdk.Level.show(Sdk.Config.level(config)),
   "service name: " ++ show_text(Sdk.Config.service_name(config)),
   "resource attributes: " ++ show_text(Sdk.Config.resource_attributes(config)),
   "sampler: " ++ Sdk.SamplerSelection.show(Sdk.Config.sampler(config)),
   "sampler arg: " ++ show_text(Sdk.Config.sampler_arg(config)),
   "exporter: " ++ Sdk.ExporterSelection.show(Sdk.Config.exporter(config)),
   "processors: " ++ Nat.show(List.length(&2, Sdk.ProcessorConfig, Sdk.Config.processors(config))),
   "batch: " ++ show_batch(Sdk.Config.batch(config)),
   "span limits: " ++ show_limits(Sdk.Config.span_limits(config)),
   "otlp: " ++ String.join(show_variables(Sdk.Config.otlp(config)), ", "),
   "shutdown timeout: " ++ show_count(Sdk.Config.shutdown_timeout(config)),
   "threshold precision: " ++ Nat.show(Sdk.Config.threshold_precision(config))]

# The fields that the defaults are usually checked by.
def show_defaults(+config: Sdk.Config) -> String:
  "disabled " ++ Bool.show(Sdk.Config.disabled(config))
    ++ ", level " ++ Sdk.Level.show(Sdk.Config.level(config))
    ++ ", sampler " ++ Sdk.SamplerSelection.show(Sdk.Config.sampler(config))
    ++ ", exporter " ++ Sdk.ExporterSelection.show(Sdk.Config.exporter(config))
    ++ ", batch " ++ show_batch(Sdk.Config.batch(config))
    ++ ", shutdown timeout " ++ show_count(Sdk.Config.shutdown_timeout(config))

# The decimal code of each character, in order: the same text on every lane,
# whatever the console's encoding.
def codes(text: String) -> List<&2, String>:
  match text:
    case SNil{}:
      Nil{}
    case SCon{Chr{code}, rest}:
      Con{U32.show(code), codes(rest)}

# A decoded text as its codes, or the refusal.
def show_decoded(decoded: Maybe<&2, String>) -> String:
  match decoded:
    case None{}:
      "refused"
    case Some{text}:
      String.join(codes(text), " ")

# The level and the number of diagnostics of a pure reading.
def show_literal(+configured: Sdk.Configured) -> String:
  "level " ++ Sdk.Level.show(Sdk.Config.level(Sdk.Configured.config(configured)))
    ++ ", diagnostics " ++ Nat.show(List.length(&2, Sdk.Diagnostic, Sdk.Configured.diagnostics(configured)))

def print_each(lines: List<&2, String>) -> IO(Unit):
  match lines:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{line, rest}:
      do IO<Unit>:
        IO.print(line)
        print_each(rest)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("package: " ++ Sdk.Package.name())
    +configured : Sdk.Configured <- Host.Config.from_env()
    +config : Sdk.Config = Sdk.Configured.config(configured)
    +level : Sdk.Level = Sdk.Config.level(config)
    +diagnostics : List<&2, Sdk.Diagnostic> = Sdk.Configured.diagnostics(configured)
    print_each(show_config(config))
    IO.print("diagnostics: " ++ Nat.show(List.length(&2, Sdk.Diagnostic, diagnostics)))
    print_each(show_diagnostics(diagnostics))
    # The stderr reporter writes the diagnostics at the configured level, on
    # stderr, which the runner keeps as evidence; the silent one writes nothing.
    Host.Reporter.each(~Host.Reporter.stderr, level, diagnostics)
    Host.Reporter.each(~Host.Reporter.silent, level, diagnostics)
    IO.print("reports: warn at " ++ Sdk.Level.show(level) ++ " " ++ Bool.show(Sdk.Level.is_at_least(Sdk.Warn{}, level))
      ++ ", debug at warn " ++ Bool.show(Sdk.Level.is_at_least(Sdk.Debug{}, Sdk.Warn{}))
      ++ ", error at error " ++ Bool.show(Sdk.Level.is_at_least(Sdk.Error{}, Sdk.Error{})))
    # Programmatic settings win over the environment.
    +pinned : Sdk.Config = Sdk.Config.with_sampler(Sdk.Config.with_level(config, Sdk.Error{}), Sdk.AlwaysOff{})
    IO.print("pinned: level " ++ Sdk.Level.show(Sdk.Config.level(pinned))
      ++ ", sampler " ++ Sdk.SamplerSelection.show(Sdk.Config.sampler(pinned)))
    IO.print("defaults: " ++ show_defaults(Sdk.Config.default()))
    IO.print("literal: " ++ show_literal(Sdk.Config.from_variables(
      [Sdk.Variable{"OTEL_LOG_LEVEL", "ERROR"}, Sdk.Variable{"OTEL_SDK_DISABLED", ""}])))
    IO.print("decoded: " ++ show_decoded(Sdk.Percent.decode("caf%C3%A9"))
      ++ " | " ++ show_decoded(Sdk.Percent.decode("%F0%9F%98%80"))
      ++ " | " ++ show_decoded(Sdk.Percent.decode("%C3%28")))
