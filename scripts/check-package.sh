#!/bin/sh
# Check every package manifest under packages/ against the working tree. A
# manifest is the package's package.json: its name is the BendHub name, its
# version is VERSION, and its `bend` field names the entry module and the
# hub packages the modules import, each at one version. The checks:
#
#   - the name is bend-telemetry-<role> and the version equals VERSION;
#   - the entry module exists and its first line ends with the Source URL,
#     which BendHub shows as the package's description;
#   - every hub import in the package's modules (`import <name>@<version>/`)
#     is a declared dependency at that version, and every declared
#     dependency is imported by some module;
#   - a LICENSE sits beside the entry module, opening with the SPDX line of
#     the repository's license and carrying the repository's LICENSE text;
#   - every `bend-telemetry-<role>@<version>` the READMEs and the tests name
#     is this repository's version, so that the examples import the package
#     that the local hub serves.
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"
command -v node >/dev/null || { echo "Required command: node" >&2; exit 1; }
status=0
fail() { echo "FAIL: $*" >&2; status=1; }
version=$(cat VERSION)
release=${version%-dev}
hub_version="$release.0"
source_url="https://github.com/LucasGois1/bend-telemetry"

for manifest in packages/*/package.json; do
  [ -f "$manifest" ] || { fail "no package manifest under packages/"; break; }
  package_dir=$(dirname -- "$manifest")
  name=$(./scripts/manifest-field.sh name "$manifest")
  manifest_version=$(./scripts/manifest-field.sh version "$manifest")
  license=$(./scripts/manifest-field.sh license "$manifest")
  entry=$(./scripts/manifest-field.sh bend.entry "$manifest")
  declared=$(./scripts/manifest-field.sh bend.dependencies "$manifest")
  case "$name" in
    bend-telemetry-[a-z]*) ;;
    *) fail "$manifest: the name must be bend-telemetry-<role>, not '$name'" ;;
  esac
  [ "$manifest_version" = "$version" ] || fail "$manifest: version '$manifest_version' is not VERSION '$version'"
  [ "$license" = Apache-2.0 ] || fail "$manifest: the license must be Apache-2.0"
  if [ -f "$package_dir/$entry" ]; then
    case "$(sed -n 1p "$package_dir/$entry")" in
      "# "*" Source: $source_url") ;;
      *) fail "$package_dir/$entry: the first line must be a comment ending with 'Source: $source_url'" ;;
    esac
  else
    fail "$manifest: the entry module $entry does not exist"
  fi
  imported=$(grep -h -o -E '^import [a-z][a-z0-9-]*@[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/' "$package_dir"/*.bend 2>/dev/null \
    | sed -e 's/^import //' -e 's|/$||' | sort -u || true)
  for dependency in $declared; do
    printf '%s\n' "$imported" | grep -qx -- "$dependency" || fail "$manifest declares $dependency, which no module of $package_dir imports"
  done
  for import in $imported; do
    printf '%s\n' "$declared" | grep -qx -- "$import" || fail "$package_dir imports $import, which $manifest does not declare at that version"
  done
  if [ -f "$package_dir/LICENSE" ]; then
    [ "$(sed -n 1p "$package_dir/LICENSE")" = "SPDX-License-Identifier: Apache-2.0" ] || fail "$package_dir/LICENSE must open with the SPDX line"
    [ -z "$(sed -n 2p "$package_dir/LICENSE")" ] || fail "$package_dir/LICENSE: line 2 must be empty"
    tail -n +3 "$package_dir/LICENSE" | diff -q - LICENSE >/dev/null || fail "$package_dir/LICENSE does not carry the repository's LICENSE after its SPDX line"
  else
    fail "$package_dir has no LICENSE beside its entry module"
  fi
done

named=$(grep -h -o -E 'bend-telemetry-[a-z][a-z0-9-]*@[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' README.md packages/*/README.md tests/consumer/*.bend 2>/dev/null | sort -u || true)
for reference in $named; do
  case "$reference" in
    *"@$hub_version") ;;
    *) fail "a README or tests/consumer names $reference; this repository is at $hub_version" ;;
  esac
done

[ "$status" -eq 0 ] && echo "PASS: package manifests"
exit "$status"
