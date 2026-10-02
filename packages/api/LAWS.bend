import Base
import ./api.bend as Api

# The laws of bend-telemetry-api
# ==============================
#
# Each `law` below is an open claim about the package's public operations.
# PROOF.bend proves each one with a `def Laws.<name>`; the proof gate is
#
#   ./bend packages/api/PROOF.bend --check-only
#
# which prints "ALL PROOFS CHECK" only when every law holds and nothing the
# proofs import relies on `@unsafe` or foreign code.

# The package answers its own BendHub name.
law name:
  {Api.Package.name() == "bend-telemetry-api" : String}

# The context fields are those of W3C Trace Context, in injection order.
law context_fields:
  {Api.TraceContext.fields() == ["traceparent", "tracestate"] : List<&2, String>}
