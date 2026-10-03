# bend-telemetry-semconv

The OpenTelemetry semantic conventions for Bend: constants for attribute
names, enumeration values and deprecation notes, and the schema URL, generated
by [weaver](https://github.com/open-telemetry/weaver) 0.26.1 from the
[semantic conventions registry](https://github.com/open-telemetry/semantic-conventions)
at v1.44.0. Nothing in the generated module is typed by hand: the HTTP
instrumentation, the SDK's resource detectors and every library author take
their attribute names from here (#27, #33).

The package covers the namespaces of HTTP spans and of the resource: `http`,
`url`, `server`, `client`, `network`, `user_agent`, `error` and `exception`,
and `service`, `telemetry`, `process`, `host`, `os` and `container`. Other
namespaces (databases, messaging, RPC, GenAI, ...) are out of scope until a
specification asks for them.

## Using the package

A program imports the package by its BendHub name and version. Every
constant is a def with no parameters that answers a `String`:

```bend
import Base
import bend-telemetry-semconv@0.1.0.0/semconv.bend as Semconv

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Semconv.Http.Request.method() ++ " = " ++ Semconv.Http.Request.Method.get())
    IO.print(Semconv.Schema.url())
```

prints `http.request.method = GET` and
`https://opentelemetry.io/schemas/1.44.0`. `tests/consumer/main.bend` at the
repository root is the version of this example that the gates run.

The module is `packages/semconv/semconv.bend`. Besides the constants of the
registry it defines `Package.name()`, the package's BendHub name, and
`Schema.url()`, the schema URL of the conventions version the constants come
from, for resources and instrumentation scopes.

## The name mapping

The Bend name of a constant follows from the registry's key, deterministically:

- An attribute key splits on `.`. Every segment but the last is capitalized,
  and `_` inside such a segment joins its words; the last segment keeps the
  registry's snake_case spelling. The constant answers the key.

  | Attribute | Constant |
  | --- | --- |
  | `http.request.method` | `Semconv.Http.Request.method()` |
  | `http.response.status_code` | `Semconv.Http.Response.status_code()` |
  | `user_agent.original` | `Semconv.UserAgent.original()` |
  | `process.executable.build_id.gnu` | `Semconv.Process.Executable.BuildId.gnu()` |

- An enumeration member is a def under the attribute's key with every
  segment capitalized, named after the member's id as the registry writes
  it. The constant answers the member's value.

  | Attribute and member | Constant | Value |
  | --- | --- | --- |
  | `http.request.method`, `get` | `Semconv.Http.Request.Method.get()` | `GET` |
  | `error.type`, `other` | `Semconv.Error.Type.other()` | `_OTHER` |
  | `http.flavor`, `http_1_0` | `Semconv.Http.Flavor.http_1_0()` | `1.0` |
  | `os.type`, `z_os` | `Semconv.Os.Type.z_os()` | `z_os` |

- Every constant answers a `String`, whatever the attribute's value type: the
  constant is the name, and the comment above it states the type
  (`Type: int. Stability: stable.`) with the registry's examples. A template
  attribute such as `http.request.header` answers its prefix; the
  instrumentation appends `.<key>`.
- Bend reads a dotted name as one token, so segments that are keywords
  elsewhere need no escape: `Semconv.Os.type()`, `Semconv.Url.template()`.
  The mapping makes no exceptions and keeps no reserved-word table; instead
  the generator rejects a module in which two keys map to one name (a
  collision), a name has a segment outside `[A-Za-z][A-Za-z0-9_]*`, or an
  enumeration value is not a plain string. None of these occurs at v1.44.0.
- Deprecated attributes and members are generated like the others, with the
  registry's note in their comment, for example
  ``Deprecated (renamed): Replaced by `http.request.method`.``

## Values the registry does not list

`telemetry.sdk.language` has no member for Bend at v1.44.0. The package
defines `Semconv.Telemetry.Sdk.Language.bend()`, which answers `bend`, and
the SDK's resource carries that value until the conventions list the
language. The definition lives in `templates/registry/bend/project.bend.j2`,
written by hand and rendered at the end of the module under its own heading,
not in the registry. When a registry version lists the member, the generator
fails with a collision on `Telemetry.Sdk.Language.bend`, and the hand-written
definition is removed: the generated member takes its place with the same
name.

## Generation

```sh
./scripts/semconv-generate.sh          # regenerate packages/semconv/semconv.bend
./scripts/semconv-generate.sh --check  # fail when the committed module differs
```

The script installs the pinned weaver under `.tools/weaver-0.26.1/` (the
release asset of its platform, verified by SHA-256, on macOS ARM64 and Linux
x86_64), fetches the release archive of the semantic conventions at the
pinned tag and verifies the content digest of its `model` folder (the SHA-256
of the sorted `SHA-256 path` lines of its files, so that the check does not
depend on how GitHub compressed the archive), runs
`weaver registry generate bend` with the Bend target in
`templates/registry/bend`, and accepts the module only when it carries no
error line, every definition is a constant with a valid name, and no two
definitions share a name. `--check` regenerates into a temporary directory
and fails with the diff when the committed module differs; CI runs it on
every pull request. Evidence goes to `build/semconv/`.

The target directory holds `weaver.yaml` (the namespaces, the comment format
and the filter: every registry attribute of those namespaces, deprecated ones
included, grouped by root namespace and sorted by name), `semconv.bend.j2`
(the module, with the name mapping) and `project.bend.j2` (the values above).

### Moving to a newer conventions version

1. Change `semconv_version` in `scripts/semconv-generate.sh` and run the
   script once: it fails and prints the content digest of the new `model`
   folder. Check the release on GitHub, pin that digest as `model_digest`,
   and record the tag's commit in the comment beside it.
2. Run the script again and review the diff of `semconv.bend`: new, renamed
   and deprecated attributes, new members, and any collision with
   `project.bend.j2` (a value the registry now lists leaves that file).
3. Update what names the version: `Schema.url()` changes, so the `schema_url`
   law in `LAWS.bend` does too, with any other law or consumer line a change
   in the registry affects; then this README and the changelog.

Moving weaver is the same with `weaver_version` and the two asset digests,
taken from the release's `sha256.sum`; the script reinstalls the new version
on its next run.

## Laws

`LAWS.bend` pins a handful of constants against literal text taken from the
registry itself: attribute names across the namespaces, enumeration values,
deprecated ones, the project's `bend` value and the schema URL. `PROOF.bend`
proves them; `./scripts/validate.sh` runs the proof gate.
