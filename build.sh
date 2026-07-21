#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="${DIR}/release/PKarchives.app/Contents"

echo "🔨 Compilation..."

swiftc "${DIR}/src/PKarchives.swift" \
  -parse-as-library \
  -o PKarchives \
  -framework SwiftUI \
  -framework AppKit

mkdir -p "${APP_DIR}/MacOS" "${APP_DIR}/Resources"

cp PKarchives "${APP_DIR}/MacOS/"
cp "${DIR}/src/archive.sh" "${APP_DIR}/MacOS/"
cp "${DIR}/src/archive.sh" "${APP_DIR}/Resources/"
chmod +x "${APP_DIR}/MacOS/"*

cat > "${APP_DIR}/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PKarchives</string>
    <key>CFBundleIdentifier</key>
    <string>com.pkarchives.app</string>
    <key>CFBundleName</key>
    <string>PKarchives</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$(cat "${DIR}/VERSION")</string>
    <key>CFBundleVersion</key>
    <string>$(cat "${DIR}/VERSION")</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
</dict>
</plist>
EOF

rm -f PKarchives
echo "✅ ${DIR}/release/PKarchives.app"
