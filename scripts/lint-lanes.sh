#!/bin/sh
# Fail when a program that CI runs under node, or a module that it imports,
# names an effect that waits or reads the environment without a guaranteed
# value.
#
#   ./scripts/lint-lanes.sh [--packages DIR] [PROGRAM... | --list FILE]
#   ./scripts/lint-lanes.sh --base FILE
#
# Node has no bun:ffi, which Bend's JavaScript effects load when they wait or
# fail: IO.sleep, IO.within, files, sockets and an IO.get_env of an unset
# variable need it, and Process.run needs Bun.spawnSync. A program that names
# one runs on the JavaScript lane (the Bun embedded in the pinned compiler)
# and natively, never under node.
#
# A PROGRAM is a Bend file, or FILE#NAME for the code block that FILE marks
# <!-- test:NAME:start --> (scripts/doc-block.sh); paths are relative to the
# repository root. Without a PROGRAM, the lint takes the programs on the node
# lane of a list, tests/lanes/programs.txt unless --list names another: the
# list from which scripts/test-consumer.sh runs its programs, so that the
# lint and the runner share one list.
#
# The lint reads text, not Bend. It drops comments and string and character
# literals, and it names an effect where a whole word of Base's spelling
# stands (IO.sleep, not IO.sleeping or Semconv.IO.sleep). It follows each
# `import`, at any indentation: `./module.bend` and `../module.bend`, and a
# package of this repository (`bend-telemetry-<role>@VERSION/module.bend`,
# read from DIR/<role>/ of the working tree, packages/ by default). An import
# that it cannot read, or does not know, fails. What it cannot read it names
# in a `note:` and does not judge: a package of another repository or a
# package by hash, which a clean checkout does not have, and foreign code (a
# def whose body imports .c or .js files). The node job's own run covers what
# it executes.
#
# An environment read fails whatever the program does with its result: the
# effect itself fails inside node when the variable is unset. Only a variable
# that every node run sets is safe, and a comment on the line states who sets
# it: `# lanes: guaranteed by the node job, which exports NAME`. The lint takes
# that comment at its word, for review to check; it covers an environment
# read and no other effect.
#
# The names are the effects of Base in the pinned compiler. `--base FILE`
# checks them against FILE, the output of `./bend base`: every effect of Base
# (a def whose body imports ./effs/ files) and every def built on one that
# waits (IO.within is) must be flagged by the lint or reviewed and left alone
# (printing, the command line, entropy, spawn and channels, the thread count,
# the clock, and the window and audio effects), and every name that it knows
# must be a def of Base. scripts/validate.sh runs it, so that a newer Bend with
# an effect that the lint has not seen fails there, and in the weekly job on
# the newest Bend, instead of passing unseen.
#
# The standard output is the transcript: `scanned: FILE` for each file read,
# `note: ...` for what it does not follow or read, `FILE:LINE: EFFECT: WHY`
# for each finding and a last PASS line; a failure ends with a FAIL line on
# the standard error and exit status 1. A usage error exits with 2.
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
usage="Usage: $0 [--packages DIR] [PROGRAM... | --list FILE] | --base FILE"
fail() {
  echo "FAIL: lint-lanes: $*" >&2
  exit 1
}
packages=packages
list=
base=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --packages)
      [ "$#" -ge 2 ] || { echo "$usage" >&2; exit 2; }
      packages=$2
      shift 2
      ;;
    --list)
      [ "$#" -ge 2 ] || { echo "$usage" >&2; exit 2; }
      list=$2
      shift 2
      ;;
    --base)
      [ "$#" -eq 2 ] || { echo "$usage" >&2; exit 2; }
      base=$2
      shift 2
      ;;
    -*) echo "$usage" >&2; exit 2 ;;
    *) break ;;
  esac
done
# A list stands in for the programs, and has nothing to do with --base.
if [ -n "$list" ] && { [ "$#" -gt 0 ] || [ -n "$base" ]; }; then
  echo "$usage" >&2
  exit 2
fi
cd "$repo_dir"

