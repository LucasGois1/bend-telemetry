#!/bin/sh
# Test the lane lint, scripts/lint-lanes.sh, the way CI runs it:
#
#   ./scripts/test-lint-lanes.sh
#
# The programs on the node lane of tests/lanes/programs.txt must pass, and the
# lint must follow their imports into this repository's packages. Each
# fixture under tests/lanes/fixtures/ must then give the exit status and the
# transcript that tests/lanes/expected/ holds, line for line:
#
#   sleeps            a program that sleeps fails;
#   listed_sleeper    so does one on the node lane of a list, which is how CI
#                     gives the lint its programs, and one off the node lane
#                     is not linted (not_on_node);
#   imports_sleeper   so does one that imports a module that waits, also from
#                     the directory above (imports_parent) and by an indented
#                     import, which Bend accepts (indented_import);
#   imports_package   and one that imports a package of this repository whose
#                     modules wait, two imports down (--packages says where
#                     the packages are);
#   env               an environment read fails unless a comment states who
#                     guarantees the value, and a guarantee covers nothing
#                     else;
#   multiline_string  a string that spans lines hides what it says, but not
#                     the code after it;
#   block             a code block that a document marks fails, at the line
#                     that the document gives it;
#   imports_unknown   imports that the lint cannot follow fail, as do a
#                     missing program and a missing block;
#   imports_foreign   imports that it knows it cannot read, such as a package
#                     of another repository, are named in a note and pass, as
#                     does foreign code (foreign_code);
#   not_effects       names that only look like effects, in comments, in
#                     strings and in other namespaces, pass.
#
# The base_* cases test `--base`, which checks the lint's effects against the
# text of Base: an excerpt of Bend 2.0.34's passes; a new effect, one written
# with a wrapped parameter list, a def built on an effect that waits, a
# renamed effect, and text that is not Base fail. Last, a program for each
# effect that waits must fail and name that effect, so that no name drops out
# of the lint's list unseen; then the lists that the lint refuses and the
# usage errors. Evidence goes to build/quality/lanes/: the lint's transcript
# of every case.
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"
lint=./scripts/lint-lanes.sh
[ -x "$lint" ] || { echo "No lane lint at $lint." >&2; exit 1; }
fixtures=tests/lanes/fixtures
expected_dir=tests/lanes/expected
evidence_dir=build/quality/lanes
rm -rf "$evidence_dir"
mkdir -p "$evidence_dir/effects"
failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

# run_lint CASE ARGS...: run the lint, keep its transcript and its standard
# error as evidence, and leave its exit status in lint_status.
run_lint() {
  lint_case=$1
  shift
  lint_status=0
  "$lint" "$@" > "$evidence_dir/$lint_case.txt" 2> "$evidence_dir/$lint_case.stderr" || lint_status=$?
}

# expect CASE STATUS ARGS...: the lint exits with STATUS and prints the
# transcript of tests/lanes/expected/CASE.txt; a failure ends with its
# summary on the standard error.
expect() {
  expect_case=$1
  expect_status=$2
  shift 2
  run_lint "$expect_case" "$@"
  if [ "$lint_status" -ne "$expect_status" ]; then
    fail "$expect_case: the lint exited $lint_status, not $expect_status"
    cat "$evidence_dir/$expect_case.stderr" >&2
  elif ! diff -u "$expected_dir/$expect_case.txt" "$evidence_dir/$expect_case.txt" > "$evidence_dir/$expect_case.diff"; then
    fail "$expect_case: the transcript differs from $expected_dir/$expect_case.txt"
    cat "$evidence_dir/$expect_case.diff" >&2
  elif [ "$expect_status" -eq 1 ] && ! grep -q '^FAIL: lint-lanes' "$evidence_dir/$expect_case.stderr"; then
    fail "$expect_case: a failing lint must end with a FAIL: lint-lanes line on its standard error"
  else
    rm -f "$evidence_dir/$expect_case.diff"
    echo "PASS: $expect_case"
  fi
}

# The programs on the node lane pass, and the lint followed their imports: it
# scanned each program, the module that each repository package of the
# consumer's imports names, and it named each package of another repository.
before=$failures
run_lint programs
if [ "$lint_status" -ne 0 ]; then
  fail "programs: the programs on the node lane must pass the lint"
  cat "$evidence_dir/programs.txt" "$evidence_dir/programs.stderr" >&2
else
  # shellcheck disable=SC2016 # $1, $4 and $2 belong to awk, not the shell.
  awk '$1 !~ /^#/ && NF == 4 && $4 ~ /node/ { print $2 }' tests/lanes/programs.txt > "$evidence_dir/node_programs.list"
  while read -r program; do
    grep -Fxq -- "scanned: $program" "$evidence_dir/programs.txt" || fail "programs: the transcript lacks 'scanned: $program'"
  done < "$evidence_dir/node_programs.list"
  sed -n 's/^import \(bend-[^ ]*\) as .*$/\1/p' tests/consumer/main.bend > "$evidence_dir/consumer_imports.list"
  while read -r target; do
    case "$target" in
      bend-telemetry-*)
        role=${target#bend-telemetry-}
        module="packages/${role%%@*}/${target#*/}"
        grep -Fxq -- "scanned: $module" "$evidence_dir/programs.txt" || fail "programs: the transcript lacks 'scanned: $module'"
        ;;
      *)
        grep -Fq -- "note: not followed: $target " "$evidence_dir/programs.txt" || fail "programs: the transcript does not name $target as not followed"
        ;;
    esac
  done < "$evidence_dir/consumer_imports.list"
