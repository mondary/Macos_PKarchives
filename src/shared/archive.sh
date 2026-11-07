#!/bin/bash

set -uo pipefail

# Share the same OS lock as the native sync engine. Perl ships with macOS and
# preserves this descriptor across exec; the kernel releases it even after a crash.
# Other entry points (CLI / v1 / scripts) use the same wrapper, not just the v2 UI.
coordination_file="${PKARCHIVES_COORDINATION_FILE:-${HOME}/Library/Application Support/PKarchives/workspace-operations.lock}"
if [[ "${PKARCHIVES_COORDINATED_PID:-}" != "$$" ]]; then
  umask 077
  mkdir -p "$(dirname "${coordination_file}")" || exit 1
  exec /usr/bin/perl -MFcntl=:DEFAULT,:flock -e '
    $^F = 255;
    my $path = shift @ARGV;
    sysopen(my $lock, $path, O_WRONLY | O_CREAT, 0600) or die "Verrou de coordination inaccessible: $!\n";
    unless (flock($lock, LOCK_EX | LOCK_NB)) {
      print STDERR "Une synchronisation ou un archivage est en cours. Attendre sa fin puis relancer.\n";
      exit 75;
    }
    $ENV{PKARCHIVES_COORDINATED_PID} = $$;
    exec "/bin/bash", @ARGV;
    die "Impossible de lancer archive.sh: $!\n";
  ' "${coordination_file}" "${BASH_SOURCE[0]}" "$@"
fi

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
rclone_remote="${rclone_remote%:}"
rclone_bin="${PKARCHIVES_RCLONE_BINARY:-${HOME}/.local/share/pkarchives/bin/rclone}"
[[ -x "${rclone_bin}" ]] || rclone_bin="rclone"

