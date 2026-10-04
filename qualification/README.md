# Qualification harness

The qualification harness is part of this project's qualification: it sends
real OTLP to an OpenTelemetry Collector, which exports it to Grafana Tempo,
and checks what arrives against the **reference trace**. One command starts
the stack, a second sends a producer's trace and runs the verifier, and
Grafana shows the trace at <http://localhost:3000>. CI runs the same on
Ubuntu. The decisions behind it are in
[#48](https://github.com/LucasGois1/bend-telemetry/issues/48).

## The stack

[`compose.yaml`](compose.yaml) runs three services, each with its
configuration in this directory. Ports are published on the loopback
interface only.

| Service | Image | Host ports | Configuration |
| --- | --- | --- | --- |
| `collector` | OpenTelemetry Collector contrib | 4317 (OTLP/gRPC), 4318 (OTLP/HTTP), 13133 (health check) | [`collector.yaml`](collector.yaml) |
| `tempo` | Grafana Tempo | 3200 (HTTP API) | [`tempo.yaml`](tempo.yaml) |
| `grafana` | Grafana | 3000 | [`grafana-datasources.yaml`](grafana-datasources.yaml) and the environment in `compose.yaml` |

- The Collector receives OTLP on every interface of its container (the
  receivers' default, localhost, cannot be reached from the host) and has one
  traces pipeline with three exporters: `file`, which writes each export
  request it receives as a line of OTLP/JSON to
  `build/qualification/collector/traces.jsonl` and flushes every second;
  `otlp_http` to Tempo; and `debug` at basic verbosity, in its log. The
  `health_check` extension answers on port 13133.
- Tempo runs as one binary (`-target=all`) with an OTLP/HTTP receiver for
  the Collector, local storage on the `tempo-data` volume and usage reporting
  off; its compose health check is the image's own `/tempo --health`.
- Grafana admits anonymous users as Admin, with the login form disabled and
  usage reporting and update checks off, for local use only; it is
  provisioned with Tempo as its default datasource.

## The pins

Each image is pinned by tag and by the digest of its multi-architecture
index, read from the registry when it was pinned:

| Image | Tag | Digest |
| --- | --- | --- |
| `ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib` | `0.161.0` | `sha256:fd328de2552466ad78385e1b1289c3f2402b1c45f265b252aab1955b42845ac1` |
| `grafana/tempo` | `3.1.0` | `sha256:3076b8dcdfb32fd6bc5ccef85e7b7313e6199b9cb84366257fc17ecb696db5fd` |
| `grafana/grafana` | `13.2.3` | `sha256:b28bae15e219c998fb0e0424ed724930cc61b1f61fb404d47c862f9a23f9e572` |

The Collector comes from the GitHub registry, which has no Docker Hub pull
limits; `0.161.0` is its newest tag with a multi-architecture index
(`0.162.0` was published without one).

Dependabot watches `compose.yaml` with the `docker-compose` ecosystem: every
week, after the same seven-day cooldown as the GitHub Actions, it proposes
one pull request that moves the tags and digests together. The `qualification`
job runs on that pull request; a new version that changes what the Collector
writes or what Tempo answers fails there. To move a pin by hand, read the
digest of the new tag's index from the registry:

```sh
docker buildx imagetools inspect grafana/tempo:3.1.0
```

and write the `Digest` it prints after the tag, as
`image: grafana/tempo:3.1.0@sha256:<digest>`; check that the index lists
both `linux/amd64` and `linux/arm64`; update the table above; then run the
harness. When a new version changes the recorded answers, record the
[fixtures](#the-verifier) again.

## The commands

Docker, or Podman with a compose plugin, is required, with curl and Node 22
or newer:

```sh
./scripts/qualify.sh up      # start a fresh stack and wait until it is healthy
./scripts/qualify.sh run     # send the reference trace with curl and run the verifier
./scripts/qualify.sh down    # keep the logs and stop the stack
```

- `up` removes any previous stack, with its Tempo volume, and the evidence
  of the previous session; runs `compose up --wait`, which waits for Tempo's
  and Grafana's health checks; and then waits for the Collector's health
  endpoint from the host, since the Collector's image has no shell for a
  health check of its own.
- `run [--producer curl]` sends the producer's trace and runs the verifier.
  The one producer today, `curl`, posts `reference-trace.json` to the
  Collector's `/v1/traces` with `Content-Type: application/json`, as one
  export, and expects HTTP 200.
- `down` writes each service's log and stops the stack, removing the Tempo
  volume.

The evidence stays under `build/qualification/`: the Collector's output
(`collector/traces.jsonl`), the Collector's answer to curl
(`curl-response.json`), the verifier's evidence (`verifier/`) and, after
`down`, the services' logs and states (`logs/`).

`run` can be repeated on one stack: the verifier reads only what the
Collector wrote during that run. Tempo, though, keeps the trace for the life
of the stack, so after the first run its check also sees what earlier runs
sent; `up` starts from an empty Tempo. On macOS, Docker Desktop asks once
for access to the folder that holds the checkout, such as Documents; `up`
waits until that access is granted.

## The reference trace

[`reference-trace.json`](reference-trace.json) is one export request in
OTLP/JSON, with the encoding that the exporter's JSON mapping writes
([#19](https://github.com/LucasGois1/bend-telemetry/issues/19)): keys in
lowerCamelCase; trace and span identifiers in lowercase hex; enumerations and
flags as numbers; 64-bit integers and timestamps as decimal strings; bytes in
base64; default values left out, except the one field of an attribute value;
the empty value as `{}`. The encoders and the example application take it as
their expectation: the OTLP/JSON encoder
([#22](https://github.com/LucasGois1/bend-telemetry/issues/22)) as literal
text, the protobuf encoder
([#20](https://github.com/LucasGois1/bend-telemetry/issues/20)) through
`protoc`, and the example application
([#52](https://github.com/LucasGois1/bend-telemetry/issues/52)) by replaying
its identifiers and timestamps. Changing it is a deliberate, reviewed change,
and the fixtures are recorded again with it.

It holds the resource `service.name` = `bend-qualification`,
`telemetry.sdk.name` = `bend-telemetry-sdk`, `telemetry.sdk.language` =
`bend` and `telemetry.sdk.version` = `0.1.0`; the instrumentation scope
`bend-telemetry-qualification` `0.1.0`; both with the schema URL
`https://opentelemetry.io/schemas/1.44.0`; and three spans of the trace
`2904730afd20f69baabe13593b08a9a0`, from 2026-10-01T12:00:00.123456789Z on:

| Span | Kind | Parent | What it carries |
| --- | --- | --- | --- |
| `GET /users/:id` (`90fc8028d84b8528`) | server | none | one attribute of each kind of attribute value; status ok |
| `GET` (`a4e46f4e67ea0510`) | client | `GET /users/:id` | HTTP client attributes; status error with its message; an `exception` event with attributes; a link with attributes to a span of another trace, a remote span context with a tracestate |
| `render` (`8bbf835aef3ff453`) | internal | `GET /users/:id` | non-zero dropped counts: the server span's attributes, with three more dropped; one `cache.miss` event of three, with one of its attributes dropped; one link to the `GET` span of two, with two of its attributes dropped; status unset |

The server span's attribute values are a string with characters that JSON
escapes and characters of two, three and four bytes in UTF-8; `true`;
-9007199254740993, a negative 64-bit integer that a double cannot hold;
2.5; arrays of strings, of Booleans, of integers (-1, 0 and 2^63 - 1) and of
doubles; seven bytes whose base64 holds `+`, `/` and padding; a key-value
list holding an empty string, `false` and 0, which OTLP/JSON still writes in
an attribute value, and a nested list with an array of mixed values; and the
empty value. Every double is exact in a 32-bit float, so that the Bend SDK,
which holds doubles in an `F32` until Base has an `F64`, writes them as they
are.

Every span's flags are 259: the W3C sampled and random bits, and bit 8, set
because the parent's remoteness is known (local, or no parent). The link to
the `GET` span, a local span context, has flags 259; the link to the remote
span context has 769: the sampled bit, bit 8 and bit 9, remote.

The dropped counts are what an SDK records under these span limits:
attributes 11, events 1, links 1, attributes per event 2 and attributes per
link 2. The `render` span sets the server span's eleven attributes and three
more; adds the same event three times, each with three attributes; and adds
the same link twice, each with four attributes. Repeating the event and the
link keeps the result the same whether an SDK keeps the first or the last.

## The verifier

[`verify.mjs`](verify.mjs) checks two layers after a producer's run, and
exits with 1 and a diff of the canonical forms, whose hunks name the path of
the change (such as
`spans["render"].attributes["qualification.int"].value.intValue`), on any
mismatch:

1. **The Collector.** The OTLP/JSON lines that the Collector wrote during
   the run must hold the reference trace exactly. Both are compared in
   canonical form: keys sorted; 64-bit integers read exactly, whether written
   as strings or as numbers; enumerations as numbers; default values left
   out, so that the Collector's `"status": {}` for an unset status equals no
   status, except the one field of an attribute value, kept even when it is
   `false`, 0 or empty; identifiers in lowercase hex; bytes in padded
   standard base64; attributes ordered by key and spans by identifier; and
   the spans of the reference trace gathered by resource and scope across
   export requests, so that the way a producer batches its spans does not
   matter. Spans of other traces are left out; a missing, an extra or a
   repeated span fails.
2. **Tempo.** `GET /api/v2/traces/<trace id>`, polled for up to 30 seconds,
   must show the reference trace's spans: the same count, names and parent
   links. Tempo's JSON writes identifiers in base64; the verifier decodes
   them to hex.

Its evidence goes to `build/qualification/verifier/`: each layer's expected
and actual canonical forms, the diff of a mismatch, Tempo's last answer and a
summary. `node qualification/verify.mjs --help` lists its options; the
defaults are those of `qualify.sh`.

Its unit tests run with `node --test qualification/*.test.mjs` on recorded
fixtures: [`fixtures/collector-output.jsonl`](fixtures/collector-output.jsonl),
the line that the pinned Collector wrote for the reference trace, and
[`fixtures/tempo-response.json`](fixtures/tempo-response.json), the answer of
the pinned Tempo. Both must pass; a changed attribute, a missing span, a span
exported twice and a wrong parent must each fail; and canonicalization is
tested on reordered keys, on 64-bit integers as strings and as numbers, and
on the other rules above. To record the fixtures again, run the harness and
copy `build/qualification/collector/traces.jsonl` and
`build/qualification/verifier/tempo-response.json` over them.

## Seeing the trace in Grafana

While the stack runs, after `run`:

1. Open <http://localhost:3000>; no login is asked.
2. Open **Explore** from the menu; the **Tempo** datasource is selected.
3. In the **TraceQL** query type, enter the trace identifier
   `2904730afd20f69baabe13593b08a9a0` and run the query.

Grafana shows the trace of `bend-qualification`: `GET /users/:id` with its
two children, their attributes, the event, the links and the error. A
lookup by identifier needs no time range. Searching may not find the trace:
Tempo indexes traces for search only after it flushes them, and only within
the time range searched, while the reference trace's timestamps stay on
2026-10-01.

## In CI

The `qualification` job of the Checks workflow runs on `ubuntu-24.04`: the
verifier's unit tests, `up`, `run --producer curl`, then `down`, and uploads
`build/qualification/` as the `qualification-<run id>` artifact, kept for 14
days. It is not required yet: it joins `required-baseline` once it has passed
three consecutive runs on `main`
([#56](https://github.com/LucasGois1/bend-telemetry/issues/56)).
