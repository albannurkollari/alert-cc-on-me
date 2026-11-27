#!/usr/bin/env bash
# The markets the addon is published to, one markets/<label>.yml each (needs yq).
#
#   scripts/markets.sh plan <alpha|release> [label...]
#       Prints the JSON matrix of markets to publish to, e.g.
#       [{"market":"curseforge","name":"CurseForge"}], and a note per skipped market on
#       stderr. Labels naming markets (any case, e.g. CurseForge) pick those markets
#       only; with none, all of them.
#       A market is skipped when it has no such channel or its project ID isn't in the
#       .toc yet.
#   scripts/markets.sh check
#       Checks each market's config and listing requirements.
set -euo pipefail
cd "$(dirname "$0")/.."

toc=AlertCCOnMe/AlertCCOnMe.toc
markets=$(for f in markets/*.yml; do basename "$f" .yml; done)

field() { yq -r "$2 // \"\"" "markets/$1.yml"; }

plan() {
	local channel=$1
	shift
	local requested="" label market name tocid json=""
	for label in "$@"; do
		label=$(tr '[:upper:]' '[:lower:]' <<<"$label")
		if grep -qx "$label" <<<"$markets"; then requested+="$label"$'\n'; fi
	done
	if [ -z "$requested" ]; then
		requested=$markets
		echo "Markets: all (no market label)." >&2
	else
		echo "Markets: $(xargs <<<"$requested") (from labels)." >&2
	fi
	for market in $requested; do
		name=$(field "$market" .name)
		tocid=$(field "$market" '.["toc-id"]')
		if ! yq -e ".channels[] | select(. == \"$channel\")" "markets/$market.yml" >/dev/null 2>&1; then
			echo "- $name: skipped, it takes no $channel builds." >&2
		elif ! grep -qE "^## $tocid: *[^ ]" "$toc"; then
			echo "- $name: skipped, no \`## $tocid:\` line in the .toc yet." >&2
		else
			json+="{\"market\":\"$market\",\"name\":\"$name\"},"
		fi
	done
	echo "[${json%,}]"
}

errors=0
fail() {
	echo "::error::markets/$1.yml: $2"
	errors=$((errors + 1))
}

# PNG width and height from the IHDR chunk; empty when the file isn't a PNG.
png_size() {
	[ "$(od -An -tx1 -N8 "$1" | tr -d ' \n')" = 89504e470d0a1a0a ] || return 0
	od -An -tu1 -j16 -N8 "$1" | awk '{ print $1*16777216 + $2*65536 + $3*256 + $4, $5*16777216 + $6*65536 + $7*256 + $8 }'
}

check() {
	local market name file forbid width height size max count dir min
	for market in $markets; do
		name=$(field "$market" .name)
		[ -n "$name" ] || fail "$market" "no name"
		[ -n "$(field "$market" '.["toc-id"]')" ] || fail "$market" "no toc-id"
		[ -n "$(field "$market" .secret)" ] || fail "$market" "no secret"
		yq -e '(.channels | length > 0) and (.channels | all_c(. == "alpha" or . == "release"))' "markets/$market.yml" >/dev/null 2>&1 \
			|| fail "$market" "channels must list alpha and/or release"

		forbid=$(field "$market" .listing.title.forbid)
		if [ -n "$forbid" ] && grep -E '^## Title:' "$toc" | grep -qE "$forbid"; then
			fail "$market" "the .toc title matches '$forbid', which $name doesn't allow in names"
		fi

		file=$(field "$market" .listing.avatar.file)
		if [ -n "$file" ]; then
			size=$( [ -f "$file" ] && png_size "$file" || true)
			width=$(field "$market" .listing.avatar.width)
			height=$(field "$market" .listing.avatar.height)
			if [ -z "$size" ]; then
				fail "$market" "avatar $file is missing or not a PNG"
			elif [ -n "$width" ] && [ "$size" != "$width $height" ]; then
				fail "$market" "avatar $file is ${size/ /x}, $name needs ${width}x$height"
			fi
		fi

		file=$(field "$market" .listing.summary.file)
		if [ -n "$file" ]; then
			max=$(field "$market" '.listing.summary["max-sentences"]')
			if [ ! -s "$file" ]; then
				fail "$market" "summary $file is missing or empty"
			elif [ -n "$max" ] && [ "$(grep -oE '[.!?]( |$)' "$file" | wc -l)" -gt "$max" ]; then
				fail "$market" "summary $file has more than $max sentence(s)"
			fi
		fi

		file=$(field "$market" .listing.description)
		if [ -n "$file" ] && [ ! -s "$file" ]; then
			fail "$market" "description $file is missing or empty"
		fi

		dir=$(field "$market" .listing.screenshots.dir)
		if [ -n "$dir" ]; then
			min=$(field "$market" .listing.screenshots.min)
			count=$(find "$dir" -maxdepth 1 -name '*.png' 2>/dev/null | wc -l)
			[ "$count" -ge "${min:-1}" ] || fail "$market" "$dir has $count PNG screenshot(s), $name needs ${min:-1}"
		fi
	done
	if [ "$errors" -gt 0 ]; then exit 1; fi
	echo "Market requirements: $(wc -w <<<"$markets") markets OK"
}

case ${1:-} in
	plan) shift; plan "$@" ;;
	check) check ;;
	*) echo "usage: $0 plan <alpha|release> [label...] | check" >&2; exit 2 ;;
esac