if [ "$#" -eq 0 ] && [ -z "$base" ]; then
  [ -n "$list" ] || list=tests/lanes/programs.txt
  [ -f "$list" ] || fail "no list of programs at $list"
  # The programs on the node lane: the second column of each row that runs on
  # node. A row has four columns, and the last names lanes that exist.
  # shellcheck disable=SC2016 # $1, $2 and $4 belong to awk, not the shell.
  programs=$(awk -v list="$list" '
    $1 ~ /^#/ || NF == 0 { next }
    { rows++ }
    NF != 4 {
      print list ":" FNR ": a program has four columns: name, program, expected, runs-on" > "/dev/stderr"
      bad = 1
      next
    }
    {
      n = split($4, lane, ",")
      node = 0
      unknown = 0
      for (i = 1; i <= n; i++) {
        if (lane[i] == "node") node = 1
        else if (lane[i] != "native" && lane[i] != "javascript") unknown = 1
      }
      if (unknown) {
        print list ":" FNR ": runs-on names native, javascript and node, separated by commas" > "/dev/stderr"
        bad = 1
        next
      }
      if (node) print $2
    }
    END {
      if (rows == 0) {
        print list ": no program" > "/dev/stderr"
        bad = 1
      }
      exit bad
    }
  ' "$list") || fail "$list is not a list of programs"
  # The paths of the list hold no white space or glob characters.
  # shellcheck disable=SC2086
  set -- $programs
fi

# shellcheck disable=SC2016 # The program is awk's, not the shell's; it holds
# no single quote, which is written \047.
awk -v packages="$packages" -v base="$base" '
# What each effect that waits is, and why node cannot run it.
function declare(names, why,    n, list, i) {
  n = split(names, list, " ")
  for (i = 1; i <= n; i++) {
    effects[++neffects] = list[i]
    reason[list[i]] = why
  }
}

# The effects that the lint has reviewed and does not flag.
function review(names,    n, list, i) {
  n = split(names, list, " ")
  for (i = 1; i <= n; i++) {
    reviews[++nreviews] = list[i]
    reviewed[list[i]] = 1
  }
}

function report(message) {
  print message
  findings++
}

function dirname(path,    n, parts, i, dir) {
  n = split(path, parts, "/")
  if (n == 1) return "."
  dir = parts[1]
  for (i = 2; i < n; i++) dir = dir "/" parts[i]
  return dir == "" ? "/" : dir
}

# The path without "." and ".." segments or doubled slashes.
function normalize(path,    absolute, n, parts, i, top, stack, out) {
  absolute = substr(path, 1, 1) == "/"
  n = split(path, parts, "/")
  top = 0
  for (i = 1; i <= n; i++) {
    if (parts[i] == "" || parts[i] == ".") continue
    if (parts[i] == ".." && top > 0 && stack[top] != "..") { top--; continue }
    if (parts[i] == ".." && absolute) continue
    stack[++top] = parts[i]
  }
  out = absolute ? "/" : ""
  for (i = 1; i <= top; i++) out = out (i > 1 ? "/" : "") stack[i]
  return out == "" ? "." : out
}

function readable(file,    probe, rc) {
  rc = (getline probe < (file))
  close(file)
  return rc >= 0
}

# Queue a file to scan: a listed program (at is empty) or an import (at is the
# file:line that names it, and an import that cannot be read is a finding
# there). A file is scanned once, for the first program that reaches it.
function enqueue(file, block, root, at, target,    key) {
  key = file "#" block
  if (key in queued) return
  if (at != "" && !readable(file)) {
    report(at ": import " target ": cannot read " file)
    return
  }
  queued[key] = 1
  nqueue++
  qfile[nqueue] = file      # the file to read
  qblock[nqueue] = block    # the code block of a document, empty for a file
  qroot[nqueue] = root      # the listed program that reached it
  qat[nqueue] = at          # where it was imported, empty for a listed program
}

function note_unfollowed(target, what, at) {
  if (target in noted) return
  noted[target] = 1
  print "note: not followed: " target " (" what "), imported at " at
}

# The line without comments and without the contents of string and character
# literals; the text of its comment is left in `comment`. A string may span
# lines, so whether one is open at the end of a line is kept in `instring`.
function strip(line,    n, i, c, out) {
  comment = ""
  out = ""
  n = length(line)
  i = 1
  while (i <= n) {
    c = substr(line, i, 1)
    i++
    if (instring) {
      if (c == "\\") i++
      else if (c == "\"") { instring = 0; out = out " " }
    } else if (c == "#") {
      comment = substr(line, i)
      break
    } else if (c == "\"") {
      instring = 1
    } else if (c == "\047") {
      while (i <= n && substr(line, i, 1) != "\047") i += (substr(line, i, 1) == "\\" ? 2 : 1)
      i++
      out = out " "
    } else {
      out = out c
    }
  }
  return out
}

# An import, at any indentation: queue what the lint follows.
function follow(code, file, ln, root,    f, target, at, pkg, slash, mark) {
  split(code, f, " ")
  target = f[2]
  at = file ":" ln
  if (target == "Base") return
  if (substr(target, 1, 2) == "./" || substr(target, 1, 3) == "../") {
    enqueue(normalize(dirname(file) "/" target), "", root, at, target)
    return
  }
  mark = index(target, "@")
  slash = index(target, "/")
  if (mark > 0 && slash > mark) {
    pkg = substr(target, 1, mark - 1)
    if (substr(pkg, 1, 15) == "bend-telemetry-") {
      enqueue(normalize(packages "/" substr(pkg, 16) "/" substr(target, slash + 1)), "", root, at, target)
    } else {
      note_unfollowed(target, "a package of another repository", at)
    }
    return
  }
  if (substr(target, 1, 2) == "0x" && slash > 0) {
    note_unfollowed(target, "a package by hash", at)
    return
  }
  report(at ": import " target ": not a form of import that the lint follows")
}

# A line of a program: an import to follow, foreign code to name, or the words
# that name an effect that waits, left to right.
function examine(line, file, ln, imported, root,    code, rest, token, guaranteed) {
  if (!instring && line ~ /^[ \t]*import[ \t]+"/) {
    sub(/^[ \t]+/, "", line)
    print "note: not read: " file ":" ln ": foreign code: " line
    return
  }
  code = strip(line)
  if (code ~ /^[ \t]*import[ \t]/) {
    follow(code, file, ln, root)
    return
  }
  guaranteed = comment ~ /^[ \t]*lanes:[ \t]*guaranteed by[ \t]+[^ \t]/
  rest = code
  while (match(rest, /[A-Za-z0-9_.]+/)) {
    token = substr(rest, RSTART, RLENGTH)
    rest = substr(rest, RSTART + RLENGTH)
    if (token in reason && !(token == "IO.get_env" && guaranteed)) {
      report(file ":" ln ": " token ": " reason[token] (imported ? " (reached from " root ")" : ""))
    }
  }
}

function scan(k,    file, block, shown, line, ln, rc, inblock, found, start, stop) {
  file = qfile[k]
  block = qblock[k]
  shown = block == "" ? file : file "#" block
  rc = (getline line < (file))
  if (rc < 0) {
    report(shown ": cannot read the program")
    return
  }
  start = "<!-- test:" block ":start -->"
  stop = "<!-- test:" block ":end -->"
  found = block == ""
  inblock = found
  if (found) {
    print "scanned: " shown
    nfiles++
  }
  ln = 0
  instring = 0
  while (rc > 0) {
    ln++
    if (block == "") {
      examine(line, file, ln, qat[k] != "", qroot[k])
    } else if (line == start) {
      inblock = 1
      instring = 0
      if (!found) {
        found = 1
        print "scanned: " shown
        nfiles++
      }
    } else if (line == stop) {
      inblock = 0
    } else if (inblock) {
      examine(line, file, ln, 0, qroot[k])
    }
    rc = (getline line < (file))
  }
  close(file)
  if (!found) report(shown ": no code block marked test:" block)
}

# Whether a line of the text of Base starts a top-level item. An indented
# line, a comment and a blank line do not, and neither does a line that opens
# with a closing bracket: it ends the parameter list that a def wraps.
function starts_item(line,    c) {
  c = substr(line, 1, 1)
  return c != "" && c != " " && c != "\t" && c != "#" && c != ")" && c != "]" && c != "}"
}

# The effects of Base, from the text that `bend base` prints: the defs whose
# bodies import ./effs/ files, and the defs whose bodies name an effect that
# waits. The lint must flag each or have reviewed it; and each name that it
# flags or has reviewed must still be a def of Base, so that a rename does not
# leave a name that flags nothing.
function check_base(file,    line, name, ln, rc, k, effect_at, found, nfound, built_on, built_at, built, nbuilt, rest, token) {
  rc = (getline line < (file))
  if (rc < 0) report(file ": cannot read the text of Base")
  ln = 0
  name = ""
  instring = 0
  while (rc > 0) {
    ln++
    if (starts_item(line)) {
      name = ""
      if (line ~ /^(@unsafe )?def /) {
        sub(/^(@unsafe )?def /, "", line)
        sub(/[(:?].*$/, "", line)
        name = line
        defined[name] = 1
      }
    } else if (name != "" && line ~ /^[ \t]+import "\.\/effs\//) {
      if (!(name in effect_at)) {
        effect_at[name] = ln
        found[++nfound] = name
      }
    } else if (name != "" && line ~ /^[ \t]/) {
      rest = strip(line)
      while (match(rest, /[A-Za-z0-9_.]+/)) {
        token = substr(rest, RSTART, RLENGTH)
        rest = substr(rest, RSTART + RLENGTH)
        if (token in reason && !(name in built_on)) {
          built_on[name] = token
          built_at[name] = ln
          built[++nbuilt] = name
        }
      }
    }
    rc = (getline line < (file))
  }
  close(file)
  if (rc >= 0 && nfound == 0) report(file ": no effect of Base found: is this the output of bend base?")
  for (k = 1; k <= nfound; k++) {
    name = found[k]
    if (!(name in reason) && !(name in reviewed)) {
      report(file ":" effect_at[name] ": " name ": an effect of Base that scripts/lint-lanes.sh neither flags nor has reviewed")
    }
  }
  for (k = 1; nfound > 0 && k <= nbuilt; k++) {
    name = built[k]
    if (!(name in reason) && !(name in reviewed)) {
      report(file ":" built_at[name] ": " name ": a def of Base built on " built_on[name] " that scripts/lint-lanes.sh neither flags nor has reviewed")
    }
  }
  for (k = 1; nfound > 0 && k <= neffects; k++) {
    if (!(effects[k] in defined)) report("scripts/lint-lanes.sh: " effects[k] ": flagged, but Base has no def of that name")
  }
  for (k = 1; nfound > 0 && k <= nreviews; k++) {
    if (!(reviews[k] in defined)) report("scripts/lint-lanes.sh: " reviews[k] ": reviewed, but Base has no def of that name")
  }
  if (findings > 0) {
    fflush()
    printf "FAIL: lint-lanes --base (findings %d)\n", findings > "/dev/stderr"
    exit 1
  }
  print "PASS: lint-lanes --base (effects " nfound ", flagged " neffects ", reviewed " nreviews ")"
  exit 0
}

BEGIN {
  declare("IO.sleep IO.within", "waits on the clock: it loads bun:ffi, which only Bun has")
  declare("File.open File.read File.read_bytes File.read_at File.size File.write File.write_bytes File.close", "uses a file: its reads and its failures load bun:ffi, which only Bun has")
  declare("TCP.listen TCP.accept TCP.connect TCP.send TCP.recv TCP.send_bytes TCP.recv_bytes TCP.poll UDP.bind UDP.send_to UDP.recv_from UDP.poll Socket.close Listener.close", "uses a socket: it loads bun:ffi, which only Bun has")
  declare("Process.run", "starts a process: it needs Bun.spawnSync, which only Bun has")
  declare("IO.get_env", "reads the environment without a guaranteed value: an unset variable loads bun:ffi, which only Bun has (a comment \"# lanes: guaranteed by WHO\" on the line states a guarantee)")
  review("IO.print IO.write IO.print_err IO.args IO.random_u32 IO.spawn IO.now IO.thread_count Chan.new Chan.send Chan.recv Chan.close Window.open Window.frame Window.set_title Window.grab Window.close Audio.open Audio.write Audio.close")
  if (base != "") check_base(base)

  for (i = 1; i < ARGC; i++) {
    hash = index(ARGV[i], "#")
    file = hash > 0 ? substr(ARGV[i], 1, hash - 1) : ARGV[i]
    block = hash > 0 ? substr(ARGV[i], hash + 1) : ""
    root = block == "" ? normalize(file) : normalize(file) "#" block
    enqueue(normalize(file), block, root, "", "")
  }
  programs = nqueue
  for (head = 1; head <= nqueue; head++) scan(head)

  if (findings > 0) {
    fflush()
    printf "FAIL: lint-lanes (findings %d, programs %d, files %d)\n", findings, programs, nfiles > "/dev/stderr"
    exit 1
  }
  print "PASS: lint-lanes (programs " programs ", files " nfiles ")"
  exit 0
}
' "$@"
