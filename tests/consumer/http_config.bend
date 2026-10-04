import Base
import bend-telemetry-instrumentation-http@0.1.0.0/core.bend as HttpCore
import bend-telemetry-instrumentation-http@0.1.0.0/host.bend as HttpHost

# The independent consumer of the HTTP instrumentation's configuration from
# the environment (#34): an application that depends on the published
# package by its BendHub name and version, reads
# OTEL_INSTRUMENTATION_HTTP_KNOWN_METHODS through HttpHost.Config.from_env and
# prints the known methods it got and a normalization under them. This file
# belongs to the application, not to the package; scripts/test-consumer.sh
# runs it against a clean clone served by the local hub, with the variable
# of http_config.env beside this file set, and compares its output with
# http_config.expected.txt. It runs natively and in-process on the
# JavaScript lane, never under node: reading a variable that may be unset
# needs the embedded Bun (tests/lanes/programs.txt).

# A normalized method: its kind and its text.
def show_method(method: HttpCore.Method) -> String:
  match method:
    case HttpCore.KnownMethod{name}:
      "known " ++ name
    case HttpCore.OtherMethod{original}:
      "_OTHER from " ++ original

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("package: " ++ HttpCore.Package.name())
    +config : HttpCore.Config <- HttpHost.Config.from_env()
    +known : List<&2, String> = HttpCore.Config.known_methods(config)
    IO.print("known methods: " ++ String.join(known, ","))
    IO.print("methods: " ++ show_method(HttpCore.Method.normalize(known, "PURGE"))
      ++ " | " ++ show_method(HttpCore.Method.normalize(known, "GET"))
      ++ " | " ++ show_method(HttpCore.Method.normalize(known, "DELETE")))
    IO.print("span name: " ++ HttpCore.Span.name(HttpCore.Method.normalize(known, "DELETE"), Some{"/items/:id"}))
    # Programmatic settings win over the environment.
    IO.print("pinned: " ++ String.join(HttpCore.Config.known_methods(
      HttpCore.Config.with_known_methods(config, HttpCore.Method.known_defaults())), ","))
