#!/usr/bin/env bash
set -euo pipefail

# Batch process images in a folder:
# 1) Border thickness = BORDER_PCT of narrowest side (min(w,h)), applied uniformly on all sides
# 2) Pad (no crop) to 5:4 aspect ratio using canvas extent, centered
# 3) Output folder is auto-created under input: OUTPUT_SUBDIR_NAME
# 4) Output filenames use OUTPUT_NAME_PREFIX + original name + OUTPUT_NAME_SUFFIX
#
# Usage:
#   ./image_border.sh /path/to/input [border_color] [orientation] [border_pct]
#
# Example:
#   ./image_border.sh ./in white landscape 10

IN_DIR="${1:-}"
BORDER_COLOR="${2:-white}"
ORIENTATION_LABEL="${3:-landscape}"
BORDER_PCT_ARG="${4:-10}"
BORDER_PCT="0.10"
BORDER_PCT_LABEL="10"
ASPECT_LABEL="5x4"
TARGET_RATIO="1.25"
TARGET_RATIO_INV="0.8"
OUTPUT_NAME_PREFIX=""

if [[ -z "${IN_DIR}" ]]; then
  echo "ERROR: Missing input folder."
  echo "Usage: $0 /path/to/input [border_color] [orientation] [border_pct]"
  exit 1
fi
if [[ ! -d "${IN_DIR}" ]]; then
  echo "ERROR: Input folder does not exist: ${IN_DIR}"
  exit 1
fi
case "${BORDER_PCT_ARG}" in
  *% ) BORDER_PCT_LABEL="${BORDER_PCT_ARG%%%}";;
  * ) BORDER_PCT_LABEL="${BORDER_PCT_ARG}";;
esac
if [[ "${BORDER_PCT_LABEL}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  if [[ "${BORDER_PCT_LABEL}" == *.* ]]; then
    BORDER_PCT="${BORDER_PCT_LABEL}"
    BORDER_PCT_LABEL="$(awk "BEGIN{printf \"%.0f\", ${BORDER_PCT_LABEL} * 100}")"
  else
    BORDER_PCT="$(awk "BEGIN{printf \"%.4f\", ${BORDER_PCT_LABEL} / 100}")"
  fi
else
  echo "ERROR: border_pct must be a number like 10, 10%, or 0.10."
  exit 1
fi
if [[ "${ORIENTATION_LABEL}" == "portrait" ]]; then
  ASPECT_LABEL="4x5"
  TARGET_RATIO="0.8"
  TARGET_RATIO_INV="1.25"
fi
if [[ "${ORIENTATION_LABEL}" != "landscape" && "${ORIENTATION_LABEL}" != "portrait" ]]; then
  echo "ERROR: Orientation must be 'landscape' or 'portrait'."
  exit 1
fi

OUTPUT_SUBDIR_NAME="processed_${ASPECT_LABEL}_${ORIENTATION_LABEL}_border${BORDER_PCT_LABEL}"
OUTPUT_NAME_SUFFIX="_${ASPECT_LABEL}_${ORIENTATION_LABEL}_border${BORDER_PCT_LABEL}"

OUT_DIR="${IN_DIR%/}/${OUTPUT_SUBDIR_NAME}"
mkdir -p "${OUT_DIR}"

# Require ImageMagick 7 `magick`.
IM_BIN="magick"
IDENT_BIN="magick identify"
if ! command -v magick >/dev/null 2>&1; then
  echo "ERROR: ImageMagick 7 not found. Install via Homebrew: brew install imagemagick"
  echo "Then verify: magick -version"
  exit 1
fi

# Print versions to help debugging
echo "Using: ${IM_BIN}"
${IM_BIN} -version | head -n 1 || true

# Process only common raster formats (add more if needed).
# Non-recursive: top-level of IN_DIR only.
shopt -s nullglob
files=(
  "${IN_DIR%/}"/*.jpg  "${IN_DIR%/}"/*.JPG
  "${IN_DIR%/}"/*.jpeg "${IN_DIR%/}"/*.JPEG
  "${IN_DIR%/}"/*.png  "${IN_DIR%/}"/*.PNG
  "${IN_DIR%/}"/*.tif  "${IN_DIR%/}"/*.TIF
  "${IN_DIR%/}"/*.tiff "${IN_DIR%/}"/*.TIFF
  "${IN_DIR%/}"/*.webp "${IN_DIR%/}"/*.WEBP
)

if (( ${#files[@]} == 0 )); then
  echo "No matching images found in: ${IN_DIR}"
  exit 0
fi

process_one() {
  local f="$1"
  local base name ext out
  base="$(basename "$f")"
  name="${base%.*}"
  ext="${base##*.}"
  out="${OUT_DIR%/}/${OUTPUT_NAME_PREFIX}${name}${OUTPUT_NAME_SUFFIX}.${ext}"

  # Optional sanity check: can ImageMagick read the file?
  if ! ${IDENT_BIN} -format "%w %h" "$f" >/dev/null 2>&1; then
    echo "SKIP (unreadable by ImageMagick): $f"
    return 0
  fi

  # NOTE: Use floating constants for ratios to avoid integer division issues.
  # Border thickness B = round(0.10 * min(w,h)).
  ${IM_BIN} "$f" \
    -set option:B "%[fx:round(${BORDER_PCT}*min(w,h))]" \
    -bordercolor "${BORDER_COLOR}" -border "%[option:B]x%[option:B]" \
    -background "${BORDER_COLOR}" -gravity center \
    -set option:TW "%[fx:(w/h > ${TARGET_RATIO}) ? w : ceil(h*${TARGET_RATIO})]" \
    -set option:TH "%[fx:(w/h > ${TARGET_RATIO}) ? ceil(w*${TARGET_RATIO_INV}) : h]" \
    -extent "%[option:TW]x%[option:TH]" \
    "$out"

  echo "Wrote: $out"
}

# Better error context
trap 'echo "ERROR while processing: ${current_file:-unknown}" >&2' ERR

for f in "${files[@]}"; do
  current_file="$f"
  echo "Processing: $f"
  process_one "$f"
done

echo "Done. Output folder: ${OUT_DIR}"
