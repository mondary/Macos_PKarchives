#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
MACOS_APP_DIR="${DIR}/release/macos/PKarchives.app/Contents"
CLI_RELEASE_DIR="${DIR}/release/cli"

echo "🔨 Compilation..."

swiftc "${DIR}/src/macos/PKarchives.swift" \
  -parse-as-library \
  -o PKarchives \
  -framework SwiftUI \
  -framework AppKit

mkdir -p "${MACOS_APP_DIR}/MacOS" "${MACOS_APP_DIR}/Resources" "${CLI_RELEASE_DIR}"

cp PKarchives "${MACOS_APP_DIR}/MacOS/"
cp "${DIR}/src/shared/archive.sh" "${MACOS_APP_DIR}/MacOS/"
cp "${DIR}/src/shared/archive.sh" "${MACOS_APP_DIR}/Resources/"
chmod +x "${MACOS_APP_DIR}/MacOS/"*

# --- Icône app (.icns) générée depuis icon.png ---
if [[ -f "${DIR}/icon.png" ]]; then
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "${ICONSET}"
  for sz in 16 32 128 256 512; do
    sips -z "${sz}" "${sz}" "${DIR}/icon.png" --out "${ICONSET}/icon_${sz}x${sz}.png" >/dev/null
    d=$((sz * 2))
    sips -z "${d}" "${d}" "${DIR}/icon.png" --out "${ICONSET}/icon_${sz}x${sz}@2x.png" >/dev/null
  done
  iconutil -c icns "${ICONSET}" -o "${MACOS_APP_DIR}/Resources/AppIcon.icns"
fi

cat > "${MACOS_APP_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PKarchives</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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

if command -v go >/dev/null 2>&1; then
  echo "🔨 Compilation CLI..."
  (cd "${DIR}/src/cli" && go build -o "${CLI_RELEASE_DIR}/pkarchives" .)
fi

rm -f PKarchives
echo "✅ ${DIR}/release/macos/PKarchives.app"

# --- v2 : interface moderne WKWebView ---
echo "🔨 Compilation v2 (WKWebView)..."
swiftc "${DIR}/src/macos/PKarchivesV2.swift" \
  -parse-as-library \
  -o PKarchives2 \
  -framework SwiftUI \
  -framework AppKit \
  -framework WebKit \
  -framework QuickLookThumbnailing

V2_APP_DIR="${DIR}/release/macos/PKarchives2.app/Contents"
mkdir -p "${V2_APP_DIR}/MacOS" "${V2_APP_DIR}/Resources/web"
cp PKarchives2 "${V2_APP_DIR}/MacOS/PKarchives"
cp "${DIR}/src/shared/archive.sh" "${V2_APP_DIR}/MacOS/"
cp "${DIR}/src/shared/archive.sh" "${V2_APP_DIR}/Resources/"
cp "${DIR}/src/macos/v2/web/index.html" "${DIR}/src/macos/v2/web/app.js" "${DIR}/icon.png" "${DIR}/src/macos/v2/web/logo-drive.svg" "${DIR}/src/macos/v2/web/logo-finder.png" "${V2_APP_DIR}/Resources/web/"
V2_VERSION="$(tr -d '\n' < "${DIR}/VERSION")"
sed -i '' "s/__VERSION__/${V2_VERSION}/g" "${V2_APP_DIR}/Resources/web/index.html"
chmod +x "${V2_APP_DIR}/MacOS/"*

cat > "${V2_APP_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PKarchives</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.pkarchives.app2</string>
    <key>CFBundleName</key>
    <string>PKarchives2</string>
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

if [[ -f "${MACOS_APP_DIR}/Resources/AppIcon.icns" ]]; then
  cp "${MACOS_APP_DIR}/Resources/AppIcon.icns" "${V2_APP_DIR}/Resources/AppIcon.icns"
fi

rm -f PKarchives2
echo "✅ ${DIR}/release/macos/PKarchives2.app"
