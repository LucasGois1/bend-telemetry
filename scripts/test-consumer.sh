#!/bin/sh
# Run the independent consumer against a clean clone of this repository at a
# commit, as an adopter would use the published packages: the clone installs
# its own pinned compiler, its packages are served by the local hub under
# their BendHub names, and the programs import them by name and version.
#
#   ./scripts/test-consumer.sh [native|node] [repository] [full-sha]
#
# The programs come from the clone: the consumer of tests/consumer/ and the
# README's marked `readme-bend` example. Each runs directly on the clone's
# compiler (in-process, the JavaScript lane); then it is compiled natively
# (`-o`) in native mode, or to JavaScript and run with `node` in node mode.
# Every output is compared with its literal expectation. Evidence goes to
# build/consumer-<mode>/. The repository defaults to this checkout and the
# commit to its HEAD; the runner tests commits, not uncommitted edits.
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

if [ "${1:-}" = --run-programs ]; then
  # The inner step, run by scripts/local-hub.sh with the hub's environment.
  shift
  mode=$1
  test_dir=$2
  clone=$3
  evidence_dir=$4
  cd "$test_dir"
  mkdir -p build
  status=0
  compare() {
    if diff -u "$1" "$2" > "$evidence_dir/$3.diff" 2>&1; then
      rm -f "$evidence_dir/$3.diff"
      return 0
    fi
    echo "FAIL: $3 differs from its expectation:" >&2
    cat "$evidence_dir/$3.diff" >&2
    return 1
  }
  run_step() {
    # run_step LABEL COMMAND...: run a command, keeping its output as evidence
    # and printing its stderr on failure.
    label=$1
    shift
    if "$@" > "$evidence_dir/$label.stdout" 2> "$evidence_dir/$label.stderr"; then
      return 0
    fi
    echo "FAIL: $label:" >&2
    cat "$evidence_dir/$label.stderr" >&2
    return 1
  }
  for program in consumer readme-bend; do
    passed=1
    if run_step "$program-direct" "$clone/bend" "$program.bend"; then
      compare "$program.expected" "$evidence_dir/$program-direct.stdout" "$program-direct" || passed=0
    else
      passed=0
    fi
    if [ "$mode" = node ]; then
      if run_step "$program-compile" "$clone/bend" "$program.bend" -o "build/$program.js" \
        && run_step "$program-compiled" node "build/$program.js"; then
        compare "$program.expected" "$evidence_dir/$program-compiled.stdout" "$program-compiled" || passed=0
      else
        passed=0
      fi
    else
      if run_step "$program-compile" "$clone/bend" "$program.bend" -o "build/$program" \
        && run_step "$program-compiled" "./build/$program"; then
        compare "$program.expected" "$evidence_dir/$program-compiled.stdout" "$program-compiled" || passed=0
      else
        passed=0
      fi
    fi
    if [ "$passed" = 1 ]; then
      echo "PASS: independent $program ($mode)"
    else
      status=1
    fi
  done
  exit "$status"
fi

mode=${1:-native}
case "$mode" in native|node) ;; *) echo "Usage: $0 [native|node] [repository] [full-sha]" >&2; exit 2 ;; esac
source_repo=${2:-$repo_dir}
revision=${3:-$(git -C "$source_repo" rev-parse HEAD)}
printf '%s\n' "$revision" | grep -Eq '^[0-9a-f]{40}$' || { echo "The commit must be a full SHA." >&2; exit 1; }
evidence_dir="$repo_dir/build/consumer-$mode"
rm -rf "$evidence_dir"
mkdir -p "$evidence_dir"

for command_name in git node; do
  command -v "$command_name" >/dev/null || { echo "Required command: $command_name" >&2; exit 1; }
done
if [ "$mode" = node ]; then
  node_major=$(node -p 'Number(process.versions.node.split(".")[0])')
  [ "$node_major" -ge 22 ] || { echo "Node 22 or newer is required; found $(node --version)." >&2; exit 1; }
else
  export CC="${CC:-clang}"
  command -v "$CC" >/dev/null || { echo "A C compiler is required for native builds: $CC" >&2; exit 1; }
fi

test_dir=$(mktemp -d "${TMPDIR:-/tmp}/bend-telemetry-consumer.XXXXXXXX")
trap 'rm -rf "$test_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM
clone="$test_dir/source"
git clone --quiet --no-local --no-checkout "$source_repo" "$clone"
git -C "$clone" checkout --quiet --detach "$revision"
[ "$(git -C "$clone" rev-parse HEAD)" = "$revision" ]
[ ! -e "$clone/.tools" ] || { echo "The clone must not carry an installed compiler." >&2; exit 1; }
printf 'repository: %s\ncommit: %s\nmode: %s\n' "$source_repo" "$revision" "$mode" > "$evidence_dir/source.txt"

"$clone/scripts/setup-bend.sh" > "$evidence_dir/setup-bend.log" 2>&1 || {
  cat "$evidence_dir/setup-bend.log" >&2
  exit 1
}

cp "$clone/tests/consumer/main.bend" "$test_dir/consumer.bend"
cp "$clone/tests/consumer/expected.txt" "$test_dir/consumer.expected"
"$clone/scripts/doc-block.sh" readme-bend bend "$clone/README.md" > "$test_dir/readme-bend.bend"
"$clone/scripts/doc-block.sh" readme-bend-output text "$clone/README.md" > "$test_dir/readme-bend.expected"
cp "$test_dir/consumer.bend" "$test_dir/consumer.expected" "$test_dir/readme-bend.bend" "$test_dir/readme-bend.expected" "$evidence_dir/"

LOCAL_HUB_SOURCE="$clone" LOCAL_HUB_DIR="$test_dir/hub" "$clone/scripts/local-hub.sh" \
  sh "$clone/scripts/test-consumer.sh" --run-programs "$mode" "$test_dir" "$clone" "$evidence_dir"
cp "$test_dir/hub/packages.txt" "$evidence_dir/packages.txt"
echo "PASS: test-consumer ($mode)"
