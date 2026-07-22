#!/bin/bash
set -euo pipefail

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
[[ -d release/macos/PKarchives.app ]] && cp -r release/macos/PKarchives.app "${BACKUP_DIR}/"

# Reset
echo "🧹 Reset de l'environnement..."
rm -rf secrets/.env release/macos/PKarchives.app release/cli/pkarchives
echo ""
echo "🚀 Maintenant, tu peux faire :"
echo "   ./setup.sh    ← comme un vrai nouveau user"
echo ""
echo "Après le test, pour restaurer ta config :"
echo "   cp ${BACKUP_DIR}/.env secrets/.env"
echo "   cp -r ${BACKUP_DIR}/PKarchives.app release/macos/"
echo ""
echo "🎯 Tu es dans un environnement vierge comme un nouveau clone du repo."
