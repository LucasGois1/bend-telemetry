#!/bin/sh
# Test the compliance check, scripts/compliance.sh, the way CI runs it:
#
#   ./scripts/test-compliance.sh
#
# The committed files must pass `--check`. Each negative case then copies the
# check and the files it reads into a scratch repository,
# build/quality/compliance-test/CASE/, breaks one thing there and expects the
# copy's `--check` to fail and to name what broke:
#
#   unclassified    the status file lacks a row of the template;
#   template_row    the vendored template gains a row: its SHA-256 is no
#                   longer the pinned one, and no status classifies the row;
#   extra_row       the status file classifies a row that the template lacks;
#   unknown_status  a row's status is not one of the specification's;
#   no_ticket       a row that is not implemented names no ticket;
#   no_reason       a row that does not apply gives no reason;
#   revision        the status file names another revision of the
#                   specification;
#   stale           a status changed and COMPLIANCE.md was not regenerated;
#   edited          COMPLIANCE.md was edited by hand.
#
# Then generation in a scratch copy reproduces the committed COMPLIANCE.md,
# generation from a status file with a problem fails and leaves COMPLIANCE.md
# as it was, and a wrong option is a usage error. The cases rewrite the row
# `- name: Create TracerProvider`, the first of the template, and add rows
# first in the Baggage section, whatever their statuses are, so that they
# hold as the status file changes. Evidence goes to
# build/quality/compliance-test/: each case's scratch repository and the
# transcript of its run, CASE.txt.
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"
check=scripts/compliance.sh
[ -f "$check" ] || { echo "No compliance check at $check." >&2; exit 1; }
template=qualification/compliance/template.yaml
status_file=qualification/compliance/bend.yaml
document=COMPLIANCE.md
evidence_dir=build/quality/compliance-test
rm -rf "$evidence_dir"
mkdir -p "$evidence_dir"
failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

# scratch CASE: a scratch repository under $evidence_dir/CASE with a copy of
# the check and of the files it reads, for the case to break.
scratch() {
  scratch_dir=$evidence_dir/$1
  mkdir -p "$scratch_dir/scripts" "$scratch_dir/qualification/compliance"
  cp "$check" scripts/compliance.mjs "$scratch_dir/scripts/"
  cp "$template" "$status_file" "$scratch_dir/qualification/compliance/"
  cp "$document" "$scratch_dir/"
}

# run CASE ARGS...: run the copy of the check in the scratch repository of
# CASE with ARGS, keep its transcript, and leave its exit status in
# run_status.
run() {
  run_case=$1
  shift
  run_status=0
  sh "$evidence_dir/$run_case/$check" "$@" > "$evidence_dir/$run_case.txt" 2>&1 || run_status=$?
}

# expect CASE TEXT...: the check of CASE fails with exit status 1, and its
# transcript holds each TEXT.
expect() {
  expect_case=$1
  shift
  run "$expect_case" --check
  before=$failures
  [ "$run_status" -eq 1 ] || fail "$expect_case: the check exited $run_status, not 1"
  for text in "$@"; do
    grep -Fq -- "$text" "$evidence_dir/$expect_case.txt" || fail "$expect_case: the transcript lacks: $text"
  done
  if [ "$failures" -ne "$before" ]; then
    cat "$evidence_dir/$expect_case.txt" >&2
  else
    echo "PASS: $expect_case"
  fi
}

# rewrite_row FILE NAME [KEY...]: FILE with the item of the row NAME holding
# the lines KEY..., such as "status: '-'", after its name in place of its own;
# with no KEY, without the row. The row must be there.
rewrite_row() {
  rewrite_file=$1
  rewrite_name=$2
  shift 2
  rewrite_keys=
  for key in "$@"; do
    rewrite_keys="$rewrite_keys$key
"
  done
  # shellcheck disable=SC2016 # $0 belongs to awk, not the shell.
  ROW_NAME=$rewrite_name ROW_KEYS=$rewrite_keys awk '
    function indent_of(line) { match(line, /^ */); return RLENGTH }
    dropping && indent_of($0) > depth { next }
    { dropping = 0 }
    !found && $0 ~ /^ *- name: / && substr($0, indent_of($0) + 9) == ENVIRON["ROW_NAME"] {
      found = 1
      dropping = 1
      depth = indent_of($0)
      if (ENVIRON["ROW_KEYS"] != "") {
        print
        count = split(ENVIRON["ROW_KEYS"], keys, "\n")
        for (i = 1; i <= count; i++) if (keys[i] != "") printf "%" (depth + 2) "s%s\n", "", keys[i]
      }
      next
    }
    { print }
    END { if (!found) exit 3 }
  ' "$rewrite_file" > "$rewrite_file.new" || { fail "$rewrite_file has no row $rewrite_name to rewrite"; return; }
  mv "$rewrite_file.new" "$rewrite_file"
}

