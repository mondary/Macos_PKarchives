#!/bin/bash
# Régénère le bundle de déploiement FTP store/website/<PROJET>/ depuis la landing.
# Source de vérité : store/index.html + les médias qu'elle référence.
# Le bundle est un artefact généré (ignoré par git) : ne pas l'éditer à la main.
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="${1:-PKarchives}"
SRC="${DIR}/store/index.html"
OUT="${DIR}/store/website/${PROJECT}"

[[ -f "$SRC" ]] || { echo "❌ Landing introuvable : $SRC" >&2; exit 1; }

mkdir -p "${OUT}/media"
cp "$SRC" "${OUT}/index.html"

# Médias réellement référencés par la landing (tout le reste est inline en base64)
for f in background.jpg ultracrea2-promo.mp4; do
  [[ -f "${DIR}/store/media/${f}" ]] || { echo "❌ Média manquant : store/media/${f}" >&2; exit 1; }
  cp "${DIR}/store/media/${f}" "${OUT}/media/"
done

cat > "${OUT}/README.md" <<EOF
# store/website/${PROJECT} — bundle de déploiement FTP

Dossier autonome prêt à uploader tel quel : le nom du dossier est le nom du projet,
la structure interne est déjà correcte.

${PROJECT}/
├── index.html                ← copie de store/index.html
└── media/
    ├── background.jpg        ← fond du hero
    └── ultracrea2-promo.mp4  ← film de présentation

Généré par scripts/website.sh (convention skill premium-promo-media).
Relancer le script après toute modification de store/index.html ou des médias.
EOF

echo "✅ ${OUT} régénéré — uploader le dossier ${PROJECT}/ tel quel."
