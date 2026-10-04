# bend-telemetry

OpenTelemetry tracing for [Bend](https://github.com/bendlang/bend): a tracing
API, an SDK, an OTLP exporter, HTTP instrumentation and semantic conventions,
written in Bend and published on BendHub.

**Status: in development.** Nothing is published yet. The repository's
toolchain is in place; the packages follow their specifications in the
[issues](https://github.com/LucasGois1/bend-telemetry/issues). This is a
community project; it is not part of, or endorsed by, the OpenTelemetry
project.

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
| `bend-telemetry-sdk` | The tracing SDK: sampling, span processing, resources, and the standard-output and in-memory exporters; in development, today its configuration from code and from the `OTEL_*` variables, and its diagnostics ([README](packages/sdk/README.md)) |
| `bend-telemetry-exporter-otlp` | Export to an OTLP endpoint |
| `bend-telemetry-instrumentation-http` | Spans and context propagation for HTTP on bend-kit |
| `bend-telemetry-semconv` | Semantic conventions v1.44.0: attribute names, enumeration values and the schema URL, generated with weaver ([README](packages/semconv/README.md)) |

The decisions behind this layout are in
[#1](https://github.com/LucasGois1/bend-telemetry/issues/1). Specifications
and decisions live in the [issues](https://github.com/LucasGois1/bend-telemetry/issues).

## Lanes

A lane is a target of the Bend compiler on which a program runs: the native C
build, or the JavaScript lane. Every package runs on both. Node, which runs
the JavaScript that `-o x.js` emits, runs only programs with no effect that
waits, and browsers only pure definitions. The effects that wait are
`IO.sleep`, `IO.within`, files, TCP and UDP sockets and `Process.run`, and an
`IO.get_env` of an unset variable fails the same way: they load `bun:ffi`,
which Node does not have, so a Node program that sleeps fails with
`Cannot find module 'bun:ffi'`.

| Where | What it is | What runs there |
| --- | --- | --- |
| Native | The C build: `bend file.bend -o file` | Every package |
| JavaScript lane | The Bun embedded in the pinned `bend`, 1.3.14 for Bend 2.0.34 (the version is named for each release). `bend file.bend` runs a program in-process, and a `-o x.js` build runs under a `bun` executable | Every package |
| Node | `-o x.js` programs with no effect that waits (printing, channels, spawn, the clock, an environment variable that is set) and the pure `-o x.mjs` module | The API and the semantic conventions, and the OTLP encoding core, the propagators and the pure HTTP core as they land; not the SDK's span pipeline, its configuration reader (an unset variable needs `bun:ffi`) or the exporter's transport |
| Browsers | Pure definitions only, with no Bend IO | Out of scope until [bendlang/bend#1148](https://github.com/bendlang/bend/issues/1148) is resolved |

The matrix is that of the specification
([#38](https://github.com/LucasGois1/bend-telemetry/issues/38)), and CI checks
each row as its package lands. No Bun version is claimed beyond the one the
pinned Bend embeds, and no JavaScript facade is planned. Each package's own
README states its lanes, as that package's documentation lands. CI runs every
program of [tests/lanes/programs.txt](tests/lanes/programs.txt) on the lanes
that the list names for it, and its lint fails when a program on the node lane
names an effect that waits ([CONTRIBUTING.md](CONTRIBUTING.md#lanes)).

## Using a package

A program imports a package by its BendHub name and version, never by a
relative path: in Bend, each version of a package is a distinct type, and a
relative import bundles a private copy whose types do not match. The API
package is in development, section by section of its specification: today
it holds its pure values (attribute values, attributes, span limits and
timestamps), its span context and its context; its reference is
[packages/api/README.md](packages/api/README.md). This example is the one
the repository tests against a clean checkout, served by the local
hub described in [CONTRIBUTING.md](CONTRIBUTING.md):

<!-- test:readme-bend:start -->
```bend
import Base
import bend-telemetry-api@0.1.0.0/api.bend as Api

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Api.Package.name())
    IO.print(String.join(Api.TraceContext.fields(), ","))
```
<!-- test:readme-bend:end -->

It prints:

<!-- test:readme-bend-output:start -->
```text
bend-telemetry-api
traceparent,tracestate
```
<!-- test:readme-bend-output:end -->

## Toolchain

The repository pins one exact Bend release, the one that its
bend-trace-context version pins (2.0.34 for bend-trace-context 0.2.0).
`./scripts/setup-bend.sh` installs it under `.tools/`, verified by version,
release commit and archive SHA-256, and `./bend` runs it. The gates are:

```sh
./scripts/validate.sh                 # the proof check of every package and the manifests
./scripts/test-consumer.sh native     # the independent consumer and the README example, in-process and natively
./scripts/test-consumer.sh node       # the same, in-process and compiled to JavaScript and run with node
./scripts/lint-lanes.sh               # the programs that run under node name no effect that waits
```

`./scripts/local-hub.sh COMMAND` serves the working tree's packages from a
local BendHub and runs a command against it, for example
`./scripts/local-hub.sh ./bend tests/consumer/main.bend`. CONTRIBUTING.md has
the details, the conventions and the weekly check on the newest Bend release.

The qualification harness sends the reference trace through an
OpenTelemetry Collector into Grafana Tempo and checks what arrives;
[qualification/README.md](qualification/README.md) describes it.

## License

[Apache-2.0](LICENSE).

OpenTelemetry is a registered trademark of The Linux Foundation. This project
uses the name only to say which specification it implements.
