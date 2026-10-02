#!/bin/sh
# Try a Bend release other than the pinned one, in this checkout only. The
# script pins it in scripts/setup-bend.sh as a move to it would, with its
# version, release commit and the SHA-256 of each archive from GitHub's
# release metadata; installs it, which verifies the archive; and commits the
# result locally. Every gate tests a commit, so each then runs on that
# release. Nothing is pushed. Without an argument, it tries the newest
# release of bendlang/bend; when that is the pinned release, it only installs
# it. GITHUB_TOKEN, when set, authenticates the metadata requests.
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
usage="Usage: $0 [X.Y.Z]"
[ "$#" -le 1 ] || { echo "$usage" >&2; exit 2; }
requested=${1:-}
case "$requested" in
  '') ;;
  *[!0-9.]*) echo "$usage" >&2; exit 2 ;;
esac
[ -z "$(git -C "$repo_dir" status --porcelain)" ] || {
  echo "try-bend.sh commits the pin, so it needs a checkout without changes." >&2
  exit 1
}
pin="$repo_dir/scripts/setup-bend.sh"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/bend-try.XXXXXXXX")
trap 'rm -rf "$work_dir"' EXIT

# The release's version, commit and archive digests, each checked for its
# form before the shell reads it.
# shellcheck disable=SC2016 # The script is JavaScript.
node -e '
  const requested = process.argv[1];
  const api = "https://api.github.com/repos/bendlang/bend";
  const headers = { accept: "application/vnd.github+json", "user-agent": "bend-telemetry try-bend" };
  if (process.env.GITHUB_TOKEN) headers.authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
  const get = async (path) => {
    const answer = await fetch(api + path, { headers });
    if (!answer.ok) throw new Error(`${api}${path} answered ${answer.status}`);
    return answer.json();
  };
  (async () => {
    const release = await get(requested === "" ? "/releases/latest" : `/releases/tags/v${requested}`);
    const version = String(release.tag_name).replace(/^v/, "");
    let ref = (await get(`/git/ref/tags/v${version}`)).object;
    if (ref.type === "tag") ref = (await get(`/git/tags/${ref.sha}`)).object;
    const digest = (platform) => {
      const asset = release.assets.find((item) => item.name === `bend-${version}-${platform}.tar.gz`);
      return String(asset?.digest ?? "").replace(/^sha256:/, "");
    };
    const values = { version, commit: ref.sha, darwin: digest("darwin-arm64"), linux: digest("linux-x64") };
    const forms = { version: /^\d+\.\d+\.\d+$/, commit: /^[0-9a-f]{40}$/, darwin: /^[0-9a-f]{64}$/, linux: /^[0-9a-f]{64}$/ };
    for (const [key, form] of Object.entries(forms)) {
      if (!form.test(values[key])) throw new Error(`release ${version} has no valid ${key}: ${values[key]}`);
    }
    console.log(Object.values(values).join(" "));
  })().catch((error) => { console.error(String(error)); process.exit(1); });
' "$requested" > "$work_dir/release"
read -r version commit darwin linux < "$work_dir/release"
pinned=$(sed -n 's/^version=//p' "$pin")
if [ "$version" = "$pinned" ]; then
  # The gates then run on the pinned release, which must be installed too.
  echo "Bend $version is the pinned release already."
  "$repo_dir/scripts/setup-bend.sh"
  exit 0
fi

sed -e "s/^version=.*/version=$version/" \
  -e "s/^release_commit=.*/release_commit=$commit/" \
  -e "s|^# https://github.com/bendlang/bend/releases/tag/v.*|# https://github.com/bendlang/bend/releases/tag/v$version|" \
  -e '/platform=darwin-arm64/{' -e 'n' -e "s/digest=[0-9a-f]*/digest=$darwin/" -e '}' \
  -e '/platform=linux-x64/{' -e 'n' -e "s/digest=[0-9a-f]*/digest=$linux/" -e '}' \
  "$pin" > "$work_dir/setup-bend.sh"
for value in "version=$version" "release_commit=$commit" "digest=$darwin" "digest=$linux"; do
  grep -Fq "$value" "$work_dir/setup-bend.sh" || { echo "Could not pin $value in $pin." >&2; exit 1; }
done
cat "$work_dir/setup-bend.sh" > "$pin"
"$repo_dir/scripts/setup-bend.sh"
git -C "$repo_dir" add -A
git -C "$repo_dir" -c user.name=try-bend -c user.email=try-bend@localhost \
  commit --quiet -m "Try Bend $version, pinned in this checkout only"
echo "Trying Bend $version ($commit), in place of $pinned, at commit $(git -C "$repo_dir" rev-parse HEAD)."
