#!/usr/bin/env bash
# Runs tools/generate_voices.py (see it for usage): natively when Python has piper-tts
# and ffmpeg is on PATH, otherwise in a container with both. In the container only this
# repository is mounted, so --out-dir must be inside it.
set -euo pipefail
cd "$(dirname "$0")/.."

if python3 -c "import piper" 2>/dev/null && command -v ffmpeg >/dev/null; then
	exec python3 tools/generate_voices.py "$@"
fi

image=alertcconme-piper
docker build -q -t "$image" - >/dev/null <<'EOF'
FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg \
	&& rm -rf /var/lib/apt/lists/* \
	&& pip install --no-cache-dir piper-tts==1.8.0
WORKDIR /src
EOF
# MSYS (Git Bash) would rewrite the container paths; pwd -W gives a Windows path.
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W 2>/dev/null || pwd):/src" "$image" \
	python tools/generate_voices.py "$@"
