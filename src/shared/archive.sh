#!/bin/bash

set -uo pipefail

# --- Load .env helper ---
load_env() {
  local key="$1" default="$2"
  # 1. Env var directe
  local env_val="${!key:-}"
  if [[ -n "${env_val}" ]]; then echo "${env_val}"; return; fi
  # 2. Fichier secrets/.env
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for env_file in "${script_dir}/../secrets/.env" "${HOME}/.config/pkarchives/secrets/.env"; do
    if [[ -f "${env_file}" ]]; then
      local val
      val=$(grep -E "^${key}=" "${env_file}" 2>/dev/null | head -1 | cut -d'=' -f2 | tr -d "\"'")
      if [[ -n "${val}" ]]; then echo "${val}"; return; fi
    fi
  done
  echo "${default}"
}

# --- Drive folder ID (obligatoire) ---
DRIVE_FOLDER_ID=$(load_env "PKARCHIVES_DRIVE_FOLDER_ID" "")
if [[ -z "${DRIVE_FOLDER_ID}" ]]; then
  echo "❌ PKARCHIVES_DRIVE_FOLDER_ID non défini."
  echo "   Copier secrets/.env.example en secrets/.env et remplir la valeur."
  exit 1
fi

# --- Paramètres configurables ---
desktop_path=$(load_env "PKARCHIVES_DESKTOP_PATH" "${HOME}/Desktop")
desktop_link_name=$(load_env "PKARCHIVES_DESKTOP_LINK_NAME" "DesktopArchive")
rclone_remote=$(load_env "PKARCHIVES_RCLONE_REMOTE" "gdrive")

current_month_year="$(LC_TIME=fr_FR.UTF-8 date +%Y_%m_%B)"

MODE="${1:-files}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

STATUS_FILE="${PKARCHIVES_STATUS_FILE:-${TMPDIR:-/tmp}/pkarchives_$$_status}"
set_status() { echo "$1" > "${STATUS_FILE}"; }
trap 'rm -f "${STATUS_FILE}"' EXIT

shopt -s nullglob

# Collecte et tri : fichiers d'abord (du plus petit au plus gros), puis dossiers
tmp_file=$(mktemp)
tmp_dir=$(mktemp)

