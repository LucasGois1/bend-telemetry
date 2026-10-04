# bend-telemetry-instrumentation-http: OpenTelemetry HTTP instrumentation for Bend on bend-kit. Source: https://github.com/LucasGois1/bend-telemetry
import Base
import ./core.bend as HttpCore

# The HTTP instrumentation package: the host effects
# ==================================================
#
# The effects of the instrumentation on its host, on top of the pure core of
# core.bend: today Config.from_env, which reads
# OTEL_INSTRUMENTATION_HTTP_KNOWN_METHODS. This file is the package's entry on
# the hub, since it imports everything the package publishes; a program
# imports it beside the core:
#
#   import bend-telemetry-instrumentation-http@0.1.0.0/core.bend as HttpCore
#   import bend-telemetry-instrumentation-http@0.1.0.0/host.bend as HttpHost
#
# No law imports this file: the laws state Config.from_variables, the pure
# core of Config.from_env, on literal environments. The server and client
# wrappers over bend-kit-http, which have effects of their own, follow in
# later tickets (#35, #36).
#
# Lanes: reading a variable that is unset reaches the embedded Bun on the
# JavaScript lane, so a program that calls Config.from_env runs natively and
# in-process with `bend file.bend`, not as a `-o file.js` build under node
# (the lane rule of spec #27). The core runs under node too.

# A variable that is set is the one-variable environment; one that is unset
# is the empty environment.
def Config.from_env.variables(got: Result<&1, &1, U32 & String, String>) -> List<&2, HttpCore.Variable>:
  match got:
    case Done{value}:
      [HttpCore.Variable{HttpCore.Config.variable_name(), value}]
    case Fail{error}:
      Nil{}

# The configuration of the process's environment: the defaults, with the
# known methods of OTEL_INSTRUMENTATION_HTTP_KNOWN_METHODS when it is set, by
# HttpCore.Config.from_variables. It never fails: an unset variable leaves
# the defaults.
def Config.from_env() -> IO(HttpCore.Config):
  do IO<HttpCore.Config>:
    got : Result<&1, &1, U32 & String, String> <- IO.get_env(HttpCore.Config.variable_name())
    return HttpCore.Config.from_variables(Config.from_env.variables(got))
