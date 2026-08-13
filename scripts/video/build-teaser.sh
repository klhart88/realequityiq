#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$ROOT/assets/video-source"
WORK="$ROOT/.video-work/teaser"
OUT="$ROOT/assets/video/realequityiq-hero-teaser-v5.mp4"

mkdir -p "$WORK" "$(dirname "$OUT")"

W=1920
H=1080
FPS=30
DUR=4.75
FADE=0.50
FRAMES=143

# --- Content-safe pre-crop for each still -----------------------------------
# The six supplied stills are not natively 16:9. Rather than the blind
# scale-to-width+center-crop from the original spec (which was verified via
# OCR to cut off real dollar values on 5 of 6 images), each still is first
# cropped to a 16:9 window at its native resolution, positioned to keep the
# values/content that matter for that specific scene. Every offset below was
# checked with OCR (pytesseract) + color-sampling against the source image
# before being locked in here.
#
#   file                          crop_top  crop_h   kept content
#   01-application-start.png        55      1262     full card (safe as-is)
#   02-results-comparison.png      199      1135     all 3 path $ figures + HIGHEST tag
#   03-single-path-results.png     200      1135     big net-worth # + composition rows
#   04-networth-breakdown.png       53      1132     total/equity/investment rows (favors top)
#   05-journey-map.png             267      1135     full promenade photo + progress panel
#   06-celebration.png             123      1135     seal, IQ number, rank name

precrop () {
  local input="$1" output="$2" crop_top="$3" crop_h="$4"
  ffmpeg -y -i "$input" -vf "crop=iw:${crop_h}:0:${crop_top}" "$output"
}

precrop "$SRC/stills/01-application-start.png"  "$WORK/pc01.png" 55  1262
precrop "$SRC/stills/02-results-comparison.png" "$WORK/pc02.png" 199 1135
precrop "$SRC/stills/03-single-path-results.png" "$WORK/pc03.png" 200 1135
precrop "$SRC/stills/04-networth-breakdown.png" "$WORK/pc04.png" 53  1132
precrop "$SRC/stills/05-journey-map.png"        "$WORK/pc05.png" 267 1135
precrop "$SRC/stills/06-celebration.png"        "$WORK/pc06.png" 123 1135

make_scene () {
  local input="$1"
  local output="$2"
  local zoom="$3"
  local xexpr="$4"
  local yexpr="$5"

  ffmpeg -y -loop 1 -i "$input" -t "$DUR" \
    -vf "scale=2200:-2:force_original_aspect_ratio=increase,crop=2200:1238,\
zoompan=z='$zoom':x='$xexpr':y='$yexpr':d=$FRAMES:s=${W}x${H}:fps=$FPS,\
format=yuv420p" \
    -an -c:v libx264 -preset slow -crf 18 -movflags +faststart "$output"
}

make_scene "$WORK/pc01.png" \
  "$WORK/01.mp4" "1+0.04*on/$FRAMES" "iw/2-(iw/zoom/2)" "ih/2-(ih/zoom/2)"

make_scene "$WORK/pc02.png" \
  "$WORK/02.mp4" "1+0.06*on/$FRAMES" "iw/2-(iw/zoom/2)" "ih/2-(ih/zoom/2)"

make_scene "$WORK/pc03.png" \
  "$WORK/03.mp4" "1.02+0.06*on/$FRAMES" "iw/2-(iw/zoom/2)" "ih/2-(ih/zoom/2)"

make_scene "$WORK/pc04.png" \
  "$WORK/04.mp4" "1+0.06*on/$FRAMES" "iw/2-(iw/zoom/2)" "ih/2-(ih/zoom/2)"

make_scene "$WORK/pc05.png" \
  "$WORK/05.mp4" "1.06-0.06*on/$FRAMES" "iw/2-(iw/zoom/2)" "ih/2-(ih/zoom/2)"

make_scene "$WORK/pc06.png" \
  "$WORK/06.mp4" "1+0.04*on/$FRAMES" "iw/2-(iw/zoom/2)" "ih/2-(ih/zoom/2)"

# Build a clean branded close on a cream background.
ffmpeg -y \
  -f lavfi -i "color=c=0xFDFBF8:s=${W}x${H}:r=${FPS}:d=${DUR}" \
  -loop 1 -i "$SRC/branding/inst-master-seal.png" \
  -loop 1 -i "$SRC/branding/rank-scholar.png" \
  -filter_complex "\
[1:v]scale=360:-1[seal];\
[2:v]scale=190:-1[rank];\
[0:v][seal]overlay=(W-w)/2-125:(H-h)/2:format=auto[tmp];\
[tmp][rank]overlay=(W-w)/2+220:(H-h)/2+55:format=auto,\
fade=t=in:st=0:d=0.45,fade=t=out:st=4.25:d=0.50,format=yuv420p[v]" \
  -map "[v]" -an -t "$DUR" -c:v libx264 -preset slow -crf 18 \
  -movflags +faststart "$WORK/07.mp4"

# Cross-dissolve all seven normalized scenes.
ffmpeg -y \
  -i "$WORK/01.mp4" -i "$WORK/02.mp4" -i "$WORK/03.mp4" \
  -i "$WORK/04.mp4" -i "$WORK/05.mp4" -i "$WORK/06.mp4" \
  -i "$WORK/07.mp4" \
  -filter_complex "\
[0:v][1:v]xfade=transition=fade:duration=$FADE:offset=4.25[v01];\
[v01][2:v]xfade=transition=fade:duration=$FADE:offset=8.50[v02];\
[v02][3:v]xfade=transition=fade:duration=$FADE:offset=12.75[v03];\
[v03][4:v]xfade=transition=fade:duration=$FADE:offset=17.00[v04];\
[v04][5:v]xfade=transition=fade:duration=$FADE:offset=21.25[v05];\
[v05][6:v]xfade=transition=fade:duration=$FADE:offset=25.50,\
format=yuv420p[v]" \
  -map "[v]" -an -r "$FPS" -c:v libx264 -profile:v high -level 4.1 \
  -preset slow -crf 18 -movflags +faststart "$OUT"

ffprobe -v error -show_entries format=duration,size \
  -show_entries stream=width,height,r_frame_rate -of default=nw=1 "$OUT"

echo "Built: $OUT"
