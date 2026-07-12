#!/usr/bin/env bash
# Download one or more videos as MP3 into this script's directory.
# Usage: ./dl.sh <url> [url ...]

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -eq 0 ]; then
  echo "Usage: $(basename "$0") <url> [url ...]" >&2
  exit 1
fi

yt-dlp \
  -x --audio-format mp3 --audio-quality 0 \
  --no-update \
  -o "$DIR/%(title)s.%(ext)s" \
  "$@"
