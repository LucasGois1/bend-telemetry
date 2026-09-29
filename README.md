# bend-telemetry

OpenTelemetry tracing for [Bend](https://github.com/bendlang/bend): a tracing
API, an SDK, an OTLP exporter, HTTP instrumentation and semantic conventions,
written in Bend and published on BendHub.

**Status: planning.** Nothing is published yet. This is a community project;
it is not part of, or endorsed by, the OpenTelemetry project.

## Scope

- Traces, following the OpenTelemetry specification. Metrics and logs are
  planned for later.
- W3C Trace Context propagation and identifier generation come from
  [bend-trace-context](https://github.com/LucasGois1/bend-trace-context).

## Packages

All packages share one version and are released together; see
[VERSIONING.md](VERSIONING.md).

| BendHub name | Role |
| --- | --- |
| `bend-telemetry-api` | The tracing API that instrumented code depends on; it works alone through its no-op implementation |
| `bend-telemetry-sdk` | The tracing SDK: sampling, span processing, resources, and the standard-output and in-memory exporters |
| `bend-telemetry-exporter-otlp` | Export to an OTLP endpoint |
| `bend-telemetry-instrumentation-http` | Spans and context propagation for HTTP on bend-kit |
| `bend-telemetry-semconv` | Semantic convention attribute names |

The decisions behind this layout are in
[#1](https://github.com/LucasGois1/bend-telemetry/issues/1). Specifications
and decisions live in the [issues](https://github.com/LucasGois1/bend-telemetry/issues).

## License

[Apache-2.0](LICENSE).

OpenTelemetry is a registered trademark of The Linux Foundation. This project
uses the name only to say which specification it implements.
