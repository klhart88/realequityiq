#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mkdir -p "$ROOT/assets/img"

ffmpeg -y -ss 5.25 \
  -i "$ROOT/assets/video/realequityiq-hero-teaser-v5.mp4" \
  -frames:v 1 -q:v 2 "$ROOT/assets/img/hero-video-poster-teaser-v5.jpg"

ffmpeg -y -ss 31.5 \
  -i "$ROOT/assets/video/realequityiq-walkthrough-full-v5.mp4" \
  -frames:v 1 -q:v 2 "$ROOT/assets/img/hero-video-poster-full-v5.jpg"

echo "Posters built."
