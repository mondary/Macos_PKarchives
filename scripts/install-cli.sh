#!/bin/bash
# Installe la CLI/TUI pkarchives utilisable partout (Apple Silicon).
# Usage : curl -fsSL https://raw.githubusercontent.com/mondary/Macos_PKarchives/main/scripts/install-cli.sh | sh
set -euo pipefail

REPO="mondary/Macos_PKarchives"
ASSET="pkarchives-darwin-arm64"

ARCH="$(uname -m)"
if [[ "$ARCH" != "arm64" ]]; then
  echo "❌ La CLI est publiée pour Apple Silicon (arm64). Architecture détectée : $ARCH" >&2
  exit 1
fi

DEST="/usr/local/bin"
if ! touch "${DEST}/.pkarchives-write-test" 2>/dev/null; then
  DEST="${HOME}/.local/bin"
  mkdir -p "$DEST"
fi
rm -f "${DEST}/.pkarchives-write-test" 2>/dev/null || true

URL="https://github.com/${REPO}/releases/latest/download/${ASSET}"
TMP="$(mktemp)"
echo "⬇️  Téléchargement de la CLI…"
curl -fsSL "$URL" -o "$TMP"
chmod +x "$TMP"
mv "$TMP" "${DEST}/pkarchives"

if [[ "$DEST" == "${HOME}/.local/bin" ]] && ! echo "$PATH" | grep -q "${HOME}/.local/bin"; then
  SHELL_RC="${HOME}/.zshrc"
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
  echo "→ ${DEST} ajouté au PATH dans ${SHELL_RC} — relance le terminal ou : source ${SHELL_RC}"
fi

echo "✅ pkarchives installé dans ${DEST}/pkarchives"
echo "   Essaie : pkarchives"