# add_baggage_row FILE LINE...: FILE with the item LINE... first in the
# features of its Baggage section.
add_baggage_row() {
  add_file=$1
  shift
  add_lines=
  for line in "$@"; do
    add_lines="$add_lines$line
"
  done
  # shellcheck disable=SC2016 # $0 belongs to awk, not the shell.
  ROW_LINES=$add_lines awk '
    $0 == "  - name: Baggage" { section = 1 }
    { print }
    section && $0 == "    features:" { printf "%s", ENVIRON["ROW_LINES"]; section = 0; added = 1 }
    END { if (!added) exit 3 }
  ' "$add_file" > "$add_file.new" || { fail "$add_file has no Baggage section"; return; }
  mv "$add_file.new" "$add_file"
}

row='Traces > TracerProvider > Create TracerProvider'

# The committed files pass.
run_status=0
sh "$check" --check > "$evidence_dir/committed.txt" 2>&1 || run_status=$?
if [ "$run_status" -ne 0 ]; then
  fail "committed: the committed files must pass the check, which exited $run_status"
  cat "$evidence_dir/committed.txt" >&2
else
  echo "PASS: committed"
fi

scratch unclassified
rewrite_row "$evidence_dir/unclassified/$status_file" 'Create TracerProvider'
expect unclassified "$status_file does not classify the row $row of the template"

scratch template_row
add_baggage_row "$evidence_dir/template_row/$template" '      - name: A row that no status classifies'
expect template_row "FAIL: $template is not the pinned template.yaml" \
  "$status_file does not classify the row Baggage > A row that no status classifies of the template"

scratch extra_row
add_baggage_row "$evidence_dir/extra_row/$status_file" '      - name: A row that the template lacks' "        status: '+'"
expect extra_row "classifies the row Baggage > A row that the template lacks, which the template does not have"

scratch unknown_status
rewrite_row "$evidence_dir/unknown_status/$status_file" 'Create TracerProvider' "status: '?'"
expect unknown_status "$row: has the status '?', which is not one of '+', '-' and 'N/A'"

scratch no_ticket
rewrite_row "$evidence_dir/no_ticket/$status_file" 'Create TracerProvider' "status: '-'"
expect no_ticket "$row: is not implemented ('-') and names neither its ticket nor the reason it does not apply"

scratch no_reason
rewrite_row "$evidence_dir/no_reason/$status_file" 'Create TracerProvider' "status: 'N/A'"
expect no_reason "$row: does not apply ('N/A') and gives no reason"

scratch revision
sed 's/^specification: .*$/specification: v0.0.0/' "$status_file" > "$evidence_dir/revision/$status_file"
expect revision "$status_file names the specification v0.0.0"

scratch stale
rewrite_row "$evidence_dir/stale/$status_file" 'Create TracerProvider' "status: '-'" 'ticket: 999999'
expect stale "FAIL: $document differs from the document generated from $status_file"

scratch edited
printf 'A line written by hand.\n' >> "$evidence_dir/edited/$document"
expect edited "FAIL: $document differs from the document generated from $status_file"

# Generation reproduces the committed document.
scratch generate
rm "$evidence_dir/generate/$document"
run generate
if [ "$run_status" -ne 0 ]; then
  fail "generate: generation exited $run_status"
  cat "$evidence_dir/generate.txt" >&2
elif ! cmp -s "$document" "$evidence_dir/generate/$document"; then
  fail "generate: the generated $document differs from the committed one"
else
  echo "PASS: generate"
fi

# Generation from a status file with a problem fails and writes nothing.
scratch generate_refused
rewrite_row "$evidence_dir/generate_refused/$status_file" 'Create TracerProvider'
printf 'A document that generation must leave alone.\n' > "$evidence_dir/generate_refused/$document"
run generate_refused
if [ "$run_status" -ne 1 ]; then
  fail "generate_refused: generation from a status file with a problem exited $run_status, not 1"
  cat "$evidence_dir/generate_refused.txt" >&2
elif [ "$(cat "$evidence_dir/generate_refused/$document")" != 'A document that generation must leave alone.' ]; then
  fail "generate_refused: generation from a status file with a problem wrote $document"
else
  echo "PASS: generate_refused"
fi

# A wrong option, or two, is a usage error.
scratch usage
run usage --unknown-option
[ "$run_status" -eq 2 ] || fail "usage: an unknown option must exit 2, not $run_status"
run usage --check --fetch
[ "$run_status" -eq 2 ] || fail "usage: two options must exit 2, not $run_status"

[ "$failures" -eq 0 ] || exit 1
echo "PASS: test-compliance"
