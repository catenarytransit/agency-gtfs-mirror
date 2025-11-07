#!/usr/bin/env bash
set -euo pipefail

# Usage: ./saskatoon.sh [output_zip]
# Example: ./saskatoon.sh gtfs.zip

OUTPUT_ZIP="${1:-gtfs.zip}"

# Check dependencies
for cmd in curl zip; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Error: '$cmd' is required but not installed." >&2
    exit 1
  }
done

# Map GTFS-standard filenames to the provided URLs
declare -A URLS=(
  [agency.txt]="https://hub.arcgis.com/api/v3/datasets/fef6cfd997f64dfabb58ea984a8b57e1_0/downloads/data?format=csv&spatialRefId=4326&where=1%3D1"
  [calendar.txt]="https://hub.arcgis.com/api/v3/datasets/62ca52c12e5f4083a941d7898fb7684b_0/downloads/data?format=csv&spatialRefId=4326&where=1%3D1"
  [routes.txt]="https://hub.arcgis.com/api/v3/datasets/7f98542548a146779a1101d47e00280d_0/downloads/data?format=csv&spatialRefId=4326&where=1%3D1"
  [shapes.txt]="https://hub.arcgis.com/api/v3/datasets/b895d9b3bf4b45f0a614af1204421e3b_0/downloads/data?format=csv&spatialRefId=4326&where=1%3D1"
  [stops.txt]="https://hub.arcgis.com/api/v3/datasets/657bed1e360b45cb8cfb21e3144244fc_0/downloads/data?format=csv&spatialRefId=4326&where=1%3D1"
  [stop_times.txt]="https://hub.arcgis.com/api/v3/datasets/780db661f1114f09850cc30748fc1403_0/downloads/data?format=csv&spatialRefId=4326&where=1%3D1"
  [trips.txt]="https://hub.arcgis.com/api/v3/datasets/7cde815acb8e4cef94df9e306ae4abc1_0/downloads/data?format=csv&spatialRefId=4326&where=1%3D1"
)

# Create a temporary working directory
WORKDIR="$(mktemp -d)"
cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

echo "Working in: $WORKDIR"

# Download each file and save with GTFS-standard name (.txt)
for fname in "${!URLS[@]}"; do
  url="${URLS[$fname]}"
  outpath="$WORKDIR/$fname"
  echo "Downloading $fname ..."
  curl -fsSL --retry 3 --retry-delay 2 "$url" -o "$outpath"
  # Remove UTF-8 BOM if present
  sed -i '1s/^\xEF\xBB\xBF//' "$outpath"
  # Normalize line endings
  if command -v dos2unix >/dev/null 2>&1; then
    dos2unix "$outpath" >/dev/null 2>&1 || true
  else
    tr -d '\r' < "$outpath" > "$outpath.tmp" && mv "$outpath.tmp" "$outpath"
  fi
done

# Build the GTFS zip (flat files at the root)
echo "Creating $OUTPUT_ZIP ..."
(
  cd "$WORKDIR"
  zip -q -j "../$OUTPUT_ZIP" *.txt
)
mv "$WORKDIR/../$OUTPUT_ZIP" "./$OUTPUT_ZIP"

echo "✅ Done: $OUTPUT_ZIP created successfully."
echo
echo "Includes:"
for f in "${!URLS[@]}"; do
  echo "  - $f"
done
