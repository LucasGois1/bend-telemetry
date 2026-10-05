# Contributing

bend-telemetry is written in English: code identifiers, comments,
documentation, file names and GitHub artifacts. Every change starts from an
issue with acceptance criteria, and a pull request is complete when it is
opened: every problem found during the work that fits its scope is fixed in
it. Specifications and decisions live in the
[issues](https://github.com/LucasGois1/bend-telemetry/issues); `CONTEXT.md`
is the glossary, and its terms are the ones to use.

## Requirements

- Git, a POSIX shell, curl, tar and a SHA-256 tool (`sha256sum` or
  `shasum`); `unzip` and an xz-capable `tar` for the semantic conventions
  generator.
- Clang 14 or later for native builds (`CC` names another C compiler).
- Node 22 or later, for the local hub, for the programs that run under Node,
  for the qualification harness's verifier and for the compliance check.
- Docker, or Podman with a compose plugin, for the qualification harness.

## Setup

```sh
./scripts/setup-bend.sh
```

installs the pinned Bend release under `.tools/`: the archive is fetched by
version, checked against its pinned SHA-256, and the compiler must answer
that version; the release commit is recorded beside them as the pin's
identity. `./bend` runs that compiler, with the compiler's telemetry
disabled. The pin is the Bend release that the bend-trace-context version in
use pins (decision 9 of #1).

## Gates

Every pull request must pass:

```sh
./scripts/validate.sh
./scripts/test-consumer.sh native
./scripts/test-consumer.sh node
./scripts/semconv-generate.sh --check
```

and the quality checks that CI runs, which can be run locally as:

```sh
shellcheck bend scripts/*.sh
go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.12 -color
uvx zizmor==1.30.1 --no-online-audits .github/workflows
git ls-files -z -- '*.js' '*.mjs' | xargs -0 -n 1 node --check
./scripts/lint-lanes.sh
./scripts/test-lint-lanes.sh
./scripts/compliance.sh --check
./scripts/test-compliance.sh
lychee --offline --include-fragments --no-progress '*.md' 'packages/**/*.md' 'qualification/**/*.md'
```

(`lychee` v0.24 checks the local links; without it, follow the links by
hand.) The two lane scripts are described under [Lanes](#lanes), and the two
compliance scripts under [Compliance](#compliance).

`validate.sh` runs the proof gate of every package (`PROOF.bend
--check-only` must print `ALL PROOFS CHECK`, which Bend prints only when
every law holds and nothing the proofs import relies on `@unsafe` or foreign
code) against the local hub, since the SDK's modules import the API by its
hub name, `scripts/check-package.sh`, which checks each package manifest
against the working tree: name, version, entry module, declared hub
dependencies against the modules' imports, and the LICENSE beside the entry,
and the lane lint's list of effects against the compiler's Base (see
[Lanes](#lanes)).

`test-consumer.sh` clones the repository at a commit, installs the clone's
compiler, serves the clone's packages from the local hub and runs the clone's
programs against them: the independent consumer (`tests/consumer/`) and the
README's marked example, as `tests/lanes/programs.txt` lists them. Each runs
on the lanes that the list names for it: directly (in-process, on the
JavaScript lane), and compiled, natively or to JavaScript under `node`; it
tests commits, not uncommitted edits. Evidence goes under `build/`, which is
not tracked.

`semconv-generate.sh --check` regenerates the semantic conventions package
from the pinned registry with the pinned weaver and fails when the committed
module differs; `packages/semconv/README.md` describes the generator, the
pins and how to move to a newer conventions version. The generated module is
never edited by hand.

CI runs the same gates natively on Linux x86_64 and macOS ARM64 and, for the
programs that run under Node, on Node 22 and 24 (the first and the current
release of each line), plus the semantic conventions check on Linux and the
quality checks above, the lane lint among them.

The qualification harness is a gate too, not yet a required check: it sends
the reference trace over OTLP to an OpenTelemetry Collector, which exports it
to Grafana Tempo, and its verifier checks what the Collector wrote and what
Tempo shows. Run it before pushing a change to the reference trace, to the
harness or, later, to what a producer exports:

```sh
node --test qualification/*.test.mjs
./scripts/qualify.sh up
./scripts/qualify.sh run
./scripts/qualify.sh down
```

The first command runs the verifier's unit tests. CI runs all four in the
`qualification` job on Linux, with the Collector's output, the stack's logs
and the verifier's evidence as its artifact; `qualification/README.md`
describes the stack, its pins, the reference trace and what the verifier
asserts.

## Packages and the local hub

A package is a directory under `packages/` with a `package.json` that names
it (`bend-telemetry-<role>`), gives it the repository's version (`VERSION`),
and lists in its `bend` field the entry module and the hub packages its
modules import, each at one version. Modules import hub packages by name and
version (`import bend-trace-context@0.2.0.0/trace_context.bend as TC`) and
other modules of the same package by relative path; a package never imports
another package of this repository by a relative path.

`./scripts/local-hub.sh COMMAND` starts a local BendHub (`scripts/hub.mjs`),
publishes every package of the working tree to it with the compiler's own
`--publish`, in dependency order (a package goes after the packages of this
repository that its manifest declares), names each
`bend-telemetry-<role>@X.Y.Z.0` (X.Y.Z being `VERSION` without `-dev`), and
runs the command with `BEND_HUB`, `BEND_LIB` and `HOME` pointing at the hub, a
fresh cache and a scratch home, so that nothing touches `~/.bend`. Packages
the working tree imports are relayed from the real hub. For example:

```sh
./scripts/local-hub.sh ./bend tests/consumer/main.bend
```

## Documentation that is tested

Code blocks marked `<!-- test:NAME:start -->` and `<!-- test:NAME:end -->`
are programs that the gates run; a block marked `NAME-output` holds the
exact output. `scripts/doc-block.sh NAME FENCE DOCUMENT` extracts one block.
Print only stable output in such a program.

## Lanes

The [README](README.md#lanes) has the lane matrix, which says where each
package runs. Programs run natively (C) and on the JavaScript lane, which is
the Bun that the pinned compiler embeds: `./bend file.bend` runs in-process.
Node, which is not a lane, runs the JavaScript that `-o x.js` emits, and only
for programs with no effect that waits (and for the pure `-o x.mjs` module),
as the lane matrix of
[#38](https://github.com/LucasGois1/bend-telemetry/issues/38) says: the
consumer and the README example run there; the SDK's pipeline will not. The
effects that wait are `IO.sleep`, `IO.within`, files, TCP and UDP sockets and
`Process.run`; an `IO.get_env` of an unset variable fails the same way.
Bend's JavaScript effects load `bun:ffi` when they wait or fail, and Node has
none (`Process.run` needs `Bun.spawnSync`); printing, channels, spawn and the
clock do not load it.

`tests/lanes/programs.txt` is the lane matrix of the toolchain, program by
program: each program that `scripts/test-consumer.sh` runs, with the lanes it
runs on (`native`, `javascript`, `node`). The runner takes its programs from
it, and runs each on the lanes of its row. A program that cannot run under
Node leaves `node` out of its row, as the SDK's configuration consumer does,
and putting a program under Node takes that word in its row. A program that
is a file may declare the environment the runner sets for its runs: the file
beside it with `.env` in place of `.bend`, one `NAME=value` per line, as
`tests/consumer/sdk_config.env` does.

`scripts/lint-lanes.sh` reads the programs on the node lane of the same list.
It follows each program's imports (relative modules, and the packages of this
repository from the working tree) and fails, naming the file, the line and
the effect, when a program or a module that it imports names an effect that
waits or reads the environment without a guaranteed value. An unset variable
fails inside the effect whatever the program does with the result, so a read
passes only when a comment on its line says who sets the variable: `# lanes:
guaranteed by the node job, which exports NAME`. The lint takes that comment
at its word, so review checks it. The lint reads text, so comments and
literals do not count; what it cannot read it names in a note and does not
judge: a package of another repository, which a clean checkout does not have,
and foreign code (a def whose body imports `.c` or `.js` files). The node
job's own run covers what it executes. Its names are the effects of Base in
the pinned compiler, and `validate.sh` checks them against `./bend base`
(`lint-lanes.sh --base FILE`): every effect of Base, and every def built on
one that waits, must be one that the lint flags or one that it has reviewed
and leaves alone, so a Bend with a new effect fails there, and in the weekly
job, until the lint classifies it.

`scripts/test-lint-lanes.sh` tests the lint: the programs on the node lane
pass, and the negative fixtures of `tests/lanes/fixtures/` (a program that
sleeps, one that imports a module or a package that waits, an environment
read) fail with the literal transcripts of `tests/lanes/expected/`; so does an
excerpt of Base that gains or renames an effect. Evidence goes under
`build/quality/lanes/`, and CI runs both scripts in the `quality` job.

### The job convention

Every package follows it as its tickets land, so that the matrix is checked
and not asserted:

- Native, required, on Linux x86_64 and macOS ARM64: the package's proof
  gate, consumer and corpora, compiled with `-o` and run.
- The JavaScript lane, required: the same consumer and corpora, run
  in-process with `./bend file.bend`. The native and node jobs run them, so a
  package needs no job of its own for the lane.
- Node, required, on Node 22 and 24: the `-o x.js` builds of the package's
  pure programs, run with `node`. Each is a row of `tests/lanes/programs.txt`
  with the `node` lane, so the lint checks it. A pure `-o x.mjs` module is not
  a program of the consumer runner: the script that builds and imports it runs
  `scripts/lint-lanes.sh` on its source first.
- A job that cannot be required yet, such as bend-kit's transport under the
  embedded Bun, starts as not required and is promoted when it is green on
  the pinned and on the newest Bend.

The weekly `Newest Bend` workflow runs the same matrix on the newest
release: the native job on Linux and macOS, and the node job on Node 22 and
24, each running its programs in-process as well.

## Compliance

[COMPLIANCE.md](COMPLIANCE.md) says, for every row of the compliance matrix
of the OpenTelemetry specification, whether this project implements it,
implements part of it, has it pending with the ticket that implements it, or
does not apply and why. It is generated from the status file,
[qualification/compliance/bend.yaml](qualification/compliance/bend.yaml),
kept in the schema of the specification's own matrix files; the file's
header gives its statuses and keys. A pull request that implements a row,
or part of one, updates that row of the status file in the same pull
request, and regenerates the document, which is never edited by hand:

```sh
./scripts/compliance.sh
```

`./scripts/compliance.sh --check`, which CI runs in the `quality` job, fails
when `qualification/compliance/template.yaml` is not the specification's
template at the pinned release, checked by its SHA-256; when the status file
does not classify every row of that template, once, in its order, and no
other; when a row has a status outside the specification's legend, or is not
implemented and names neither its ticket nor the reason it does not apply;
and when `COMPLIANCE.md` differs from the regeneration.
`./scripts/test-compliance.sh` shows each of these failures on a scratch copy
of the files. The header of `scripts/compliance.sh` says how to move to a
newer release of the specification, which `--fetch` downloads and checks.

## The Bend pin

The repository pins one exact Bend release, and Bend releases often. Every
week, and on demand, the `Newest Bend` workflow runs the gates on the newest
release in place of the pinned one, with the matrix of [the job
convention](#the-job-convention): `./scripts/try-bend.sh` pins that release
in the runner's checkout only and commits the result there. It is not a
required check; a failed run tells the maintainer that a move needs work. A
move changes `version`, `release_commit` and the digests in
`scripts/setup-bend.sh` (the wrapper reads the version from there), follows
the bend-trace-context release that pins the same compiler, classifies in
`scripts/lint-lanes.sh` any effect of Base that `validate.sh` reports as new,
updates the Bun version that the README's lane matrix names (a program whose
JavaScript effect prints `Bun.version`, run in-process, tells the embedded
one), and updates the changelog.

## Branches and pull requests

Branches are named `feat/<issue>-<slug>`, `docs/<slug>`, `chore/<slug>` or
`release/X.Y.Z`. Commit subjects follow `feat:`, `fix:`, `docs:`, `chore:`,
`ci:` and `release:`. `docs/` at the repository root is local and untracked:
research and planning notes never enter the published history.
