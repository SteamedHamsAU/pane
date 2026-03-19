#!/bin/bash
set -e

echo "→ Checking dependencies..."
brew list xcodegen &>/dev/null || brew install xcodegen
brew list swiftformat &>/dev/null || brew install swiftformat
brew list swiftlint &>/dev/null || brew install swiftlint
brew list xcbeautify &>/dev/null || brew install xcbeautify

echo "→ Generating Xcode project..."
xcodegen generate

echo "→ Opening in VSCode..."
code .

echo ""
echo "✓ Ready. Open Snap.xcodeproj in Xcode once to set your Team ID under Signing & Capabilities."
