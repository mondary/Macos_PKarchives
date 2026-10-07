#!/bin/bash
set -euo pipefail



DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${DIR}/.." && pwd)"

# Version : source de vérité = dernier en-tête versionné de CHANGELOG.md
BASE_VERSION="$(sed -nE 's/^### \[([0-9]{4}\.[0-9]{2}\.[0-9]+)\].*/\1/p' "${ROOT}/CHANGELOG.md" | head -1)"
if [[ -z "${BASE_VERSION}" ]]; then
  echo "❌ Version introuvable dans CHANGELOG.md (en-tête '### [YYYY.MM.PATCH]')" >&2
  exit 1
fi
if [[ "${PK_DEV_BUILD:-0}" == "1" ]]; then
  APP_VERSION="${BASE_VERSION}-dev.$(date -u +%H%M%S)"
else
  APP_VERSION="${BASE_VERSION}"
fi
BUILD_VERSION="$(date +%s)"
echo "🔖 Version ${APP_VERSION}"

SPARKLE_VERSION="2.9.6"
SPARKLE_SHA256="52bf9e88cdd972fc0c81501377a880e90d47031bd8ca5462488f843e2609e192"
SPARKLE_DIR="${ROOT}/release/sparkle"

if [[ ! -f "${SPARKLE_DIR}/Sparkle.framework/Sparkle" || ! -x "${SPARKLE_DIR}/bin/sign_update" ]]; then
  echo "⬇️  Téléchargement Sparkle ${SPARKLE_VERSION}..."
  mkdir -p "${SPARKLE_DIR}"
  curl -sL "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz" \
    -o "${SPARKLE_DIR}/Sparkle.tar.xz"
  echo "${SPARKLE_SHA256}  ${SPARKLE_DIR}/Sparkle.tar.xz" | shasum -a 256 -c - >/dev/null
  tar xf "${SPARKLE_DIR}/Sparkle.tar.xz" -C "${SPARKLE_DIR}" ./Sparkle.framework ./bin
  rm -f "${SPARKLE_DIR}/Sparkle.tar.xz"
fi

MACOS_APP_PATH="${ROOT}/release/macos/PKarchives-v1-${APP_VERSION}.app"
MACOS_APP_DIR="${MACOS_APP_PATH}/Contents"
CLI_RELEASE_DIR="${ROOT}/release/cli"

(
  set -e
  echo "🔨 Compilation..."

  swiftc "${ROOT}/src/macos/PKarchives.swift" \
  -parse-as-library \
  -o PKarchives \
  -framework SwiftUI \
  -framework AppKit

mkdir -p "${MACOS_APP_DIR}/MacOS" "${MACOS_APP_DIR}/Resources" "${CLI_RELEASE_DIR}"

cp PKarchives "${MACOS_APP_DIR}/MacOS/"
cp "${ROOT}/src/shared/archive.sh" "${MACOS_APP_DIR}/MacOS/"
cp "${ROOT}/src/shared/archive.sh" "${MACOS_APP_DIR}/Resources/"
chmod +x "${MACOS_APP_DIR}/MacOS/"*

# --- Icône app (.icns) générée depuis icon.png ---
if [[ -f "${ROOT}/icon.png" ]]; then
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "${ICONSET}"
  for sz in 16 32 128 256 512; do
    sips -z "${sz}" "${sz}" "${ROOT}/icon.png" --out "${ICONSET}/icon_${sz}x${sz}.png" >/dev/null
    d=$((sz * 2))
    sips -z "${d}" "${d}" "${ROOT}/icon.png" --out "${ICONSET}/icon_${sz}x${sz}@2x.png" >/dev/null
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
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_VERSION}</string>
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
echo "✅ ${MACOS_APP_PATH}"
) || echo "⚠️ v1 ignorée (CLT Swift 6.4 sans plugin macro SwiftUI) — seule la v2 est générée"

if command -v go >/dev/null 2>&1; then
  echo "🔨 Compilation CLI..."
  mkdir -p "${CLI_RELEASE_DIR}"
  (cd "${ROOT}/src/cli" && go build -o "${CLI_RELEASE_DIR}/pkarchives" .)
fi

# --- v2 : interface moderne WKWebView ---
echo "🔨 Compilation v2 (WKWebView + Sparkle)..."
swiftc "${ROOT}/src/macos/PKarchivesV2.swift" "${ROOT}/src/macos/KofiLogo.swift" \
  -F "${SPARKLE_DIR}" \
  -parse-as-library \
  -target arm64-apple-macos14.0 \
  -o PKarchives2 \
  -framework SwiftUI \
  -framework AppKit \
  -framework WebKit \
  -framework QuickLookThumbnailing \
  -framework Sparkle \
  -Xlinker -rpath -Xlinker "@executable_path/../Frameworks"

V2_APP_PATH="${ROOT}/release/macos/PKarchives-${APP_VERSION}.app"
V2_APP_DIR="${V2_APP_PATH}/Contents"
mkdir -p "${V2_APP_DIR}/MacOS" "${V2_APP_DIR}/Resources/web" \
  "${V2_APP_DIR}/Resources/ProjectIcons" "${V2_APP_DIR}/Resources/ProjectScreenshots"
cp PKarchives2 "${V2_APP_DIR}/MacOS/PKarchives"
cp "${ROOT}/src/shared/archive.sh" "${V2_APP_DIR}/MacOS/"
cp "${ROOT}/src/shared/archive.sh" "${V2_APP_DIR}/Resources/"
cp "${ROOT}/src/macos/v2/web/index.html" "${ROOT}/src/macos/v2/web/app.js" "${ROOT}/icon.png" "${ROOT}/src/macos/v2/web/logo-drive.svg" "${ROOT}/src/macos/v2/web/logo-finder.png" "${V2_APP_DIR}/Resources/web/"
cp "${ROOT}/src/macos/Resources/kofi-logo.png" "${V2_APP_DIR}/Resources/"
cp "${ROOT}/src/macos/Resources/ProjectIcons/"*.png "${V2_APP_DIR}/Resources/ProjectIcons/"
cp "${ROOT}/src/macos/Resources/ProjectScreenshots/"*.png "${V2_APP_DIR}/Resources/ProjectScreenshots/"
V2_VERSION="${APP_VERSION}"
sed -i '' "s/__VERSION__/${V2_VERSION}/g" "${V2_APP_DIR}/Resources/web/index.html"
chmod +x "${V2_APP_DIR}/MacOS/"*
mkdir -p "${V2_APP_DIR}/Frameworks"
cp -R "${SPARKLE_DIR}/Sparkle.framework" "${V2_APP_DIR}/Frameworks/"

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
    <string>PKarchives</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/mondary/Macos_PKarchives/main/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>t9Zzlc7LZD17hLCepinDvSRHk51hAWGbkFc2yVjbAYs=</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_VERSION}</string>
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

codesign --force --deep --sign - "${V2_APP_PATH}"
rm -f PKarchives2
echo "✅ ${V2_APP_PATH}"
