#!/bin/sh
# Generate the semantic conventions package's entry module,
# packages/semconv/semconv.bend, from the pinned OpenTelemetry semantic
# conventions registry with the pinned weaver, through the Bend target in
# templates/registry/bend (#33). Nothing in that module is typed by hand.
#
#   ./scripts/semconv-generate.sh          # regenerate the committed module
#   ./scripts/semconv-generate.sh --check  # regenerate into a temporary
#                                          # directory and fail when the
#                                          # committed module differs
#
# The pins are below. weaver is a release asset, verified by SHA-256 and
# installed under .tools/weaver-<version>/, and the registry is the `model`
# folder of the semantic-conventions release archive, as the Go SDK fetches
# it, verified by a content digest: the SHA-256 of the sorted `SHA-256 path`
# lines of its files, which does not depend on how GitHub compressed the
# archive. The generated module is accepted only when it carries no
# `GENERATOR ERROR:` line, every definition has the shape
# `def Name() -> String:` with a valid Bend name, and no two definitions
# share a name (a collision of the name mapping, or of a project value with
# a value the registry now lists). packages/semconv/README.md explains how
# to move to a newer conventions version. Evidence goes to build/semconv/.
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"
usage="Usage: $0 [--check]"
[ "$#" -le 1 ] || { echo "$usage" >&2; exit 2; }
mode=generate
case "${1:-}" in
  '') ;;
  --check) mode=check ;;
  *) echo "$usage" >&2; exit 2 ;;
esac

weaver_version=0.26.1
# https://github.com/open-telemetry/weaver/releases/tag/v0.26.1
# Digests are pinned from the release's sha256.sum and GitHub release asset metadata.
case "$(uname -s)/$(uname -m)" in
  Darwin/arm64)
    weaver_platform=aarch64-apple-darwin
    weaver_digest=7324b3950a387a1e6ab506454a45177196d120be09a19aebad1e4d7627c00380
    ;;
  Linux/x86_64)
    weaver_platform=x86_64-unknown-linux-gnu
    weaver_digest=1be79cca68925c09b6da04ef8a3875b563cf7c1dcd51cc5b7eff7d2edbb1a5dc
    ;;
  *) echo "Supported hosts: macOS ARM64 and Linux x86_64." >&2; exit 1 ;;
esac
semconv_version=1.44.0
# https://github.com/open-telemetry/semantic-conventions/releases/tag/v1.44.0
# The tag points at commit e10a930844c6951757a43b849d364f7d056ac32b; the digest
# is the content digest of its model folder, computed by model_digest_of below.
model_digest=514c3c46ea35f7afbddbd0355f88157b1a70811e5693d2df88b69ed5b07a1787
package_dir=packages/semconv
module=semconv.bend
target=bend

for command_name in curl tar unzip diff; do
  command -v "$command_name" >/dev/null || { echo "Required command: $command_name" >&2; exit 1; }
done
if command -v sha256sum >/dev/null; then
  hash_command=sha256sum
elif command -v shasum >/dev/null; then
  hash_command=shasum
else
  echo "Install sha256sum or shasum to verify the downloads." >&2
  exit 1
fi
digest_of() {
  # digest_of FILE: the SHA-256 of a file, as 64 hex digits.
  if [ "$hash_command" = sha256sum ]; then
    sha256sum "$1" | cut -d ' ' -f 1
  else
    shasum -a 256 "$1" | cut -d ' ' -f 1
  fi
}
model_digest_of() {
  # model_digest_of DIRECTORY LISTING: write one `SHA-256 path` line per file
  # under the directory, sorted by path, to LISTING, and print the SHA-256
  # of that listing.
  (
    cd "$1"
    find . -type f | LC_ALL=C sort | while IFS= read -r file; do
      printf '%s %s\n' "$(digest_of "$file")" "$file"
    done
  ) > "$2"
  digest_of "$2"
}

evidence_dir=build/semconv
rm -rf "$evidence_dir"
mkdir -p "$evidence_dir" .tools
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/bend-telemetry-semconv.XXXXXXXX")
trap 'rm -rf "$work_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM
fetch() {
  # fetch URL FILE: download a release file over TLS, retrying.
  curl --fail --silent --show-error --location --retry 3 --proto '=https' --tlsv1.2 "$1" -o "$2"
}

