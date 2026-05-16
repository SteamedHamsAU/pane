#!/bin/bash
# Generate Snap social media preview PNG from SVG source
# Usage: ./Scripts/generate-social-preview.sh
set -euo pipefail

cd "$(dirname "$0")/.."

SVG="branding/social-preview.svg"
PNG="branding/social-preview.png"

if ! command -v rsvg-convert &>/dev/null; then
  echo "rsvg-convert not found. Install with: brew install librsvg"
  exit 1
fi

rsvg-convert "$SVG" -o "$PNG" -w 1280 -h 640
echo "✅ Generated $PNG ($(sips -g pixelWidth -g pixelHeight "$PNG" 2>/dev/null | grep pixel | awk '{print $2}' | paste -sd'×' -))"
echo ""
echo "Upload at: https://github.com/SteamedHamsAU/snap/settings"
echo "  → Social preview → Edit → Upload $PNG"
