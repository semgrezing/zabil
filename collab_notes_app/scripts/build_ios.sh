#!/bin/bash
set -euo pipefail

# iOS build script for collab_notes
# Run on macOS with Xcode installed.
#
# Usage:
#   ./scripts/build_ios.sh [version]
#   Example: ./scripts/build_ios.sh 1.10.0
#
# Prerequisites:
#   1. macOS with Xcode 15+
#   2. Apple Developer account (free or paid)
#   3. ios/Runner/GoogleService-Info.plist from Firebase Console
#   4. For Ad Hoc distribution: provisioning profile with target device UDIDs

VERSION="${1:-1.10.0}"
BUILD_NUMBER="${2:-11}"
BUNDLE_ID="com.example.collab_notes"
BASE_URL="https://api.achiemvemer.ru/api/v1"
OUTPUT_DIR="build/ios_release"

echo "=== Building collab_notes iOS v${VERSION}+${BUILD_NUMBER} ==="

# Check prerequisites
if [[ "$(uname)" != "Darwin" ]]; then
  echo "ERROR: iOS builds require macOS. This script must run on a Mac."
  exit 1
fi

if ! command -v xcodebuild &>/dev/null; then
  echo "ERROR: Xcode not found. Install Xcode from the App Store."
  exit 1
fi

# Check for GoogleService-Info.plist
if [[ ! -f "ios/Runner/GoogleService-Info.plist" ]]; then
  echo "WARNING: ios/Runner/GoogleService-Info.plist not found."
  echo "Push notifications won't work without it."
  echo "Download it from https://console.firebase.google.com"
  echo ""
fi

# Clean previous build
flutter clean
flutter pub get

# Build iOS archive
echo "Building iOS archive..."
flutter build ipa \
  --build-name="$VERSION" \
  --build-number="$BUILD_NUMBER" \
  --dart-define="BASE_URL=$BASE_URL" \
  --dart-define="APP_VERSION=$VERSION" \
  --export-method=ad-hoc

# The IPA will be in build/ios/ipa/
mkdir -p "$OUTPUT_DIR"

IPA_PATH="build/ios/ipa/collab_notes.ipa"
if [[ -f "$IPA_PATH" ]]; then
  cp "$IPA_PATH" "$OUTPUT_DIR/collab_notes_${VERSION}.ipa"
  echo ""
  echo "=== Build successful ==="
  echo "IPA: $OUTPUT_DIR/collab_notes_${VERSION}.ipa"
  echo ""
  echo "Next steps:"
  echo "  1. Upload IPA to server: scp $OUTPUT_DIR/collab_notes_${VERSION}.ipa user@achiemvemer.ru:/path/to/releases/ios/"
  echo "  2. Generate manifest.plist (see scripts/generate_ios_manifest.sh)"
  echo "  3. Update /update endpoint to return iOS manifest URL"
else
  echo "ERROR: IPA not found at $IPA_PATH"
  echo "Check build/ios/archive/Runner.xcarchive for the archive."
  exit 1
fi