# The pinned weaver, installed once under .tools and checked on every run.
weaver_dir=".tools/weaver-$weaver_version"
weaver="$weaver_dir/weaver"
if [ ! -x "$weaver" ]; then
  asset="weaver-$weaver_platform.tar.xz"
  url="https://github.com/open-telemetry/weaver/releases/download/v$weaver_version/$asset"
  echo "weaver release: v$weaver_version"
  echo "Asset: $url"
  echo "Expected SHA256: $weaver_digest"
  fetch "$url" "$work_dir/$asset"
  actual_digest=$(digest_of "$work_dir/$asset")
  [ "$actual_digest" = "$weaver_digest" ] || { echo "weaver checksum mismatch ($actual_digest); nothing was installed." >&2; exit 1; }
  mkdir -p "$work_dir/weaver"
  tar -xJf "$work_dir/$asset" -C "$work_dir/weaver" --strip-components 1
  [ "$("$work_dir/weaver/weaver" --version)" = "weaver $weaver_version" ] || {
    echo "weaver version mismatch; nothing was installed." >&2
    exit 1
  }
  rm -rf "$weaver_dir"
  mv "$work_dir/weaver" "$weaver_dir"
  echo "Installed verified weaver: $weaver_dir"
fi
[ "$("$weaver" --version)" = "weaver $weaver_version" ] || {
  echo "$weaver is not weaver $weaver_version; remove $weaver_dir and run again." >&2
  exit 1
}

# The pinned registry: the model folder of the release archive, verified by
# its content digest.
archive="v$semconv_version.zip"
url="https://github.com/open-telemetry/semantic-conventions/archive/refs/tags/$archive"
echo "Semantic conventions release: v$semconv_version"
echo "Archive: $url"
fetch "$url" "$work_dir/$archive"
unzip -q "$work_dir/$archive" -d "$work_dir/registry"
model_dir="$work_dir/registry/semantic-conventions-$semconv_version/model"
[ -d "$model_dir" ] || { echo "The archive carries no model folder." >&2; exit 1; }
actual_digest=$(model_digest_of "$model_dir" "$evidence_dir/model-files.txt")
echo "Expected model digest: $model_digest"
[ "$actual_digest" = "$model_digest" ] || {
  echo "Registry content mismatch: the model folder's digest is $actual_digest; nothing was generated." >&2
  exit 1
}

# Generation, into the work directory; HOME is scratch so that no personal
# weaver configuration takes part.
output_dir="$work_dir/output"
mkdir -p "$output_dir" "$work_dir/home"
if ! HOME="$work_dir/home" "$weaver" registry generate --quiet \
    --registry "$model_dir" --templates templates \
    --param "semconv_version=$semconv_version" --param "weaver_version=$weaver_version" \
    "$target" "$output_dir" > "$evidence_dir/weaver.log" 2>&1; then
  cat "$evidence_dir/weaver.log" >&2
  echo "weaver failed." >&2
  exit 1
fi
generated="$output_dir/$module"
[ -f "$generated" ] || { echo "weaver generated no $module." >&2; exit 1; }
cp "$generated" "$evidence_dir/$module"

# The generated module is accepted only when it is sound.
status=0
if grep -n '^GENERATOR ERROR:' "$generated" >&2; then
  echo "The template reported the errors above." >&2
  status=1
fi
if grep -E '^def ' "$generated" | grep -vE '^def [A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)*\(\) -> String:$' >&2; then
  echo "The definitions above are not constants with a valid Bend name." >&2
  status=1
fi
duplicates=$(sed -n 's/^def \(.*\)() -> String:$/\1/p' "$generated" | sort | uniq -d)
if [ -n "$duplicates" ]; then
  printf '%s\n' "$duplicates" >&2
  echo "The names above are defined more than once: a collision of the name mapping, or a project value of templates/registry/bend/project.bend.j2 that the registry now lists." >&2
  status=1
fi
[ "$status" -eq 0 ] || { echo "The generated module was rejected; nothing was written to $package_dir." >&2; exit 1; }

if [ "$mode" = check ]; then
  if ! diff -u "$package_dir/$module" "$generated" > "$evidence_dir/$module.diff" 2>&1; then
    cat "$evidence_dir/$module.diff" >&2
    echo "FAIL: $package_dir/$module differs from the code generated from semantic conventions v$semconv_version; run ./scripts/semconv-generate.sh and commit the result." >&2
    exit 1
  fi
  rm -f "$evidence_dir/$module.diff"
  echo "PASS: $package_dir/$module is the code generated from semantic conventions v$semconv_version with weaver $weaver_version"
else
  cp "$generated" "$package_dir/$module"
  echo "Generated $package_dir/$module from semantic conventions v$semconv_version with weaver $weaver_version."
fi
