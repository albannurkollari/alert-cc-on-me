#!/usr/bin/env bash
# Prints the next stable release tag (vX.Y.Z) for HEAD, or nothing when no commit since
# the last stable release calls for one. Conventional commits decide the bump:
# breaking change -> major, feat -> minor, fix/perf -> patch. The first stable release
# is v1.0.0: the first build players can install is a public release, not 0.x.
#
# Run on main to release, or on beta to preview what promoting it would publish.
# Usage: scripts/next-version.sh
set -euo pipefail

stable='^v[0-9]+\.[0-9]+\.[0-9]+$'

# A re-run after a failed publish reuses the tag already on HEAD.
existing=$(git tag --points-at HEAD | grep -E "$stable" | sort -V | tail -n1 || true)
if [ -n "$existing" ]; then
	echo "$existing"
	exit 0
fi

# The newest stable tag anywhere, not only one reachable from HEAD: stable tags sit on
# main's merge commits, which beta never contains.
last=$(git tag -l 'v*' | grep -E "$stable" | sort -V | tail -n1 || true)
range=${last:+$last..}HEAD

subjects=$(git log --no-merges --format=%s "$range")
bodies=$(git log --no-merges --format=%b "$range")
if grep -qE '^[a-z]+(\([^)]*\))?!:' <<<"$subjects" || grep -q '^BREAKING CHANGE' <<<"$bodies"; then
	bump="major"
elif grep -qE '^feat(\([^)]*\))?:' <<<"$subjects"; then
	bump="minor"
elif grep -qE '^(fix|perf)(\([^)]*\))?:' <<<"$subjects"; then
	bump="patch"
else
	exit 0
fi

if [ -z "$last" ]; then
	echo "v1.0.0"
	exit 0
fi

IFS=. read -r major minor patch <<<"${last#v}"
case $bump in
	major) major=$((major + 1)) minor=0 patch=0 ;;
	minor) minor=$((minor + 1)) patch=0 ;;
	patch) patch=$((patch + 1)) ;;
esac
echo "v$major.$minor.$patch"
