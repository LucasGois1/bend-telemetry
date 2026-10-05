#!/bin/sh
# The compliance status of bend-telemetry (#51):
# qualification/compliance/bend.yaml classifies every row of the compliance
# matrix of the OpenTelemetry specification at the pinned release, in the
# schema of the specification's own matrix files, and COMPLIANCE.md is
# generated from it. Nothing in COMPLIANCE.md is typed by hand.
#
#   ./scripts/compliance.sh          # regenerate COMPLIANCE.md
#   ./scripts/compliance.sh --check  # fail when the vendored template is not
#                                    # the pinned one, when the status file
#                                    # does not classify its rows, or when
#                                    # COMPLIANCE.md differs from the
#                                    # regeneration
#   ./scripts/compliance.sh --fetch  # download the pinned template again
#
# The pins are below: the specification's release and the SHA-256 of its
# spec-compliance-matrix/template.yaml, which the repository keeps as
# qualification/compliance/template.yaml so that the check runs offline; the
# status file names the same release. scripts/compliance.mjs parses both
# files, checks the status file against the template (every row of the
# template classified once, in its order, and no other; a status from the
# specification's legend; a ticket for a row that is not implemented; a
# reason for a row that does not apply) and renders the document; its header
# describes the statuses and the YAML it reads. Generation writes nothing
# unless every check passes.
#
# To move to a newer release, set spec_version and run --fetch: it fails,
# prints the new template's digest and keeps the template, with its diff from
# the vendored one, under build/quality/compliance/ for review. Pin that
# digest in template_digest, run --fetch again, change `specification` in the
# status file, classify every row that --check names, and regenerate. The
# check and the generation need Node 22 or newer, and --fetch needs curl.
# Evidence goes to build/quality/compliance/: the regenerated document and,
# when it differs from COMPLIANCE.md, the diff.
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"
usage="Usage: $0 [--check | --fetch]"
[ "$#" -le 1 ] || { echo "$usage" >&2; exit 2; }
mode=generate
case "${1:-}" in
  '') ;;
  --check) mode=check ;;
  --fetch) mode=fetch ;;
  *) echo "$usage" >&2; exit 2 ;;
esac

spec_version=1.61.0
# https://github.com/open-telemetry/opentelemetry-specification/tree/v1.61.0/spec-compliance-matrix
# The tag points at commit 32c0b2c1d9e11f68da0e6e7b63044e57878590de, whose
# template.yaml is the Git blob a2e95534a9ebd5c91df9def163d8fb74d85e72b8.
template_digest=cd2fdf3d1e4936aa78124d2b2ea589f78636ecd4432da109693b25b93a9ee604
template=qualification/compliance/template.yaml
status_file=qualification/compliance/bend.yaml
document=COMPLIANCE.md
evidence_dir=build/quality/compliance

if command -v sha256sum >/dev/null; then
  hash_command=sha256sum
elif command -v shasum >/dev/null; then
  hash_command=shasum
else
  echo "Install sha256sum or shasum to verify the template." >&2
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

rm -rf "$evidence_dir"
mkdir -p "$evidence_dir"

if [ "$mode" = fetch ]; then
  command -v curl >/dev/null || { echo "Required command: curl" >&2; exit 1; }
  url="https://raw.githubusercontent.com/open-telemetry/opentelemetry-specification/v$spec_version/spec-compliance-matrix/template.yaml"
  echo "Specification release: v$spec_version"
  echo "Template: $url"
  echo "Expected SHA256: $template_digest"
  fetched="$evidence_dir/template.yaml"
  curl --fail --silent --show-error --location --retry 3 --proto '=https' --tlsv1.2 "$url" -o "$fetched"
  actual_digest=$(digest_of "$fetched")
  if [ "$actual_digest" != "$template_digest" ]; then
    if [ -f "$template" ]; then
      diff -u "$template" "$fetched" > "$fetched.diff" || true
    fi
    echo "FAIL: the template of v$spec_version has the SHA-256 $actual_digest, not the pinned one; nothing was written. Review $fetched and $fetched.diff, and pin its digest in template_digest to adopt it." >&2
    exit 1
  fi
  cp "$fetched" "$template"
  echo "PASS: $template is the template of the specification v$spec_version"
  exit 0
fi

command -v node >/dev/null || { echo "Required command: node" >&2; exit 1; }
node_major=$(node -p 'Number(process.versions.node.split(".")[0])')
[ "$node_major" -ge 22 ] || { echo "Node 22 or newer is required; found $(node --version)." >&2; exit 1; }

status=0
if [ ! -f "$template" ]; then
  echo "FAIL: there is no $template; run ./scripts/compliance.sh --fetch." >&2
  status=1
elif [ "$(digest_of "$template")" = "$template_digest" ]; then
  echo "PASS: $template is the pinned template of the specification v$spec_version"
else
  echo "FAIL: $template is not the pinned template.yaml of the specification v$spec_version: its SHA-256 is $(digest_of "$template"), the pin $template_digest; run ./scripts/compliance.sh --fetch." >&2
  status=1
fi
generated="$evidence_dir/$document"
node scripts/compliance.mjs "v$spec_version" "$template" "$status_file" "$generated" || status=1

if [ "$mode" = check ]; then
  if [ -f "$generated" ]; then
    if diff -u "$document" "$generated" > "$evidence_dir/$document.diff" 2>&1; then
      rm -f "$evidence_dir/$document.diff"
      echo "PASS: $document is the document generated from $status_file"
    else
      cat "$evidence_dir/$document.diff" >&2
      echo "FAIL: $document differs from the document generated from $status_file; run ./scripts/compliance.sh and commit the result." >&2
      status=1
    fi
  fi
  exit "$status"
fi
[ "$status" -eq 0 ] || { echo "FAIL: nothing was written to $document." >&2; exit 1; }
cp "$generated" "$document"
echo "Generated $document from $status_file against the specification v$spec_version."
