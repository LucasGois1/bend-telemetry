#!/bin/sh
# Serve the working tree's packages from a local BendHub and run a command
# against it. The hub (scripts/hub.mjs) answers the pinned compiler as
# https://hub.bend-lang.com would. Each package under packages/ is published
# to it with `--publish`, which gives it the hash a release would have, and
# named `bend-telemetry-<role>@X.Y.Z.0`, where X.Y.Z is VERSION without
# `-dev`. The packages that the working tree imports, such as
# bend-trace-context, are relayed from the real hub. The command then runs
# with BEND_HUB at the local hub, BEND_LIB at a fresh package cache and HOME
# at a scratch home whose bender.json holds a local key, so that nothing
# touches ~/.bend; when it ends, the hub stops.
#
#   ./scripts/local-hub.sh ./bend tests/consumer/main.bend
#
# LOCAL_HUB_SOURCE, when set, publishes that checkout's packages with that
# checkout's compiler instead of this one's; the consumer runner points it at
# a clean clone. LOCAL_HUB_DIR, when set, keeps the hub's store, cache and
# logs there instead of in a temporary directory removed at exit.
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
source_dir=${LOCAL_HUB_SOURCE:-$repo_dir}
[ "$#" -ge 1 ] || { echo "Usage: $0 COMMAND [ARGS...]" >&2; exit 2; }
command -v node >/dev/null || { echo "Required command: node" >&2; exit 1; }
bend="$source_dir/bend"
[ -x "$bend" ] || { echo "No bend wrapper at $bend." >&2; exit 1; }
version=$(cat "$source_dir/VERSION")
release=${version%-dev}
case "$release" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "VERSION must be X.Y.Z or X.Y.Z-dev, not '$version'." >&2; exit 1 ;;
esac
hub_version="$release.0"

if [ -n "${LOCAL_HUB_DIR:-}" ]; then
  work_dir=$LOCAL_HUB_DIR
  mkdir -p "$work_dir"
  cleanup_dir=
else
  work_dir=$(mktemp -d "${TMPDIR:-/tmp}/bend-telemetry-hub.XXXXXXXX")
  cleanup_dir=$work_dir
fi
hub_pid=
cleanup() {
  [ -z "$hub_pid" ] || kill "$hub_pid" 2>/dev/null || true
  [ -z "$cleanup_dir" ] || rm -rf "$cleanup_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM

mkdir -p "$work_dir/store" "$work_dir/lib" "$work_dir/home/.bend"
printf '{"key": "local-hub", "login": "local"}\n' > "$work_dir/home/.bend/bender.json"
: > "$work_dir/hub.log"
HUB_PORT=0 HUB_STORE="$work_dir/store" node "$repo_dir/scripts/hub.mjs" >> "$work_dir/hub.log" 2>&1 &
hub_pid=$!
tries=0
until grep -Eq '^http://127\.0\.0\.1:[0-9]+$' "$work_dir/hub.log"; do
  tries=$((tries + 1))
  if [ "$tries" -gt 100 ] || ! kill -0 "$hub_pid" 2>/dev/null; then
    echo "The local hub did not start:" >&2
    cat "$work_dir/hub.log" >&2
    exit 1
  fi
  sleep 0.1
done
local_hub=$(sed -n 1p "$work_dir/hub.log")

on_hub() {
  HOME="$work_dir/home" BEND_HUB="$local_hub" BEND_LIB="$work_dir/lib" BEND_NO_TELEMETRY=1 "$@"
}

# The packages are published in dependency order, not in the order of their
# names: a package is published once every package of this repository that
# its manifest declares is on the hub, since publishing compiles its modules
# and their imports must resolve. packages.txt lists what is published, one
# `name@version hash` per line.
: > "$work_dir/packages.txt"
total=0
for manifest in "$source_dir"/packages/*/package.json; do
  [ -f "$manifest" ] || { echo "No package manifest under $source_dir/packages." >&2; exit 1; }
  total=$((total + 1))
done
count=0
while [ "$count" -lt "$total" ]; do
  before=$count
  for manifest in "$source_dir"/packages/*/package.json; do
    package_dir=$(dirname -- "$manifest")
    name=$("$repo_dir/scripts/manifest-field.sh" name "$manifest")
    if grep -q "^$name@" "$work_dir/packages.txt"; then
      continue
    fi
    ready=1
    for dependency in $("$repo_dir/scripts/manifest-field.sh" bend.dependencies "$manifest"); do
      case "$dependency" in
        bend-telemetry-*) grep -q "^$dependency " "$work_dir/packages.txt" || ready=0 ;;
      esac
    done
    [ "$ready" -eq 1 ] || continue
    entry=$("$repo_dir/scripts/manifest-field.sh" bend.entry "$manifest")
    [ -f "$package_dir/$entry" ] || { echo "$manifest names an entry module that does not exist: $entry" >&2; exit 1; }
    if ! on_hub "$bend" "$package_dir/$entry" --publish > "$work_dir/$name.publish.stdout" 2> "$work_dir/$name.publish.stderr"; then
      echo "Publishing $name to the local hub failed:" >&2
      cat "$work_dir/$name.publish.stdout" "$work_dir/$name.publish.stderr" >&2
      exit 1
    fi
    hash=$(sed -n 1p "$work_dir/$name.publish.stdout")
    printf '%s\n' "$hash" | grep -Eq '^0x[0-9a-f]{32}$' || {
      echo "Publishing $name printed no package hash:" >&2
      cat "$work_dir/$name.publish.stdout" >&2
      exit 1
    }
    if ! on_hub "$bend" link "$name@$hub_version" "$hash" > "$work_dir/$name.link.log" 2>&1; then
      echo "Naming $name@$hub_version on the local hub failed:" >&2
      cat "$work_dir/$name.link.log" >&2
      exit 1
    fi
    printf '%s %s\n' "$name@$hub_version" "$hash" >> "$work_dir/packages.txt"
    count=$((count + 1))
  done
  if [ "$count" -eq "$before" ]; then
    echo "No package of $source_dir/packages can be published next: one depends on a package of this repository at a version this tree does not serve ($hub_version), or on a package that depends on it." >&2
    exit 1
  fi
done

on_hub "$@"
