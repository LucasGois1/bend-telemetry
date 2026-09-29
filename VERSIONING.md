# Versioning

bend-telemetry follows [Semantic Versioning 2.0.0](https://semver.org/) and
OpenTelemetry's
[versioning and stability](https://opentelemetry.io/docs/specs/otel/versioning-and-stability/)
rules as they apply to a language implementation.

## One version for every package

All packages in this repository share one version and are released together.
In Bend, each version of a package is a distinct type: an application must
use exactly the API version that its SDK, exporter and instrumentation were
built against. One shared version makes that set obvious.

Release X.Y.Z is published on BendHub as `bend-telemetry-<role>@X.Y.Z.0` for
each package, because BendHub versions have four numbers, and it is tagged
`vX.Y.Z`.

## Before 1.0

A 0.Y.Z version may break any API: a breaking change raises Y, and any other
change raises Z. The changelog gives a migration note for every breaking
change.

## What each release states

Each release names:

- the OpenTelemetry specification version that it implements;
- the bend-trace-context version that it depends on;
- the Bend release that it is qualified on, which is the one that the
  bend-trace-context version pins.

## At 1.0

OpenTelemetry expects the API to become stable before the SDK. When the API
approaches 1.0, this policy is reviewed, and the API may then take a version
of its own.

## Signals

Only traces are supported. When metrics and logs arrive, all signals share
the API version and the SDK version, as OpenTelemetry requires.
