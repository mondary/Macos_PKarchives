#!/bin/bash
# Publication manuelle d'une release Sparkle depuis CHANGELOG.md.
# Fournir SPARKLE_PRIVATE_KEY via l'environnement; ne jamais écrire/committer la clé.
set -euo pipefail

DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$DIR"

CHANGELOG_VERSION="$(sed -nE 's/^### \[([0-9]{4}\.[0-9]{2}\.[0-9]+)\].*/\1/p' CHANGELOG.md | head -1)"
VERSION="${1:-$CHANGELOG_VERSION}"
if [[ ! "$VERSION" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]+$ || "$VERSION" != "$CHANGELOG_VERSION" ]]; then
  echo "❌ Version demandée ${VERSION} différente du CHANGELOG ${CHANGELOG_VERSION}" >&2; exit 1
fi
if ! command -v gh >/dev/null 2>&1; then
  echo "❌ gh CLI requis : brew install gh" >&2; exit 1
fi
ZIP_NAME="PKarchives-${VERSION}.zip"
DMG_NAME="PKarchives-${VERSION}.dmg"
PKG_NAME="PKarchives-${VERSION}.pkg"
APP="release/macos/PKarchives-${VERSION}.app"
SIGN_UPDATE="release/sparkle/bin/sign_update"

echo "🔨 Build v${VERSION}..."
./scripts/build.sh
[[ -d "$APP" ]] || { echo "❌ App versionnée introuvable : $APP" >&2; exit 1; }
INFO_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
[[ "$INFO_VERSION" == "$VERSION" ]] || { echo "❌ Version du bundle ${INFO_VERSION} différente de ${VERSION}" >&2; exit 1; }

mkdir -p release
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/pkarchives-dmg.XXXXXX")"
PKG_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/pkarchives-pkg.XXXXXX")"
trap 'rm -rf "$STAGE" "$PKG_STAGE" "${KEY_FILE:-}" "${APPCAST_TEMP:-}"' EXIT
ditto "$APP" "$STAGE/$(basename "$APP")"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "PKarchives ${VERSION}" -srcfolder "$STAGE" -format UDZO -imagekey zlib-level=9 -ov "release/$DMG_NAME"
cp "release/$DMG_NAME" release/PKarchives.dmg
ditto "$APP" "$PKG_STAGE/PKarchives.app"
pkgbuild --root "$PKG_STAGE" --install-location /Applications \
  --identifier com.pkarchives.installer --version "$VERSION" "release/$PKG_NAME"
cp "release/$PKG_NAME" release/PKarchives.pkg
ZIP_READY=0
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  ditto -c -k --sequesterRsrc --keepParent "$APP" "release/$ZIP_NAME"
  KEY_FILE="$(mktemp "${TMPDIR:-/tmp}/pkarchives-sparkle-key.XXXXXX")"
  chmod 600 "$KEY_FILE"
  printf '%s' "$SPARKLE_PRIVATE_KEY" > "$KEY_FILE"
  SIG=$("$SIGN_UPDATE" -f "$KEY_FILE" "release/$ZIP_NAME" | sed -E 's/.*edSignature="([^"]+)".*/\1/')
  [[ -n "$SIG" ]] || { echo "❌ Signature Sparkle vide" >&2; exit 1; }
  ZIP_READY=1
  LEN=$(stat -f%z "release/$ZIP_NAME")
  PUB_DATE="$(date -u '+%a, %d %b %Y %H:%M:%S %z')"
  APPCAST_TEMP="$(mktemp "${TMPDIR:-/tmp}/pkarchives-appcast.XXXXXX")"
  cat > "$APPCAST_TEMP" <<EOF
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/" version="2.0">
  <channel>
    <title>PKarchives</title>
    <link>https://raw.githubusercontent.com/mondary/Macos_PKarchives/main/appcast.xml</link>
    <description>Dernières mises à jour de PKarchives</description>
    <language>fr</language>
    <item>
      <title>Version ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure url="https://github.com/mondary/Macos_PKarchives/releases/download/v${VERSION}/${ZIP_NAME}" sparkle:edSignature="${SIG}" length="${LEN}" type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF
else
  echo "⚠️ DMG publiable ; Sparkle non mis à jour : SPARKLE_PRIVATE_KEY est absente." >&2
fi

echo "🏷️ Publication de v${VERSION}..."
gh release create "v${VERSION}" "release/${DMG_NAME}" release/PKarchives.dmg \
  "release/${PKG_NAME}" release/PKarchives.pkg --title "PKarchives ${VERSION}" --generate-notes
if [[ "$ZIP_READY" == 1 ]]; then gh release upload "v${VERSION}" "release/${ZIP_NAME}"; fi

if [[ "$ZIP_READY" == 1 ]]; then
  echo "🌐 Mise à jour de l'appcast sur main..."
  git fetch origin main
  git switch --create "appcast-update-${VERSION}" origin/main
  cp "$APPCAST_TEMP" appcast.xml
  git add appcast.xml
  git commit -m "MAJ: appcast sparkle pour v${VERSION}"
  git push origin HEAD:main
  echo "✅ Release v${VERSION} et appcast Sparkle signés publiés."
else
  echo "✅ DMG de la release v${VERSION} publié ; Sparkle reste en attente de la clé privée."
fi
