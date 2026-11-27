#!/usr/bin/env bash
# Lint and test the addon and check the market listings (scripts/markets.sh): natively
# when busted, luacheck and yq are on PATH, otherwise in the Lua 5.1 container from
# tests/Dockerfile. Extra arguments go to busted (e.g. --filter zone).
# `tests/run.sh bench` runs the micro-benchmark instead.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "${1:-}" = "bench" ]; then
	script='lua5.1 tests/bench.lua'
	shift
else
	script='luacheck -q . && scripts/markets.sh check && busted "$@"'
fi

if command -v busted >/dev/null && command -v luacheck >/dev/null && command -v lua5.1 >/dev/null \
	&& command -v yq >/dev/null; then
	sh -c "$script" sh "$@"
else
	image=alertcconme-lua
	docker build -q -t "$image" -f tests/Dockerfile tests >/dev/null
	# MSYS (Git Bash) would rewrite the container paths; pwd -W gives a Windows path.
	MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W 2>/dev/null || pwd):/src" "$image" \
		sh -c "$script" sh "$@"
fi
