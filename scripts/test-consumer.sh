#!/bin/sh
# Run the independent consumer against a clean clone of this repository at a
# commit, as an adopter would use the published packages: the clone installs
# its own pinned compiler, its packages are served by the local hub under
# their BendHub names, and the programs import them by name and version.
#
#   ./scripts/test-consumer.sh [native|node] [repository] [full-sha]
#
# The programs come from the clone's tests/lanes/programs.txt, which names the
# lanes of each: the consumer of tests/consumer/ and the README's marked
# `readme-bend` example today. A program on the javascript lane runs directly
# on the clone's compiler (in-process, the JavaScript lane); one on the native
# lane is compiled (`-o`) and run in native mode, and one on the node lane is
# compiled to JavaScript and run with `node` in node mode. The same list gives
# scripts/lint-lanes.sh the programs that it checks for effects that node
# cannot run. A program that is a file may declare the environment its runs
# get: the file beside it with `.env` in place of `.bend`, one NAME=value per
# line, as the list's header says. Every output is compared with its literal
# expectation. Evidence goes to build/consumer-<mode>/. The repository
# defaults to this checkout and the commit to its HEAD; the runner tests
# commits, not uncommitted edits.
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
  on_lane() {
    # on_lane LANES LANE: whether the comma-separated LANES name LANE.
    case ",$1," in *",$2,"*) return 0 ;; esac
    return 1
  }
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
    # run_step LABEL COMMAND...: run a step of the current program, keeping
    # its output as evidence and printing its stderr on failure. When the
    # program declares an environment ($program.env, one NAME=value per
    # line), every step of it runs with those variables set.
    label=$1
    shift
    if [ -f "$program.env" ]; then
      while IFS= read -r pair; do
        set -- "$pair" "$@"
      done < "$program.env"
      set -- env "$@"
    fi
    if "$@" < /dev/null > "$evidence_dir/$label.stdout" 2> "$evidence_dir/$label.stderr"; then
      return 0
    fi
    echo "FAIL: $label:" >&2
    cat "$evidence_dir/$label.stderr" >&2
    return 1
  }
  while read -r program lanes; do
    passed=1
    ran=0
    if on_lane "$lanes" javascript; then
      ran=1
      if run_step "$program-direct" "$clone/bend" "$program.bend"; then
        compare "$program.expected" "$evidence_dir/$program-direct.stdout" "$program-direct" || passed=0
      else
        passed=0
      fi
    fi
    if [ "$mode" = node ] && on_lane "$lanes" node; then
      ran=1
      if run_step "$program-compile" "$clone/bend" "$program.bend" -o "build/$program.js" \
        && run_step "$program-compiled" node "build/$program.js"; then
        compare "$program.expected" "$evidence_dir/$program-compiled.stdout" "$program-compiled" || passed=0
      else
        passed=0
      fi
    elif [ "$mode" = native ] && on_lane "$lanes" native; then
      ran=1
      if run_step "$program-compile" "$clone/bend" "$program.bend" -o "build/$program" \
        && run_step "$program-compiled" "./build/$program"; then
        compare "$program.expected" "$evidence_dir/$program-compiled.stdout" "$program-compiled" || passed=0
      else
        passed=0
      fi
    fi
    if [ "$passed" = 0 ]; then
      status=1
    elif [ "$ran" = 0 ]; then
      echo "SKIP: independent $program ($mode): it is on no lane of this mode"
    else
      echo "PASS: independent $program ($mode)"
    fi
  done < programs
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

materialize() {
  # materialize SOURCE FENCE DESTINATION: a program, or what it prints, is a
  # file of the clone or FILE#NAME for the block that FILE marks NAME.
  case "$1" in
    *'#'*) "$clone/scripts/doc-block.sh" "${1#*#}" "$2" "$clone/${1%%#*}" > "$3" ;;
    *) cp "$clone/$1" "$3" ;;
  esac
}
program_list="$clone/tests/lanes/programs.txt"
[ -f "$program_list" ] || { echo "The clone has no tests/lanes/programs.txt." >&2; exit 1; }
grep -v -E '^[[:space:]]*(#|$)' "$program_list" > "$test_dir/list" || true
: > "$test_dir/programs"
while read -r name source expected_source lanes extra; do
  if [ -z "$lanes" ] || [ -n "$extra" ]; then
    echo "tests/lanes/programs.txt: $name has not four columns: name, program, expected, runs-on." >&2
    exit 1
  fi
  materialize "$source" bend "$test_dir/$name.bend"
  materialize "$expected_source" text "$test_dir/$name.expected"
  cp "$test_dir/$name.bend" "$test_dir/$name.expected" "$evidence_dir/"
  # The environment a program that is a file declares beside itself, if any.
  case "$source" in
    *'#'*) ;;
    *)
      if [ -f "$clone/${source%.bend}.env" ]; then
        cp "$clone/${source%.bend}.env" "$test_dir/$name.env"
        cp "$test_dir/$name.env" "$evidence_dir/"
      fi
      ;;
  esac
  printf '%s %s\n' "$name" "$lanes" >> "$test_dir/programs"
done < "$test_dir/list"
[ -s "$test_dir/programs" ] || { echo "tests/lanes/programs.txt lists no program." >&2; exit 1; }

LOCAL_HUB_SOURCE="$clone" LOCAL_HUB_DIR="$test_dir/hub" "$clone/scripts/local-hub.sh" \
  sh "$clone/scripts/test-consumer.sh" --run-programs "$mode" "$test_dir" "$clone" "$evidence_dir"
cp "$test_dir/hub/packages.txt" "$evidence_dir/packages.txt"
echo "PASS: test-consumer ($mode)"