# The monthly archive root must never also be a live sync destination.
/usr/bin/perl -MJSON::PP -e '
  my ($file, $remote, $archive) = @ARGV;
  exit 0 unless -e $file;
  open my $fh, "<", $file or die "Configuration de synchronisation inaccessible\n";
  local $/; my $pairs = decode_json(<$fh>);
  die "Configuration de synchronisation invalide\n" unless ref($pairs) eq "ARRAY";
  for my $pair (@$pairs) {
    next if exists($pair->{enabled}) && !$pair->{enabled};
    my $connection = $pair->{remoteOverride} // $remote;
    $connection =~ s/:$//;
    if ($connection eq $remote && ($pair->{driveFolderID} // "") eq $archive) {
      die "Le dossier Drive de travail est aussi la racine des archives mensuelles. Choisir des destinations distinctes.\n";
    }
  }
' "$(dirname "${coordination_file}")/sync.json" "${rclone_remote}" "${DRIVE_FOLDER_ID}" || exit 1

# Mode de suppression : "trash" (Corbeille, défaut sûr) ou "delete" (définitif).
delete_mode="$(load_env "PKARCHIVES_DELETE_MODE" "trash")"
del_label="→ Corbeille"
[[ "${delete_mode}" == "delete" ]] && del_label="supprimé (définitif)"

# Corbeille (récupérable) via Finder.
trash_item() {
  local p="$1"
  p="${p//\\/\\\\}"
  p="${p//\"/\\\"}"
  osascript -e "tell application \"Finder\" to delete (POSIX file \"${p}\" as alias)" >/dev/null 2>&1
}

# Suppression selon le mode configuré.
# Persist a review receipt BEFORE deleting anything. If the app exits mid-archive,
# the next sync still knows these are deliberate archival removals, not a lost volume.
archive_receipt=""
record_archive_review() {
  [[ -n "${archive_receipt}" ]] && return 0
  local review_dir pending
  review_dir="$(dirname "${coordination_file}")/archive-reviews"
  mkdir -p "${review_dir}" || return 1
  pending=$(mktemp "${review_dir}/pending.XXXXXXXX") || return 1
  if /usr/bin/perl -MJSON::PP -e 'print encode_json({source => $ARGV[0]})' "${desktop_path}" > "${pending}" &&
     mv "${pending}" "${pending}.json"; then
    archive_receipt="${pending}.json"
    return 0
  fi
  rm -f "${pending}"
  return 1
}

delete_item() {
  record_archive_review || { echo "Compte rendu d’archivage inaccessible : fichier conservé." >&2; return 1; }
  if [[ "${delete_mode}" == "delete" ]]; then
    rm -rf "$1"
  else
    trash_item "$1"
  fi
}

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

# Journal d'événements append-only (interface v2) : type|nom[|détail]
EVENT_FILE="${PKARCHIVES_EVENT_FILE:-}"
emit_event() { [[ -n "${EVENT_FILE}" ]] && printf '%s\n' "$*" >> "${EVENT_FILE}"; }

shopt -s nullglob

# Le tag Finder "Bureau" est lu dans l'xattr directement : mdls peut renvoyer
# un index Spotlight périmé juste après une écriture programmatique.
has_bureau_tag() {
  local file="$1" hex
  hex=$(xattr -px com.apple.metadata:_kMDItemUserTags "${file}" 2>/dev/null) || return 1
  [[ -n "${hex}" ]] || return 1
  printf '%s' "${hex}" | xxd -r -p | plutil -convert xml1 -o - - 2>/dev/null | grep -qi "Bureau"
}

# Collecte et tri : fichiers d'abord (du plus petit au plus gros), puis dossiers
tmp_file=$(mktemp)
tmp_dir=$(mktemp)

for file in "${desktop_path}"/*; do
  bn="$(basename "${file}")"
  [[ "${bn}" == "${desktop_link_name}" ]] && continue
  [[ "${bn}" == ".DS_Store" ]] && continue

  has_bureau_tag "${file}" && continue

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

emit_event "total|${count}"

echo -e "${BLUE}📦 ${count} élément(s) à archiver${NC}"
echo -e "${CYAN}🚀 Upload puis suppression immédiate après vérification${NC}"
echo ""

rclone_dir="${rclone_remote}:${current_month_year}"
success=0
failed_items=()

upload_file() {
  local file="$1"
  local destination="$2"
  local status_prefix="$3"

  "${rclone_bin}" copy "${file}" "${destination}/" \
    --drive-root-folder-id "${DRIVE_FOLDER_ID}" \
    --drive-chunk-size 32M --buffer-size 32M \
    --drive-upload-cutoff 32M \
    --drive-pacer-min-sleep 10ms --drive-pacer-burst 200 \
    --stats 1s --stats-one-line --stats-log-level NOTICE 2>&1 |
    while IFS= read -r line; do
      if [[ "${line}" =~ ([0-9]{1,3})% ]]; then
        set_status "${status_prefix} — ${BASH_REMATCH[1]}%"
        emit_event "progress|$(basename "${file}")|${BASH_REMATCH[1]}"
      fi
      [[ -n "${line}" ]] && printf '%s\n' "${line}"
    done
  return ${PIPESTATUS[0]}
}

for item in "${files_to_process[@]}"; do
  bn="$(basename "${item}")"
  num=$((success + 1))

  if [[ -f "${item}" ]]; then
    sz=$(ls -lh "${item}" | awk '{print $5}')
    echo -e "${BOLD}[${num}/${count}]${NC} 📄 ${bn} (${sz})"
    set_status "📄 [${num}/${count}] ${bn}"
    emit_event "upload|${bn}"
    if ! upload_file "${item}" "${rclone_dir}" "📄 [${num}/${count}] ${bn}"; then
      failed_items+=("${item}")
      emit_event "failed|${bn}"
      echo -e "  ${RED}❌ Upload échoué, fichier conservé${NC}"
      echo ""
      continue
    fi
    file_id=$("${rclone_bin}" lsjson "${rclone_dir}/${bn}" --drive-root-folder-id "${DRIVE_FOLDER_ID}" 2>/dev/null | grep -oE '"ID":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [[ -n "${file_id}" ]]; then
      echo -e "  ${CYAN}🔗 https://drive.google.com/file/d/${file_id}/view${NC}"
      emit_event "fileurl|${bn}|https://drive.google.com/file/d/${file_id}/view"
    fi
    success=$((success + 1))
    echo -e "  ${GREEN}✅ Uploadé${NC}"
    emit_event "ok|${bn}"
    set_status "🗑️ ${num}/${count} — ${bn}"
    if delete_item "${item}"; then
      emit_event "deleted|${bn}"
      echo -e "  🗑️  ${bn} ${del_label}"
    else
      echo -e "  ${YELLOW}⚠️  ${bn} : suppression impossible (conservé)${NC}"
    fi
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
    emit_event "upload|${bn}"
    echo ""

    sub_ok=0
    sub_fail=0
    for sub_file in "${sub_files[@]}"; do
      sub_bn="${sub_file#"${item}/"}"
      if [[ "${sub_bn}" == */* ]]; then
        sub_dir="${sub_bn%/*}"
      else
        sub_dir="."
      fi
      destination_dir="${rclone_dir}/${bn}"
      if [[ "${sub_dir}" != "." ]]; then
        destination_dir+="/${sub_dir}"
      fi
      sub_sz=$(ls -lh "${sub_file}" | awk '{print $5}')
      echo -e "  📄 ${sub_bn} (${sub_sz})"
      set_status "📁 [${num}/${count}] ${bn}/ — ${sub_ok}/${sub_count} — ${sub_bn}"
      if upload_file "${sub_file}" "${destination_dir}" "📁 [${num}/${count}] ${bn}/ — ${sub_ok}/${sub_count} — ${sub_bn}"; then
        sub_ok=$((sub_ok + 1))
        emit_event "progress|${bn}|${sub_ok}/${sub_count}"
        echo -e "  ${GREEN}✅ OK${NC}"
      else
        sub_fail=$((sub_fail + 1))
        echo -e "  ${RED}❌ Échec, dossier conservé${NC}"
      fi
    done

    if [[ ${sub_fail} -eq 0 ]]; then
      success=$((success + 1))
      folder_id=$("${rclone_bin}" lsjson "${rclone_dir}/${bn}" --drive-root-folder-id "${DRIVE_FOLDER_ID}" 2>/dev/null | grep -oE '"ID":"[^"]*"' | head -1 | cut -d'"' -f4)
      [[ -n "${folder_id}" ]] && emit_event "fileurl|${bn}|https://drive.google.com/drive/folders/${folder_id}"
      emit_event "ok|${bn}"
      set_status "🗑️ ${num}/${count} — ${bn}"
      if delete_item "${item}"; then
        emit_event "deleted|${bn}"
        echo -e "  ${GREEN}📁 Dossier '${bn}' uploadé — ${del_label} (${sub_ok}/${sub_count})${NC}"
      else
        echo -e "  ${YELLOW}⚠️  Dossier '${bn}' : suppression impossible (conservé)${NC}"
      fi
    else
      failed_items+=("${item}")
      emit_event "failed|${bn}"
      echo -e "  ${YELLOW}⚠️  Dossier '${bn}' conservé (${sub_fail} échec(s))${NC}"
    fi
    echo ""
  fi
done

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ ${success}/${count} élément(s) archivé(s) → Corbeille${NC}"
echo -e "${BLUE}📁 Google Drive archive folder${NC}"
echo -e "${CYAN}🔗 https://drive.google.com/drive/folders/${DRIVE_FOLDER_ID}${NC}"
if [[ ${#failed_items[@]} -gt 0 ]]; then
  echo -e "${YELLOW}⚠️  ${#failed_items[@]} élément(s) conservé(s) après échec d'upload${NC}"
fi
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
