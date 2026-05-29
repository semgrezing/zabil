#!/bin/bash
set -euo pipefail

# Generates OTA manifest.plist for iOS Ad Hoc distribution.
# The manifest allows installing/updating the app via itms-services:// URL.
#
# Usage:
#   ./scripts/generate_ios_manifest.sh <version> <ipa_url>
#   Example: ./scripts/generate_ios_manifest.sh 1.10.0 https://api.achiemvemer.ru/releases/ios/collab_notes_1.10.0.ipa

VERSION="${1:?Usage: $0 <version> <ipa_https_url>}"
IPA_URL="${2:?Usage: $0 <version> <ipa_https_url>}"
BUNDLE_ID="com.example.collab_notes"
APP_TITLE="Совместные заметки"
OUTPUT_DIR="build/ios_release"

mkdir -p "$OUTPUT_DIR"

cat > "$OUTPUT_DIR/manifest_${VERSION}.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>items</key>
  <array>
    <dict>
      <key>assets</key>
      <array>
        <dict>
          <key>kind</key>
          <string>software-package</string>
          <key>url</key>
          <string>${IPA_URL}</string>
        </dict>
      </array>
      <key>metadata</key>
      <dict>
        <key>bundle-identifier</key>
        <string>${BUNDLE_ID}</string>
        <key>bundle-version</key>
        <string>${VERSION}</string>
        <key>kind</key>
        <string>software</string>
        <key>title</key>
        <string>${APP_TITLE}</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
PLIST

echo "Manifest created: $OUTPUT_DIR/manifest_${VERSION}.plist"
echo ""
echo "Upload to server and configure /update endpoint to return:"
echo "  { \"manifestUrl\": \"/releases/ios/manifest_${VERSION}.plist\" }"
echo ""
echo "iOS install URL:"
echo "  itms-services://?action=download-manifest&url=https://api.achiemvemer.ru/releases/ios/manifest_${VERSION}.plist"
