#!/bin/sh
# Print one field of a package manifest (a package.json under packages/):
#
#   scripts/manifest-field.sh FIELD MANIFEST
#
# FIELD is a dotted path such as name, version, license or bend.entry;
# bend.dependencies prints one `name@version` per line. A field that the
# manifest lacks is an error, so that a script never reads an empty value
# silently.
set -eu

[ "$#" -eq 2 ] || { echo "Usage: $0 FIELD MANIFEST" >&2; exit 2; }
command -v node >/dev/null || { echo "Required command: node" >&2; exit 1; }
[ -f "$2" ] || { echo "No manifest at $2." >&2; exit 1; }
# shellcheck disable=SC2016 # The script is JavaScript.
node -e '
  const [field, path] = process.argv.slice(1);
  const manifest = JSON.parse(require("fs").readFileSync(path, "utf8"));
  const value = field.split(".").reduce((at, key) => (at === undefined ? undefined : at[key]), manifest);
  if (value === undefined) {
    console.error(`${path} has no field ${field}.`);
    process.exit(1);
  }
  if (field === "bend.dependencies") {
    for (const [name, version] of Object.entries(value)) console.log(`${name}@${version}`);
  } else if (typeof value === "string") {
    console.log(value);
  } else {
    console.error(`${path}: ${field} is not a string.`);
    process.exit(1);
  }
' "$1" "$2"
