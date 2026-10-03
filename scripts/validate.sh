#!/bin/sh
# The repository's static gates, run on the pinned compiler:
#
#   - the proof gate of every package: `PROOF.bend --check-only` prints
#     "ALL PROOFS CHECK", which Bend prints only when every law holds and
#     nothing the proofs import relies on `@unsafe` or foreign code;
#   - the effects of the compiler's Base, which the lane lint must know: each
#     one is flagged as an effect that waits or reviewed and left alone
#     (scripts/lint-lanes.sh --base), so that a newer Bend with a new effect
#     fails here, and in the weekly job, rather than pass unseen;
#   - the package manifests (scripts/check-package.sh).
#
# Evidence goes to build/validation/.
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"
build_dir=build/validation
rm -rf "$build_dir"
mkdir -p "$build_dir"

for proof in packages/*/PROOF.bend; do
  [ -f "$proof" ] || { echo "No PROOF.bend under packages/." >&2; exit 1; }
  package=$(basename -- "$(dirname -- "$proof")")
  if ! ./bend "$proof" --check-only > "$build_dir/proofs-$package.txt" 2>&1; then
    cat "$build_dir/proofs-$package.txt"
    exit 1
  fi
  cat "$build_dir/proofs-$package.txt"
  [ "$(head -n 1 "$build_dir/proofs-$package.txt")" = 'ALL PROOFS CHECK' ] || {
    echo "The proof check of $package did not print ALL PROOFS CHECK first." >&2
    exit 1
  }
  echo "PASS: proofs of $package"
done

./bend base > "$build_dir/base.txt"
./scripts/lint-lanes.sh --base "$build_dir/base.txt"

./scripts/check-package.sh
echo "PASS: validate"
