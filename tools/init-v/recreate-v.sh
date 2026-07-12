#!/usr/bin/env bash
# recreate-v.sh — rebuild the ~/v media folder on a fresh machine.
#
# WHAT IT DOES
#   Re-fetches every source video with yt-dlp, then runs the same conversion
#   pipeline that produced the current folder (webm -> mp3 @128k, cap to 1h,
#   short-rename). No zip, no cloud copy — just URLs in, ~30 GB tree out.
#
#   The result is the SAME tree (paths / names / formats), not a byte-for-byte
#   copy: YouTube re-encodes and rotates formats, so file sizes will drift.
#
# WHAT YOU MUST DO FIRST
#   Fill in every  TODO_URL  in the MANIFEST below. Those are the ambient mp3s
#   whose source URL was erased by rename-media.py (it strips the [youtube-id]).
#   Rows that already have a URL/ID are ready to go.
#
# USAGE
#   ./recreate-v.sh --check           # deps + how many URLs still missing
#   ./recreate-v.sh --dry-run         # print the plan, download nothing
#   ./recreate-v.sh                   # do it (into $HOME/v by default)
#   ./recreate-v.sh /path/to/v        # rebuild under a different root
#   BITRATE=192k ./recreate-v.sh      # override audio bitrate (default 128k)
#
# DEPENDENCIES
#   yt-dlp, ffmpeg, ffprobe   (ffmpeg/ffprobe usually ship together)

set -euo pipefail

# ---------------------------------------------------------------------------
# MANIFEST — one row per file in the folder.
#   URL_or_ID | DEST_DIR (relative to root) | MODE | FINAL_NAME (optional)
#
#   MODE:
#     keep   download best video/audio, leave yt-dlp's "Title [id].ext" name
#            (or rename to FINAL_NAME if given)
#     mp3    download, convert to mp3 @ $BITRATE, cap to 1h, save as FINAL_NAME
#
#   Put "TODO_URL" where a source is unknown — --check counts these, and the
#   run skips them with a warning instead of failing.
# ---------------------------------------------------------------------------
MANIFEST=(
  # --- full videos, folder root (IDs still on disk — ready) ---------------
  "9YTwtIEngJI|.|keep|"
  "HV44B1JtIHM|.|keep|"
  "l18rdshGIew|.|keep|"
  "jC0w_zBQqeA|.|keep|"
  "ipf7ifVSeDU|.|keep|"
  "5LdG4FO10tk|.|keep|"
  "vxKD0lLS4mM|.|keep|"

  # --- full videos, mp4/ subdir ------------------------------------------
  "74cOUSKXMz0|mp4|keep|"
  "kCc8FmEb1nY|mp4|keep|lets-build-gpt-from-scratch.webm"   # from shell history (Karpathy)
  "TODO_URL|mp4|keep|study1.webm"                           # source unknown — fill in
  "TODO_URL|mp4|keep|study1.mp4"                            # source unknown — fill in

  # --- ambient mp3s, root ------------------------------------------------
  "nBD-4ZDWJr8|.|mp3|F_gentle_rain.mp3"                     # pp= base64 = "gentle rain"
  "TODO_URL|.|mp3|freeze.mp3"
  "TODO_URL|.|mp3|h_study.mp3"
  "TODO_URL|.|mp3|noise.mp3"
  "TODO_URL|.|mp3|rain.mp3"
  "TODO_URL|.|mp3|rain_3.mp3"
  "TODO_URL|.|mp3|techno.mp3"
  "TODO_URL|.|mp3|techno_3.mp3"
  "TODO_URL|.|mp3|underwater.mp3"
  "TODO_URL|.|mp3|water.mp3"

  # --- ambient mp3s, others/ ---------------------------------------------
  "TODO_URL|others|mp3|is_this_the.mp3"
  "TODO_URL|others|mp3|library.mp3"
  "TODO_URL|others|mp3|mountain.mp3"
  "TODO_URL|others|mp3|night_rain.mp3"
  "TODO_URL|others|mp3|night_water.mp3"
  "TODO_URL|others|mp3|powerful.mp3"
  "TODO_URL|others|mp3|quiet_night.mp3"
  "TODO_URL|others|mp3|spaceship.mp3"
  "TODO_URL|others|mp3|substation.mp3"
  "TODO_URL|others|mp3|winter_storm.mp3"

  # --- ambient mp3s, others/tmp/ -----------------------------------------
  "TODO_URL|others/tmp|mp3|building.mp3"
  "TODO_URL|others/tmp|mp3|building_2.mp3"
  "TODO_URL|others/tmp|mp3|building_4.mp3"
  "TODO_URL|others/tmp|mp3|increase.mp3"
  "TODO_URL|others/tmp|mp3|the_spelled.mp3"
  "TODO_URL|others/tmp|mp3|the_spelled_3.mp3"
)

