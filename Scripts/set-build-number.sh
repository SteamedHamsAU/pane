#!/bin/bash
set -euo pipefail
# Sets CFBundleVersion in the built app's Info.plist to YYMMDD.HHMM.SHA format
# Runs as a post-build script so it overwrites the $(CURRENT_PROJECT_VERSION) placeholder.
BUILT_PLIST="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"
BUILD_NUMBER=$(date +"%y%m%d.%H%M")
SHORT_SHA=$(git -C "${SRCROOT}" rev-parse --short HEAD 2>/dev/null || echo "unknown")
FULL_BUILD="${BUILD_NUMBER}.${SHORT_SHA}"
if ! /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${FULL_BUILD}" "${BUILT_PLIST}"; then
  echo "Failed to set CFBundleVersion in ${BUILT_PLIST}" >&2
  exit 1
fi
echo "Build number set to ${FULL_BUILD}"
