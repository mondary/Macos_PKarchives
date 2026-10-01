#!/bin/bash
set -euo pipefail

# Toujours exécuter depuis la racine du repo
cd "$(cd "$(dirname "$0")/.." && pwd)"
APP_VERSION="$(sed -nE 's/^### \[([0-9]{4}\.[0-9]{2}\.[0-9]+)\].*/\1/p' CHANGELOG.md | head -1)"
APP_PATH="release/macos/PKarchives-${APP_VERSION}.app"

echo "🧪 PKarchives — Mode Sandbox"
echo ""
echo "Ce mode te permet de tester setup.sh comme un nouveau user,"
echo "sans toucher à ta vraie configuration actuelle."
echo ""

# Backup
BACKUP_DIR=".sandbox-backup-$(date +%Y%m%d_%H%M%S)"
mkdir -p "${BACKUP_DIR}"
echo "📦 Backup de ta config actuelle : ${BACKUP_DIR}"
[[ -f secrets/.env ]] && cp secrets/.env "${BACKUP_DIR}/"
[[ -d "$APP_PATH" ]] && cp -r "$APP_PATH" "${BACKUP_DIR}/"

# Reset
echo "🧹 Reset de l'environnement..."
rm -rf secrets/.env "$APP_PATH" release/cli/pkarchives
echo ""
echo "🚀 Maintenant, tu peux faire :"
echo "   ./setup.sh    ← comme un vrai nouveau user"
echo ""
echo "Après le test, pour restaurer ta config :"
echo "   cp ${BACKUP_DIR}/.env secrets/.env"
echo "   cp -r ${BACKUP_DIR}/PKarchives-${APP_VERSION}.app release/macos/"
echo ""
echo "🎯 Tu es dans un environnement vierge comme un nouveau clone du repo."