# ---------------------------------------------------------------------------
BITRATE="${BITRATE:-128k}"
CAP_SECONDS="${CAP_SECONDS:-3600}"    # cap audio to 1 hour, like mp3-cap-1h.sh

ROOT=""
DRY_RUN=0
CHECK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --check)   CHECK_ONLY=1 ;;
    -h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)        echo "Unknown flag: $arg" >&2; exit 2 ;;
    *)         [ -n "$ROOT" ] && { echo "one path only" >&2; exit 2; }; ROOT="$arg" ;;
  esac
done
ROOT="${ROOT:-$HOME/v}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "MISSING dependency: $1" >&2; return 1; }; }
check_deps() {
  local ok=0
  need yt-dlp  || ok=1
  need ffmpeg  || ok=1
  need ffprobe || ok=1
  return $ok
}

# Count how many manifest rows still need a URL.
missing_urls() {
  local n=0 row src
  for row in "${MANIFEST[@]}"; do
    IFS='|' read -r src _ _ _ <<<"$row"
    [ "$src" = "TODO_URL" ] && n=$((n+1))
  done
  echo "$n"
}

# yt-dlp accepts a bare 11-char ID or a full URL. Normalize to a watch URL.
to_url() {
  case "$1" in
    http*) printf '%s' "$1" ;;
    *)     printf 'https://www.youtube.com/watch?v=%s' "$1" ;;
  esac
}

# keep: download into DEST with yt-dlp's default template, optionally rename.
do_keep() {
  local url="$1" dest="$2" final="$3"
  mkdir -p "$dest"
  if [ -n "$final" ]; then
    yt-dlp -o "$dest/$final" "$url"
  else
    yt-dlp -o "$dest/%(title)s [%(id)s].%(ext)s" "$url"
  fi
}

# mp3: download bestaudio, transcode to mp3 @BITRATE, cap to CAP_SECONDS,
# write atomically to $dest/$final.
do_mp3() {
  local url="$1" dest="$2" final="$3"
  mkdir -p "$dest"
  local raw tmp out; out="$dest/$final"
  raw="$(mktemp "$dest/.src.XXXXXX")"; rm -f "$raw"
  yt-dlp -f bestaudio -o "${raw}.%(ext)s" "$url"
  raw="$(ls "${raw}".* | head -n1)"
  tmp="${out}.tmp"
  # trim to the cap and (re)encode to mp3 in one pass
  ffmpeg -hide_banner -loglevel error -y -t "$CAP_SECONDS" -i "$raw" \
         -vn -c:a libmp3lame -b:a "$BITRATE" -f mp3 "$tmp"
  if [ -s "$tmp" ] && ffprobe -v error -select_streams a -show_entries stream=codec_type \
                              -of csv=p=0 "$tmp" | grep -q audio; then
    mv -f -- "$tmp" "$out"
    rm -f -- "$raw"
    echo "  ok  -> $out"
  else
    rm -f -- "$tmp" "$raw"
    echo "  FAIL output failed verification: $out" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
missing="$(missing_urls)"
total="${#MANIFEST[@]}"

if [ "$CHECK_ONLY" -eq 1 ]; then
  echo "Root:            $ROOT"
  echo "Manifest rows:   $total"
  echo "URLs missing:    $missing   (rows marked TODO_URL — fill them in)"
  echo -n "Dependencies:    "
  if check_deps; then echo "all present"; else echo "see MISSING lines above"; fi
  exit 0
fi

check_deps || { echo "Install the missing dependencies and retry." >&2; exit 1; }
[ "$missing" -gt 0 ] && echo "NOTE: $missing/$total rows still say TODO_URL — those will be skipped."

echo "Rebuilding into: $ROOT"
mkdir -p "$ROOT"

done_n=0 skip_n=0 fail_n=0
for row in "${MANIFEST[@]}"; do
  IFS='|' read -r src rel mode final <<<"$row"
  dest="$ROOT/$rel"
  label="${final:-$src}  ($rel)"

  if [ "$src" = "TODO_URL" ]; then
    echo "SKIP (no URL): $label"; skip_n=$((skip_n+1)); continue
  fi
  url="$(to_url "$src")"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "WOULD $mode: $url  ->  $dest/${final:-<title [id]>}"; done_n=$((done_n+1)); continue
  fi

  echo ">> $mode: $label"
  case "$mode" in
    keep) do_keep "$url" "$dest" "$final" && done_n=$((done_n+1)) || fail_n=$((fail_n+1)) ;;
    mp3)  do_mp3  "$url" "$dest" "$final" && done_n=$((done_n+1)) || fail_n=$((fail_n+1)) ;;
    *)    echo "  unknown mode: $mode" >&2; fail_n=$((fail_n+1)) ;;
  esac
done

echo
echo "Done:    $done_n"
echo "Skipped: $skip_n  (missing URLs)"
echo "Failed:  $fail_n"
