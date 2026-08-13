#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$ROOT/assets/video-source/segments"
WORK="$ROOT/.video-work/walkthrough"
OUT="$ROOT/assets/video/realequityiq-walkthrough-full-v5.mp4"

mkdir -p "$WORK" "$(dirname "$OUT")"

FPS=30
W=1920
H=1080
XFADE=0.35

# Corrected crop: the original spec (2940:1654:0:129) only removes 129px from
# the top of the 2940x1912 recordings, but the browser chrome (tabs + address
# bar + bookmarks) on this exact footage doesn't fully clear until ~y=290 --
# verified by rendering the original crop and finding bookmark-bar icons
# still visible in the top ~100px of the output. A full-width crop can't
# reach y=290 and still hit a clean 1654-tall 16:9 window within the 1912px
# source, so width is trimmed slightly instead (2940 -> 2884, ~1% each side,
# well clear of the actual content bounds at x=707-2225) to make room.
CROP_W=2884
CROP_H=1622
CROP_X=28
CROP_Y=290

normalize () {
  local input="$1" start="$2" end="$3" target="$4" output="$5"
  local source_dur
  source_dur=$(awk -v s="$start" -v e="$end" 'BEGIN {print e-s}')
  local speed
  speed=$(awk -v s="$source_dur" -v t="$target" 'BEGIN {print s/t}')

  ffmpeg -y -ss "$start" -to "$end" -i "$input" \
    -filter_complex "\
[0:v]crop=${CROP_W}:${CROP_H}:${CROP_X}:${CROP_Y},scale=${W}:${H}:flags=lanczos,\
fps=${FPS},setpts=PTS/$speed,format=yuv420p[v];\
[0:a]asetpts=PTS-STARTPTS,atempo=$speed,\
aresample=async=1:first_pts=0[a]" \
    -map "[v]" -map "[a]" -t "$target" \
    -c:v libx264 -preset slow -crf 18 -profile:v high -level 4.1 \
    -c:a aac -b:a 160k -ar 48000 -movflags +faststart "$output"
}

normalize "$SRC/01-county-select.mp4" 0.80 17.80 7.0 "$WORK/01.mp4"
normalize "$SRC/02-financial-profile.mp4" 0.60 15.60 8.0 "$WORK/02.mp4"
normalize "$SRC/03-choose-scenario.mp4" 0.50 13.90 8.0 "$WORK/03.mp4"
normalize "$SRC/04-results-single.mp4" 0.80 18.40 9.0 "$WORK/04.mp4"
normalize "$SRC/05-results-compare.mp4" 0.80 29.30 11.0 "$WORK/05.mp4"
normalize "$SRC/06-commit-path.mp4" 0.60 16.60 8.0 "$WORK/06.mp4"
normalize "$SRC/07-environment.mp4" 0.80 26.70 9.0 "$WORK/07.mp4"
normalize "$SRC/08-celebration.mp4" 0.80 34.30 12.0 "$WORK/08.mp4"

# Offsets are cumulative target durations minus prior crossfades.
ffmpeg -y \
  -i "$WORK/01.mp4" -i "$WORK/02.mp4" -i "$WORK/03.mp4" -i "$WORK/04.mp4" \
  -i "$WORK/05.mp4" -i "$WORK/06.mp4" -i "$WORK/07.mp4" -i "$WORK/08.mp4" \
  -filter_complex "\
[0:v][1:v]xfade=transition=fade:duration=$XFADE:offset=6.65[v01];\
[0:a][1:a]acrossfade=d=$XFADE[a01];\
[v01][2:v]xfade=transition=fade:duration=$XFADE:offset=14.30[v02];\
[a01][2:a]acrossfade=d=$XFADE[a02];\
[v02][3:v]xfade=transition=fade:duration=$XFADE:offset=21.95[v03];\
[a02][3:a]acrossfade=d=$XFADE[a03];\
[v03][4:v]xfade=transition=fade:duration=$XFADE:offset=30.60[v04];\
[a03][4:a]acrossfade=d=$XFADE[a04];\
[v04][5:v]xfade=transition=fade:duration=$XFADE:offset=41.25[v05];\
[a04][5:a]acrossfade=d=$XFADE[a05];\
[v05][6:v]xfade=transition=fade:duration=$XFADE:offset=48.90[v06];\
[a05][6:a]acrossfade=d=$XFADE[a06];\
[v06][7:v]xfade=transition=fade:duration=$XFADE:offset=57.55,format=yuv420p[v];\
[a06][7:a]acrossfade=d=$XFADE[a]" \
  -map "[v]" -map "[a]" -r "$FPS" \
  -c:v libx264 -preset slow -crf 18 -profile:v high -level 4.1 \
  -c:a aac -b:a 160k -ar 48000 -movflags +faststart "$OUT"

ffprobe -v error -show_entries format=duration,size \
  -show_entries stream=width,height,r_frame_rate -of default=nw=1 "$OUT"

echo "Built: $OUT"
