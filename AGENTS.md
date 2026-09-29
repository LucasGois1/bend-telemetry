# Project instructions

## Project direction

- Aim for the most complete OpenTelemetry tracing implementation for Bend that is technically feasible and verifiable, following the OpenTelemetry specification. Evaluate features by their usefulness to adopters: instrumented libraries, applications and their operators.
- Treat ease of adoption, usability, and maintainability as delivery requirements. Common use cases must have a ready, documented path, with explicit control available for advanced integrations.
- Write idiomatic Bend: use types, pure functions, explicit effects, and laws/proofs appropriate to the contract. Distinguish proven properties, tested behavior, and environmental dependencies.
- Keep effects where their package's role allows them. The API package imports no foreign code, so instrumented libraries stay provable, and it uses only the pure codec of bend-trace-context. The SDK keeps a pure core, which a proof file imports alone, apart from its modules with effects (clock, host entropy, export). Exporters and instrumentation may have effects.
- W3C Trace Context belongs to [bend-trace-context](https://github.com/LucasGois1/bend-trace-context): build on it, and do not reimplement its rules here.
- This is a community project. Never present it as part of, or endorsed by, the OpenTelemetry project; use the OpenTelemetry name only descriptively.
- Keep the public repository dedicated to this implementation. Personal studies and learning experiments must stay out of versioned files and published history. Keep `docs/` local and untracked, including research and supporting planning notes; it must not appear in published history. Publish approved product specifications and decisions in GitHub issues so contributors can access the contract from a fresh clone.
- Use English as the repository standard for code identifiers, comments, documentation, filenames, directories, and GitHub artifacts.
- Complete planning through the selected Matt workflow before expanding implementation: `grill-with-docs`, specification, and tickets. Resolve factual questions through research and routine engineering choices using the criteria above; bring product trade-offs to the user when those criteria do not resolve them.
- Every pull request must be complete when it is opened. Fix in the pull request every problem found during the work that fits its scope; do not leave known problems as follow-up notes. Open a new issue for a problem outside that scope only when it truly needs work.

## Packages and releases

- Each package has one role and is published on BendHub as `bend-telemetry-<role>`: `api`, `sdk`, `exporter-otlp`, `instrumentation-http` and `semconv` ([#1](https://github.com/LucasGois1/bend-telemetry/issues/1)).
- All packages share one version and are released together ([VERSIONING.md](VERSIONING.md)).
- Packages import each other through BendHub by name and version, never by a relative path: a relative import bundles a private copy whose types do not match. Development across packages uses a local hub that serves the working tree.
- Pin exactly the Bend release that the pinned bend-trace-context version pins: an application compiles both with one compiler.
- Publication is manual. The maintainer reviews and authorizes each release, and the BendHub key never enters CI.

## Issue tracker: GitHub

Project issues and specifications live at https://github.com/LucasGois1/bend-telemetry/issues.
Use the `gh` CLI for operations. The repository can be resolved from `origin`; for commands run outside this checkout, provide `--repo LucasGois1/bend-telemetry`.

### Conventions

- Create an issue with `rtk proxy gh issue create --repo LucasGois1/bend-telemetry --title "..." --body-file <file>`.
- For multiline descriptions and comments, write the exact text to a temporary file and use `--body-file`. Preserve line breaks.
- Read the body, comments, and labels before working on an issue: `rtk proxy gh issue view <number> --repo LucasGois1/bend-telemetry --comments`.
- List work with `rtk proxy gh issue list --repo LucasGois1/bend-telemetry --state open --json number,title,body,labels,comments`.
- Comment with `rtk proxy gh issue comment <number> --repo LucasGois1/bend-telemetry --body-file <file>`.
- Add or remove labels with `rtk proxy gh issue edit <number> --repo LucasGois1/bend-telemetry --add-label <label>` or `--remove-label <label>`.
- Close an issue with `rtk proxy gh issue close <number> --repo LucasGois1/bend-telemetry`; record the outcome according to the active workflow.
- Use the triage label vocabulary below.
- Issues and PRs share GitHub numbering. For an ambiguous numeric reference, check the PR first and, if it does not exist, check the issue.

### Pull requests as a triage surface

**PRs as a request surface: no.**

### When a skill requests publication in the tracker

Create a GitHub issue for the artifact, respecting the active skill's checkpoints. To retrieve a ticket, read its entire issue and comments.

### Ticket dependencies

Use native GitHub dependencies when available. To declare a blocker:

1. Get the blocking issue's numeric database ID with `rtk proxy gh api repos/LucasGois1/bend-telemetry/issues/<number> --jq .id`.
2. Add the relationship with `rtk proxy gh api --method POST repos/LucasGois1/bend-telemetry/issues/<blocked-issue>/dependencies/blocked_by -F issue_id=<numeric-id>`.

The parameter is the database ID, not the issue number or `node_id`. When the dependency API is unavailable, record `Blocked by: #N` at the beginning of the body. An issue is only unblocked when all of its blockers are closed.

### Wayfinding operations

When the `wayfinder` workflow is needed:

- Keep the map in an issue labeled `wayfinder:map`, with decisions and open questions.
- Keep each decision in a child issue labeled `wayfinder:<type>` (`research`, `prototype`, `grilling`, or `task`). Link it through the native sub-issue relationship; if unavailable, use a list in the map and `Part of #N` in the child issue.
- The frontier includes only the map's child issues that are open, have no open blockers, and are unassigned; select the first in the map's order.
- Before working on a decision, assign the issue to yourself with `--add-assignee @me`.
- When resolved, record the answer in a comment, close the issue, and add a linked summary to the map's decisions.

## Triage labels

Mapping from the Matt workflow's canonical roles to this repository's labels:

| Role | GitHub label | Meaning |
| --- | --- | --- |
| `needs-triage` | `needs-triage` | Requires maintainer assessment |
| `needs-info` | `needs-info` | Waiting for information from the requester |
| `ready-for-agent` | `ready-for-agent` | Specified and ready for agent implementation |
| `ready-for-human` | `ready-for-human` | Requires human implementation |
| `wontfix` | `wontfix` | Will not be implemented |

When a skill mentions a role, use the corresponding label from this table.
Reuse existing labels; create only missing ones. Other GitHub labels may coexist with these.

## Domain documentation

This project uses a single-context layout. `CONTEXT.md` at the repository root is the public domain glossary. Approved specifications and decisions live in GitHub issues. Local files under `docs/`, including ADRs, are optional supporting context and must not be required to understand or contribute to the project.

### Before exploring the code

- Read `CONTEXT.md` if it exists.
- Read the approved specifications and decisions in GitHub issues that are relevant to the work.
- Read relevant local ADRs under `docs/adr/` when available.
- If local supporting files do not exist yet, proceed normally. Do not create empty files or treat their absence as a blocker.
- `grill-with-docs` and `domain-modeling` develop the glossary and decisions as terms and choices are resolved. Publish approved specifications and decisions in GitHub issues; keep supporting `docs/` files local.

### Vocabulary

`CONTEXT.md` is only a domain glossary: short definitions, preferred terms, and ambiguities to avoid.
Do not put specifications, backlogs, implementation decisions, or progress logs in it.

Use glossary terms in discussions, specifications, tickets, and concept names.
If a concept is missing or conflicting, raise it during domain modeling.

### Decisions

Record decisions that are difficult to reverse, surprising without context, and the result of a real choice between alternatives. Local ADRs may support the reasoning; publish approved decisions in GitHub issues so external contributors can retrieve them.
If a proposal conflicts with an existing approved decision or available ADR, make the conflict explicit before proceeding.
