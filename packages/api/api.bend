# bend-telemetry-api: the OpenTelemetry tracing API for Bend. Source: https://github.com/LucasGois1/bend-telemetry
import Base
import bend-trace-context@0.2.0.0/trace_context.bend as TC

# The tracing API package
# =======================
#
# The OpenTelemetry tracing API for Bend: the package that instrumented code
# depends on. Its contract is the specification in
# https://github.com/LucasGois1/bend-telemetry/issues/2. This file is the
# package's entry module; today it holds the skeleton that the repository's
# toolchain builds, checks and serves (#3). It imports no foreign code, so
# that every library that depends on it stays provable.
#
# W3C Trace Context comes from bend-trace-context, imported by its BendHub
# name and version, never by a relative path (#1).

# The package's BendHub name.
def Package.name() -> String:
  "bend-telemetry-api"

# The names of the context fields that the W3C Trace Context propagator
# writes, in injection order: traceparent, then tracestate.
def TraceContext.fields() -> List<&2, String>:
  TC.Context.field_names()