for file in "${desktop_path}"/*; do
  bn="$(basename "${file}")"
  [[ "${bn}" == "${desktop_link_name}" ]] && continue
  [[ "${bn}" == ".DS_Store" ]] && continue

  tags=$(mdls -name kMDItemUserTags -raw "${file}" 2>/dev/null || true)
  [[ "${tags}" =~ "Bureau" ]] && continue

  if [[ -d "${file}" ]]; then
    [[ "${MODE}" == "files" ]] && continue
    # Dossier : taille = nombre de fichiers dedans
    size=$(find "${file}" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "${size} ${file}" >> "${tmp_dir}"
  else
    size=$(stat -f%z "${file}" 2>/dev/null || echo 0)
    echo "${size} ${file}" >> "${tmp_file}"
  fi
done

# Trier par taille (chiffre = premier champ), puis reconstruire le tableau
files_to_process=()

while IFS= read -r line; do
  file_path="${line#* }"
  files_to_process+=("${file_path}")
done < <(sort -n "${tmp_file}" 2>/dev/null)

while IFS= read -r line; do
  file_path="${line#* }"
  files_to_process+=("${file_path}")
done < <(sort -n "${tmp_dir}" 2>/dev/null)

rm -f "${tmp_file}" "${tmp_dir}"

count=${#files_to_process[@]}

if [[ ${count} -eq 0 ]]; then
  echo -e "${YELLOW}📭 Rien à archiver.${NC}"
  exit 0
fi

echo -e "${BLUE}📦 ${count} élément(s) à archiver${NC}"
echo -e "${CYAN}🚀 Upload puis suppression immédiate après vérification${NC}"
echo ""

rclone_dir="${rclone_remote}:"
success=0
failed_items=()

upload_file() {
  local file="$1"
  local bn
  bn="$(basename "${file}")"

  rclone copy "${file}" "${rclone_dir}/" \
    --drive-root-folder-id "${DRIVE_FOLDER_ID}" \
    --drive-chunk-size 32M --buffer-size 32M \
    --drive-upload-cutoff 32M \
    --drive-pacer-min-sleep 10ms --drive-pacer-burst 200 \
    --quiet 2>&1
}

for item in "${files_to_process[@]}"; do
  bn="$(basename "${item}")"
  num=$((success + 1))

  if [[ -f "${item}" ]]; then
    sz=$(ls -lh "${item}" | awk '{print $5}')
    echo -e "${BOLD}[${num}/${count}]${NC} 📄 ${bn} (${sz})"
    set_status "📄 [${num}/${count}] ${bn}"
    if ! upload_file "${item}"; then
      failed_items+=("${item}")
      echo -e "  ${RED}❌ Upload échoué, fichier conservé${NC}"
      echo ""
      continue
    fi
    file_id=$(rclone lsjson "${rclone_dir}/${bn}" --drive-root-folder-id "${DRIVE_FOLDER_ID}" 2>/dev/null | grep -oE '"ID":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [[ -n "${file_id}" ]]; then
      echo -e "  ${CYAN}🔗 https://drive.google.com/file/d/${file_id}/view${NC}"
    fi
    success=$((success + 1))
    echo -e "  ${GREEN}✅ Uploadé${NC}"
    set_status "🧹 Suppression ${num}/${count} — ${bn}"
    rm -f "${item}"
    echo -e "  🗑️  ${bn} supprimé"
    echo ""

  elif [[ -d "${item}" ]]; then
    shopt -s nullglob
    sub_files=()
    while IFS= read -r -d '' f; do
      sub_files+=("${f}")
    done < <(find "${item}" -type f -not -path '*/.*' -print0 | sort -z)
    shopt -u nullglob

    sub_count=${#sub_files[@]}
    echo -e "${BOLD}[${num}/${count}]${NC} 📁 ${bn}/ (${sub_count} fichiers)"
    set_status "📁 [${num}/${count}] ${bn}/ — 0/${sub_count}"
    echo ""

    sub_ok=0
    sub_fail=0
    for sub_file in "${sub_files[@]}"; do
      sub_bn="${sub_file#"${item}/"}"
      sub_sz=$(ls -lh "${sub_file}" | awk '{print $5}')
      echo -e "  📄 ${sub_bn} (${sub_sz})"
      set_status "📁 [${num}/${count}] ${bn}/ — ${sub_ok}/${sub_count} — ${sub_bn}"
      if upload_file "${sub_file}"; then
        sub_ok=$((sub_ok + 1))
        echo -e "  ${GREEN}✅ OK${NC}"
      else
        sub_fail=$((sub_fail + 1))
        echo -e "  ${RED}❌ Échec, dossier conservé${NC}"
      fi
    done

    if [[ ${sub_fail} -eq 0 ]]; then
      success=$((success + 1))
      set_status "🧹 Suppression ${num}/${count} — ${bn}"
      rm -rf "${item}"
      echo -e "  ${GREEN}📁 Dossier '${bn}' uploadé + supprimé (${sub_ok}/${sub_count})${NC}"
    else
      failed_items+=("${item}")
      echo -e "  ${YELLOW}⚠️  Dossier '${bn}' conservé (${sub_fail} échec(s))${NC}"
    fi
    echo ""
  fi
done

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ ${success}/${count} élément(s) archivé(s) + supprimé(s)${NC}"
echo -e "${BLUE}📁 Google Drive archive folder${NC}"
echo -e "${CYAN}🔗 https://drive.google.com/drive/folders/${DRIVE_FOLDER_ID}${NC}"
if [[ ${#failed_items[@]} -gt 0 ]]; then
  echo -e "${YELLOW}⚠️  ${#failed_items[@]} élément(s) conservé(s) après échec d'upload${NC}"
fi
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
