# bend-telemetry-sdk: the OpenTelemetry tracing SDK for Bend. Source: https://github.com/LucasGois1/bend-telemetry
import Base
import ./sdk.bend as Sdk

# The tracing SDK package: the host effects
# =========================================
#
# The effects of the SDK on its host, on top of the pure core of sdk.bend:
# Config.from_env reads the supported OTEL_* variables and the reporters
# write diagnostics to stderr. This file is the package's entry on the hub,
# since it imports everything the package publishes; a program imports it
# beside the core:
#
#   import bend-telemetry-sdk@0.1.0.0/sdk.bend as Sdk
#   import bend-telemetry-sdk@0.1.0.0/host.bend as Host
#
# No law imports this file: the laws state Config.from_variables, the pure
# core of Config.from_env, on literal environments.
#
# Lanes: the effects here are Base's. Reading a variable that is unset
# reaches the embedded Bun on the JavaScript lane, so a program that calls
# Config.from_env runs natively and in-process with `bend file.bend`, not as
# a `-o file.js` build under node (the lane rule of spec #11).

# A variable that is set is kept with its text; one that is unset is not.
def Config.from_env.keep(name: String, got: Result<&1, &1, U32 & String, String>, found: List<&2, Sdk.Variable>) ->
  List<&2, Sdk.Variable>:
  match got:
    case Done{value}:
      Con{Sdk.Variable{name, value}, found}
    case Fail{error}:
      found

# Read each name in turn, keeping the variables that are set, in order.
def Config.from_env.collect(names: List<&2, String>, found: List<&2, Sdk.Variable>) -> IO(List<&2, Sdk.Variable>):
  match names:
    case Nil{}:
      IO.pure(List<&2, Sdk.Variable>, List.reverse(&2, Sdk.Variable, found))
    case Con{+name, rest}:
      do IO<List<&2, Sdk.Variable>>:
        got : Result<&1, &1, U32 & String, String> <- IO.get_env(name)
        Config.from_env.collect(rest, Config.from_env.keep(name, got, found))

# The configuration of the process's environment: every supported variable
# (Sdk.Config.variable_names) read and applied to the defaults by
# Sdk.Config.from_variables, with the diagnostics of the invalid values. It
# never fails: an unset variable is skipped and an invalid one is reported.
def Config.from_env() -> IO(Sdk.Configured):
  do IO<Sdk.Configured>:
    variables : List<&2, Sdk.Variable> <- Config.from_env.collect(Sdk.Config.variable_names(), Nil{})
    return Sdk.Config.from_variables(variables)

# The fixed prefix of every line the stderr reporter writes.
def Reporter.prefix() -> String:
  "bend-telemetry-sdk "

# Write the line when the diagnostic reaches the configured level.
def Reporter.stderr.write(line: String, reaches: Bool) -> IO(Unit):
  match reaches:
    case True{}:
      IO.print_err(line)
    case False{}:
      IO.pure(Unit, Unit{})

# The default reporter: a diagnostic at or above the configured level is
# written to stderr as one line, the fixed prefix followed by
# Sdk.Diagnostic.show; a diagnostic below the level is dropped. The
# parameters are plain, so that the definition fits the reporter slot.
def Reporter.stderr(level: Sdk.Level, diagnostic: Sdk.Diagnostic) -> IO(Unit):
  match diagnostic:
    case Sdk.Diagnostic{+severity, component, message}:
      Reporter.stderr.write(Reporter.prefix() ++ Sdk.Diagnostic.show(Sdk.Diagnostic{severity, component, message}),
        Sdk.Level.is_at_least(severity, level))

# The silent reporter, for tests: every diagnostic is dropped.
def Reporter.silent(level: Sdk.Level, diagnostic: Sdk.Diagnostic) -> IO(Unit):
  IO.pure(Unit, Unit{})

# Report each diagnostic of a list in turn with a reporter, such as the
# diagnostics of Config.from_env: `Reporter.each(~Reporter.stderr, level,
# diagnostics)`.
def Reporter.each(~report: Sdk.Level -> Sdk.Diagnostic -> IO(Unit), +level: Sdk.Level,
  diagnostics: List<&2, Sdk.Diagnostic>) -> IO(Unit):
  match diagnostics:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{diagnostic, rest}:
      do IO<Unit>:
        report(level, diagnostic)
        Reporter.each(~report, level, rest)