fi
[ "$failures" -ne "$before" ] || echo "PASS: programs"

expect sleeps 1 "$fixtures/sleeps.bend"
expect listed_sleeper 1 --list "$fixtures/listed_sleeper.txt"
expect not_on_node 0 --list "$fixtures/not_on_node.txt"
expect imports_sleeper 1 "$fixtures/imports_sleeper.bend"
expect imports_parent 1 "$fixtures/nested/imports_parent.bend"
expect indented_import 1 "$fixtures/indented_import.bend"
expect imports_package 1 --packages "$fixtures/packages" "$fixtures/imports_package.bend"
expect env 1 "$fixtures/env.bend"
expect multiline_string 1 "$fixtures/multiline_string.bend"
expect block 1 "$fixtures/block.md#slow"
expect imports_unknown 1 "$fixtures/imports_unknown.bend"
expect imports_foreign 0 "$fixtures/imports_foreign.bend"
expect foreign_code 0 "$fixtures/foreign_code.bend"
expect missing_block 1 "$fixtures/block.md#absent"
expect missing_program 1 "$fixtures/nonexistent.bend"
expect not_effects 0 "$fixtures/not_effects.bend"

# The effects of Base, as `--base` checks them.
base_excerpt=$fixtures/base_effects.txt
expect base_known 0 --base "$base_excerpt"
{
  printf 'def Time.sleep(ms: U32) -> IO(Unit):\n  import "./effs/time_sleep.c"\n  import "./effs/time_sleep.js"\n\n'
  cat "$base_excerpt"
} > "$evidence_dir/base_new_effect.base"
expect base_new_effect 1 --base "$evidence_dir/base_new_effect.base"
{
  printf 'def Time.sleep(\n  ms: U32\n) -> IO(Unit):\n  import "./effs/time_sleep.c"\n  import "./effs/time_sleep.js"\n\n'
  cat "$base_excerpt"
} > "$evidence_dir/base_wrapped.base"
expect base_wrapped 1 --base "$evidence_dir/base_wrapped.base"
{
  printf 'def IO.timeout(-A: Type, ms: U32, act: IO(A)) -> IO(Maybe<&1, A>):\n  IO.within(A, ms, act)\n\n'
  cat "$base_excerpt"
} > "$evidence_dir/base_derived.base"
expect base_derived 1 --base "$evidence_dir/base_derived.base"
sed 's/^def IO\.sleep(/def Time.sleep(/' "$base_excerpt" > "$evidence_dir/base_renamed.base"
expect base_renamed 1 --base "$evidence_dir/base_renamed.base"
expect base_not_base 1 --base "$fixtures/sleeps.bend"

# Every effect that waits, one program each: Base's own spellings.
effects='IO.sleep IO.within
  File.open File.read File.read_bytes File.read_at File.size File.write File.write_bytes File.close
  TCP.listen TCP.accept TCP.connect TCP.send TCP.recv TCP.send_bytes TCP.recv_bytes TCP.poll
  UDP.bind UDP.send_to UDP.recv_from UDP.poll Socket.close Listener.close
  Process.run IO.get_env'
before=$failures
for effect in $effects; do
  program="$evidence_dir/effects/$effect.bend"
  printf 'import Base\n\ndef main() -> IO(Unit):\n  %s()\n' "$effect" > "$program"
  run_lint "effects/$effect" "$program"
  if [ "$lint_status" -ne 1 ] || ! grep -Fq -- "$program:4: $effect: " "$evidence_dir/effects/$effect.txt"; then
    fail "$effect: a program that names it must fail the lint, naming the file, the line and the effect"
  fi
done
[ "$failures" -ne "$before" ] || echo "PASS: every effect that waits is flagged"

# A list with a row that lacks its columns, or names a lane that does not
# exist, fails and names each row.
run_lint malformed_list --list "$fixtures/malformed_list.txt"
if [ "$lint_status" -ne 1 ] \
  || ! grep -Fq "$fixtures/malformed_list.txt:3: a program has four columns" "$evidence_dir/malformed_list.stderr" \
  || ! grep -Fq "$fixtures/malformed_list.txt:4: runs-on names" "$evidence_dir/malformed_list.stderr" \
  || ! grep -q '^FAIL: lint-lanes' "$evidence_dir/malformed_list.stderr"; then
  fail "malformed_list: a row without four columns or with an unknown lane must fail the lint, naming the row"
fi

# A wrong option, and a list beside programs, are usage errors, not passes.
run_lint usage --unknown-option
[ "$lint_status" -eq 2 ] || fail "usage: an unknown option must exit 2, not $lint_status"
run_lint usage_list --list "$fixtures/listed_sleeper.txt" "$fixtures/sleeps.bend"
[ "$lint_status" -eq 2 ] || fail "usage_list: a list and a program together must exit 2, not $lint_status"

[ "$failures" -eq 0 ] || exit 1
echo "PASS: test-lint-lanes"
