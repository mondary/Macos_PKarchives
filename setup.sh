#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SECRETS_DIR="${DIR}/secrets"
ENV_FILE="${SECRETS_DIR}/.env"

# Couleurs
GREEN=$(printf '\033[0;32m')
NC=$(printf '\033[0m')

echo "📦 PKarchives — Setup"
echo ""

# Créer le dossier secrets
mkdir -p "${SECRETS_DIR}"

# Vérifier si .env existe déjà
if [[ -f "${ENV_FILE}" ]]; then
  echo "✅ Configuration existante : ${ENV_FILE}"
  echo ""
  read -p "Voulez-vous reconfigurer ? (o/N) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    echo "Setup terminé. Pour modifier : ${ENV_FILE}"
    exit 0
  fi
  rm -f "${ENV_FILE}"
fi

# Demander le Drive Folder ID
echo "1. Google Drive Folder ID"
echo ""
printf "%b\n" "   Exemple d'URL : https://drive.google.com/drive/folders/${GREEN}1GFBhH-BbuWq33_YMOUcJIGovPN3q5NXv${NC}"
printf "%b\n" "   L'ID est la partie verte : ${GREEN}1GFBhH-BbuWq33_YMOUcJIGovPN3q5NXv${NC}"
echo ""
while true; do
  read -p "   Votre Drive Folder ID : " DRIVE_ID
  if [[ -n "${DRIVE_ID}" ]]; then
    break
  fi
  echo "   ⚠️  ID requis"
done
echo ""

# Demander le desktop path (optionnel, défaut : ~/Desktop)
echo "2. Dossier à archiver"
printf "%b\n" "   Par défaut : ${GREEN}~/Desktop${NC} (appuyez sur Entrée)"
read -p "   Votre dossier : " DESKTOP_PATH
DESKTOP_PATH="${DESKTOP_PATH:-~/Desktop}"
echo ""

# Demander le nom du symlink (optionnel, défaut : DesktopArchive)
echo "3. Nom du symlink à exclure"
printf "%b\n" "   Par défaut : ${GREEN}DesktopArchive${NC} (appuyez sur Entrée)"
read -p "   Votre nom : " LINK_NAME
LINK_NAME="${LINK_NAME:-DesktopArchive}"
echo ""

# Demander le remote rclone
echo "4. Remote rclone (connexion Google Drive)"
echo "   rclone utilise des \"remotes\" que tu as configurés au préalable"
echo ""

# Lister les remotes disponibles
if command -v rclone &> /dev/null; then
  echo "   Remotes disponibles :"
  while IFS= read -r remote; do
    printf "%b\n" "   - ${GREEN}${remote}${NC}"
  done < <(rclone listremotes)
  echo ""
fi

read -p "   Votre remote rclone [gdrive] : " RCLONE_REMOTE
RCLONE_REMOTE="${RCLONE_REMOTE:-gdrive}"
echo ""

# Vérifier rclone
echo "5. Vérification de rclone..."
if ! command -v rclone &> /dev/null; then
  echo "   ⚠️  rclone n'est pas installé"
  echo "   Installez-le : brew install rclone"
else
  if rclone listremotes | grep -q "^${RCLONE_REMOTE}:"; then
    echo "   ✅ Remote '${RCLONE_REMOTE}' trouvé"
  else
    echo "   ⚠️  Remote '${RCLONE_REMOTE}' non trouvé"
    echo "   Configurez-le : rclone config"
  fi
fi
echo ""

# Créer le .env
cat > "${ENV_FILE}" << EOF
# PKarchives — Configuration générée automatiquement le $(date +%Y-%m-%d)
PKARCHIVES_DRIVE_FOLDER_ID="${DRIVE_ID}"
PKARCHIVES_DESKTOP_PATH="${DESKTOP_PATH}"
PKARCHIVES_DESKTOP_LINK_NAME="${LINK_NAME}"
PKARCHIVES_RCLONE_REMOTE="${RCLONE_REMOTE}"
EOF

echo "✅ Configuration créée : ${ENV_FILE}"
echo ""
echo "🚀 Build de l'app..."
"${DIR}/build.sh"
echo ""
echo "🎉 Setup terminé !"
echo "   Lancez l'app : open release/PKarchives.app"
