#!/bin/bash
# Publie une release PKarchives2 avec Sparkle :
#   1. Build de l'app
#   2. Zip signé EdDSA
#   3. Génération de appcast.xml (lu par les apps pour détecter les MAJ)
#   4. Publication : commit de l'appcast + GitHub Release
#
# Usage : ./.github/scripts/release.sh            (version lue depuis VERSION)
#         ./.github/scripts/release.sh 2026.10.01 (version explicite)
set -euo pipefail

DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$DIR"

VERSION="${1:-$(tr -d '\n' < VERSION)}"
ZIP_NAME="PKarchives2-${VERSION}.zip"
BUILD_DIR="release"
APP="release/macos/PKarchives2.app"
SIGN_UPDATE="release/sparkle/bin/sign_update"

if ! command -v gh >/dev/null 2>&1; then
  echo "❌ gh CLI requis : brew install gh" >&2; exit 1
fi

echo "🔨 Build v${VERSION}..."
./build.sh

echo "📦 Zip..."
mkdir -p "${BUILD_DIR}"
rm -f "${BUILD_DIR}/${ZIP_NAME}"
echo "✍️  Signature EdDSA..."
SIG=$("$SIGN_UPDATE" "${BUILD_DIR}/${ZIP_NAME}" | sed -E 's/.*edSignature="([^"]+)".*/\1/')
LEN=$(stat -f%z "${BUILD_DIR}/${ZIP_NAME}")
PUB_DATE="$(date -u '+%a, %d %b %Y %H:%M:%S %z')"

cat > appcast.xml << EOF
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
            <enclosure
                url="https://github.com/mondary/Macos_PKarchives/releases/download/${VERSION}/${ZIP_NAME}"
                sparkle:edSignature="${SIG}"
                length="${LEN}"
                type="application/octet-stream"
            />
        </item>
    </channel>
</rss>
EOF

echo "⬆️  GitHub release v${VERSION}..."
git add appcast.xml
git commit -m "Release v${VERSION}" || true
gh release create "${VERSION}" \
  --title "PKarchives ${VERSION}" \
  --generate-notes \
  "${BUILD_DIR}/${ZIP_NAME}"
git push

echo "✅ Release v${VERSION} publiée. L'appcast est à jour sur main."
