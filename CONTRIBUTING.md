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
  `shasum`).
- Clang 14 or later for native builds (`CC` names another C compiler).
- Node 22 or later, for the local hub and the JavaScript lane's compiled
  programs.

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
```

and the quality checks that CI runs, which can be run locally as:

```sh
shellcheck bend scripts/*.sh
go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.12 -color
uvx zizmor==1.30.1 --no-online-audits .github/workflows
git ls-files -z -- '*.js' '*.mjs' | xargs -0 -n 1 node --check
lychee --offline --include-fragments --no-progress '*.md' 'packages/**/*.md'
```

(`lychee` v0.24 checks the local links; without it, follow the links by
hand.)

`validate.sh` runs the proof gate of every package (`PROOF.bend
--check-only` must print `ALL PROOFS CHECK`, which Bend prints only when
every law holds and nothing the proofs import relies on `@unsafe` or foreign
code) and `scripts/check-package.sh`, which checks each package manifest
against the working tree: name, version, entry module, declared hub
dependencies against the modules' imports, and the LICENSE beside the entry.

`test-consumer.sh` clones the repository at a commit, installs the clone's
compiler, serves the clone's packages from the local hub and runs the clone's
independent consumer (`tests/consumer/`) and README marked example against
them, directly and compiled; it tests commits, not uncommitted edits.
Evidence goes under `build/`, which is not tracked.

CI runs the same gates natively on Linux x86_64 and macOS ARM64 and, for the
JavaScript lane, on Node 22 and 24 (the first and the current release of
each line), plus the quality checks above.

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
`--publish`, names each `bend-telemetry-<role>@X.Y.Z.0` (X.Y.Z being
`VERSION` without `-dev`), and runs the command with `BEND_HUB`, `BEND_LIB`
and `HOME` pointing at the hub, a fresh cache and a scratch home, so that
nothing touches `~/.bend`. Packages the working tree imports are relayed from
the real hub. For example:

```sh
./scripts/local-hub.sh ./bend tests/consumer/main.bend
```

## Documentation that is tested

Code blocks marked `<!-- test:NAME:start -->` and `<!-- test:NAME:end -->`
are programs that the gates run; a block marked `NAME-output` holds the
exact output. `scripts/doc-block.sh NAME FENCE DOCUMENT` extracts one block.
Print only stable output in such a program.

## Lanes

Programs run natively (C) and on the JavaScript lane, which is the Bun that
the pinned compiler embeds: `./bend file.bend` runs in-process. `node` runs
only `-o x.js` builds of programs with no effect that waits, as the lane
matrix of #38 says: the consumer and the README example qualify; the SDK's
pipeline will not.

## The Bend pin

The repository pins one exact Bend release, and Bend releases often. Every
week, and on demand, the `Newest Bend` workflow runs the gates on the newest
release in place of the pinned one: `./scripts/try-bend.sh` pins that release
in the runner's checkout only and commits the result there. It is not a
required check; a failed run tells the maintainer that a move needs work. A
move changes `version`, `release_commit` and the digests in
`scripts/setup-bend.sh` (the wrapper reads the version from there), follows
the bend-trace-context release that pins the same compiler, and updates the
changelog.

## Branches and pull requests

Branches are named `feat/<issue>-<slug>`, `docs/<slug>`, `chore/<slug>` or
`release/X.Y.Z`. Commit subjects follow `feat:`, `fix:`, `docs:`, `chore:`,
`ci:` and `release:`. `docs/` at the repository root is local and untracked:
research and planning notes never enter the published history.
