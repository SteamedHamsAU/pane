#!/bin/bash
# Sets CURRENT_PROJECT_VERSION to YYMMDD.HHMM format
BUILD_NUMBER=$(date +"%y%m%d.%H%M")
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "${INFOPLIST_FILE}"
echo "Build number set to ${BUILD_NUMBER}"
