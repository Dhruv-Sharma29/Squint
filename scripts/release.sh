#!/bin/bash
# Releases Squint: scripts/release.sh 0.3.0
#
# 1. Checks main is clean, in step with GitHub, and passed CI.
# 2. Sets the version in bundle.sh (and the next build number), dates the changelog's Unreleased section, commits
#    and pushes, then waits for CI to pass on that commit.
# 3. Tags it vX.Y.Z and pushes the tag.
# 4. Downloads GitHub's archive of the tag twice, checks the checksums agree, and points Formula/squint.rb at it,
#    and the tap's formula too when TAP_DIR is a clone of github.com/Dhruv-Sharma29/homebrew-tap.
set -euo pipefail

version=${1:?usage: scripts/release.sh <version>, such as 0.3.0}
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must look like 0.3.0" >&2; exit 1; }
repo=Dhruv-Sharma29/Squint
cd "$(dirname "$0")/.."

[[ $(git branch --show-current) == main ]] || { echo "switch to main first" >&2; exit 1; }
[[ -z $(git status --porcelain) ]] || { echo "commit or stash your changes first" >&2; exit 1; }
git fetch --quiet origin main
[[ $(git rev-parse HEAD) == $(git rev-parse origin/main) ]] || { echo "main isn't in step with origin/main" >&2; exit 1; }
! git rev-parse --quiet --verify "refs/tags/v$version" >/dev/null || { echo "v$version already exists" >&2; exit 1; }
grep -q '^## \[Unreleased\]' CHANGELOG.md || { echo "CHANGELOG.md has no Unreleased section" >&2; exit 1; }

# Waits for the CI run on a commit, and fails unless it passed.
ci_passes() {
    local commit=$1 conclusion=""
    for _ in $(seq 1 80); do
        conclusion=$(gh run list --repo "$repo" --workflow ci.yml --commit "$commit" --json status,conclusion \
            -q '.[0] | select(.status == "completed") | .conclusion' 2>/dev/null || true)
        [[ -n $conclusion ]] && break
        sleep 15
    done
    [[ $conclusion == success ]] || { echo "CI on ${commit:0:7}: ${conclusion:-still running}" >&2; return 1; }
}
ci_passes "$(git rev-parse HEAD)"

build=$(( $(sed -n 's/.*<key>CFBundleVersion<\/key><string>\([0-9]*\)<\/string>.*/\1/p' bundle.sh) + 1 ))
sed -i '' -e "s|<key>CFBundleShortVersionString</key><string>[^<]*</string>|<key>CFBundleShortVersionString</key><string>$version</string>|" \
          -e "s|<key>CFBundleVersion</key><string>[^<]*</string>|<key>CFBundleVersion</key><string>$build</string>|" bundle.sh
sed -i '' "s|^## \[Unreleased\]|## [$version] - $(date +%Y-%m-%d)|" CHANGELOG.md
git commit --quiet -am "Release $version"
git push --quiet origin main
ci_passes "$(git rev-parse HEAD)"

git tag "v$version"
git push --quiet origin "v$version"

# GitHub builds the archive on first request; two downloads must agree before the checksum is published.
archive="https://github.com/$repo/archive/refs/tags/v$version.tar.gz"
sums=()
for _ in 1 2; do
    sleep 3
    sums+=("$(curl -sSfL "$archive" | shasum -a 256 | cut -d' ' -f1)")
done
[[ ${sums[0]} == "${sums[1]}" ]] || { echo "checksums differ: ${sums[*]}" >&2; exit 1; }
sha=${sums[0]}

update_formula() {
    sed -i '' -e "s|url \"https://github.com/$repo/archive/refs/tags/v[^\"]*\"|url \"$archive\"|" \
              -e "s|sha256 \"[0-9a-f]*\"|sha256 \"$sha\"|" "$1"
}
update_formula Formula/squint.rb
git commit --quiet -am "Release $version in the Homebrew formula"
git push --quiet origin main
if [[ -n ${TAP_DIR:-} ]]; then
    git -C "$TAP_DIR" pull --quiet
    cp Formula/squint.rb "$TAP_DIR/Formula/squint.rb"
    git -C "$TAP_DIR" commit --quiet -am "squint $version"
    git -C "$TAP_DIR" push --quiet
fi
echo "Released $version: $archive ($sha)"
