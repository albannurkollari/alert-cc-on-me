#!/usr/bin/env bash
# Prints the release tag for HEAD on `beta` or `main`, or nothing when no commit since
# the last stable release calls for one. Conventional commits decide the bump:
# breaking change -> major, feat -> minor, fix/perf -> patch. Beta tags get -beta.N.
#
# Usage: scripts/next-version.sh beta|main
set -euo pipefail

branch=$1
case $branch in
	beta) pattern='^v[0-9]+\.[0-9]+\.[0-9]+-beta\.[0-9]+$' ;;
	main) pattern='^v[0-9]+\.[0-9]+\.[0-9]+$' ;;
	*) echo "unknown branch: $branch" >&2; exit 2 ;;
esac

# A re-run after a failed publish reuses the tag already on HEAD.
existing=$(git tag --points-at HEAD | grep -E "$pattern" | sort -V | tail -n1 || true)
if [ -n "$existing" ]; then
	echo "$existing"
	exit 0
fi

# The newest stable tag anywhere, not only one reachable from HEAD: stable tags sit on
# main's merge commits, which beta never contains.
last=$(git tag -l 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1 || true)
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

IFS=. read -r major minor patch <<<"${last#v}"
major=${major:-0} minor=${minor:-0} patch=${patch:-0}
case $bump in
	major) major=$((major + 1)) minor=0 patch=0 ;;
	minor) minor=$((minor + 1)) patch=0 ;;
	patch) patch=$((patch + 1)) ;;
esac
version="v$major.$minor.$patch"

if [ "$branch" = beta ]; then
	n=$(git tag -l "$version-beta.*" | sed 's/.*-beta\.//' | grep -E '^[0-9]+$' | sort -n | tail -n1 || true)
	version="$version-beta.$((${n:-0} + 1))"
fi
echo "$version"
