# Changelog

All packages share one version and are released together
([VERSIONING.md](VERSIONING.md)). `VERSION` names the release of a commit:
release `X.Y.Z` is tagged `vX.Y.Z` and published on BendHub as
`bend-telemetry-<role>@X.Y.Z.0`; between releases, `VERSION` is the next
version with `-dev`.

## 0.1.0-dev — unreleased

Nothing is published yet. The repository's toolchain is in place (#3): the
pinned Bend 2.0.34 installer and `bend` wrapper, the `bend-telemetry-api`
package skeleton with its proof gate, the local hub that serves the working
tree's packages by name and version, the independent consumer, the tested
README example, and CI natively on Linux and macOS and on Node, with a weekly
job on the newest Bend release.
