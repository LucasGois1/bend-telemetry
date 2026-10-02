#!/bin/sh
# Run the pinned compiler installed by scripts/setup-bend.sh.
set -eu
repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# The release that setup-bend.sh pins and installs.
version=$(sed -n 's/^version=//p' "$repo_dir/scripts/setup-bend.sh")
compiler="$repo_dir/.tools/bend-$version/bin/bend"
if [ -z "$version" ] || [ ! -x "$compiler" ]; then
  echo "Bend ${version:-?} is not installed. Run: $repo_dir/scripts/setup-bend.sh" >&2
  exit 1
fi
export BEND_NO_TELEMETRY=1
exec "$compiler" "$@"
