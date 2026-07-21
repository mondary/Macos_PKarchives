#!/bin/bash

# ═══════════════════════════════════════════════════════════
#  PKarchives — Installer
#  Usage: curl -fsSL <url>/setup.sh | sh
#         ./setup.sh
# ═══════════════════════════════════════════════════════════

set -uo pipefail

DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
[ -z "$DIR" ] && DIR="$(pwd)"
SECRETS_DIR="${DIR}/secrets"
ENV_FILE="${SECRETS_DIR}/.env"

# ── Couleurs (vraies séquences ESC) ──────────────────────────
RST="$(printf '\033[0m')"
BOLD="$(printf '\033[1m')"
DIM="$(printf '\033[2m')"
RED="$(printf '\033[0;31m')"
GREEN="$(printf '\033[0;32m')"
YELLOW="$(printf '\033[0;33m')"
BLUE="$(printf '\033[0;34m')"
MAGENTA="$(printf '\033[0;35m')"
CYAN="$(printf '\033[0;36m')"
GRAY="$(printf '\033[0;90m')"

# ── Helpers d'affichage ──────────────────────────────────────
print()     { printf '%b\n' "$*"; }
println()   { printf '\n'; }
label()     { printf '%b%s%b' "$GRAY" "$1" "$RST"; }
value()     { printf '%b%s%b' "$BOLD" "$1" "$RST"; }
ok()        { printf '%b✓%b %s\n' "$GREEN" "$RST" "$1"; }
fail()      { printf '%b✗%b %s\n' "$RED" "$RST" "$1"; }
pending()   { printf '%b•%b %s\n' "$GRAY" "$RST" "$1"; }
info()      { printf '%bℹ%b  %s\n' "$CYAN" "$RST" "$1"; }
step_num()  { printf '%b[%s]%b' "$DIM" "$1" "$RST"; }

# Spinner : spin <pid> <message>
spin() {
  local pid=$1 msg=$2
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r%b%s%b  %s' "$CYAN" "${frames[$((i % 10))]}" "$RST" "$msg"
    i=$((i + 1))
    sleep 0.08
  done
  wait "$pid" 2>/dev/null
  local rc=$?
  printf '\r%b\033[K' "$RST"
  return $rc
}

# run_step <message> <command...>
run_step() {
  local msg=$1; shift
  "$@" >/tmp/pkarch_setup_$$.log 2>&1 &
  local pid=$!
  spin "$pid" "$msg"
  local rc=$?
  rm -f /tmp/pkarch_setup_$$.log
  return $rc
}

# ── Bannière ─────────────────────────────────────────────────
banner() {
  println
  printf '%b%b' "$BOLD" "$CYAN"
  cat <<'BAN'
  ╦  ╦╔═╗╦  ╦╔╦╗╔═╗╦ ╦╦╔╗╔╔═╗
  ║║║║╠═╣║  ║ ║ ║║║║║║║║║╠═╣
  ╚╩╝╩╩ ╩╩═╝╩ ╩ ╚╩╝╚╩╝╚╝╚╝╩ ╩
BAN
  printf '%b' "$RST"
  printf '%b  Archives your Desktop to Google Drive — powered by rclone%b\n' "$GRAY" "$RST"
  println
}

# ── Carte (boxed) ────────────────────────────────────────────
# Affiche un texte entre des bordures arrondies
card() {
  local content="$1"
  local line
  local max_len=0
  # Calculer la largeur max (sans codes ANSI — approximation)
  while IFS= read -r line; do
    local stripped
    stripped=$(printf '%b' "$line" | sed 's/\x1b\[[0-9;]*m//g')
    local len=${#stripped}
    [ "$len" -gt "$max_len" ] && max_len=$len
  done <<< "$content"

  printf '%b╭%s╮%b\n' "$GRAY" "$(printf '─%.0s' $(seq 1 $((max_len + 2))))" "$RST"
  while IFS= read -r line; do
    local stripped
    stripped=$(printf '%b' "$line" | sed 's/\x1b\[[0-9;]*m//g')
    local pad=$((max_len - ${#stripped}))
    [ "$pad" -lt 0 ] && pad=0
    printf '%b│%b %b%b%*s%b│%b\n' "$GRAY" "$RST" "$line" "$RST" "$pad" "" "$GRAY" "$RST"
  done <<< "$content"
  printf '%b╰%s╯%b\n' "$GRAY" "$(printf '─%.0s' $(seq 1 $((max_len + 2))))" "$RST"
}

# ── Détection système ────────────────────────────────────────
detect_system() {
  SYSTEM_OS="$(uname -s)"
  SYSTEM_ARCH="$(uname -m)"
  SYSTEM_MACOS="$(sw_vers -productVersion 2>/dev/null || echo 'N/A')"

  if command -v rclone >/dev/null 2>&1; then
    RCLONE_VER="$(rclone version 2>/dev/null | head -1 | awk '{print $2}')"
    RCLONE_STATUS="installed"
  else
    RCLONE_VER="not found"
    RCLONE_STATUS="missing"
  fi

  SHELL_NAME="$(basename "${SHELL:-/bin/bash}")"
}

# ── Intro : carte de système ─────────────────────────────────
show_system_card() {
  local content
  content=$(
    printf '%b⚡  PKarchives installer%b\n\n' "$BOLD" "$RST"
    printf '%bSystem:    %b%s/%s\n' "$GRAY" "$RST" "$SYSTEM_OS" "$SYSTEM_ARCH"
    printf '%bmacOS:     %b%s\n' "$GRAY" "$RST" "$SYSTEM_MACOS"
    printf '%bShell:     %b%s\n' "$GRAY" "$RST" "$SHELL_NAME"
    if [ "$RCLONE_STATUS" = "installed" ]; then
      printf '%brclone:    %b%s %b(installed)%b\n' "$GRAY" "$RST" "$RCLONE_VER" "$GREEN" "$RST"
    else
      printf '%brclone:    %b%s %b(missing — required)%b\n' "$GRAY" "$RST" "$RCLONE_VER" "$RED" "$RST"
    fi
  )
  card "$content"
}

# ═══════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════

banner
detect_system
show_system_card
println

# ── Vérifier rclone ──────────────────────────────────────────
if [ "$RCLONE_STATUS" = "missing" ]; then
  fail "rclone is required but not installed."
  println
  info "Install it with:"
  printf '  %bbrew install rclone%b\n' "$CYAN" "$RST"
  println
  exit 1
fi

# ── Vérifier macOS ───────────────────────────────────────────
if [ "$SYSTEM_OS" != "Darwin" ]; then
  fail "PKarchives requires macOS."
  exit 1
fi

# ── Lister les remotes rclone ────────────────────────────────
REMOTES=""
if command -v rclone >/dev/null 2>&1; then
  REMOTES="$(rclone listremotes 2>/dev/null | tr '\n' ' ')"
fi

if [ -z "$REMOTES" ]; then
  fail "No rclone remote configured."
  println
  info "Configure one with:"
  printf '  %brclone config%b\n' "$CYAN" "$RST"
  println
  exit 1
fi

# ── Demander le Drive Folder ID ──────────────────────────────
println
printf '%b1. Google Drive Folder ID%b\n' "$BOLD" "$RST"
println
printf '   Example URL:  https://drive.google.com/drive/folders/%b1GFBhH-BbuWq33_YMOUcJIGovPN3q5NXv%b\n' "$GREEN" "$RST"
printf '   The ID is the %bgreen%b part above.\n' "$GREEN" "$RST"
println
while true; do
  printf '   %bYour Drive Folder ID:%b ' "$CYAN" "$RST"
  read -r DRIVE_ID
  if [ -n "$DRIVE_ID" ]; then
    break
  fi
  printf '   %b⚠  ID required%b\n' "$YELLOW" "$RST"
done
println

# ── Demander le dossier à archiver ───────────────────────────
printf '%b2. Folder to archive%b\n' "$BOLD" "$RST"
printf '   Default: %b~/Desktop%b (just press Enter)\n' "$GREEN" "$RST"
printf '   %bYour folder:%b ' "$CYAN" "$RST"
read -r DESKTOP_INPUT
DESKTOP_PATH="${DESKTOP_INPUT:-}"
println

# ── Demander le remote rclone ────────────────────────────────
printf '%b3. rclone remote%b\n' "$BOLD" "$RST"
println
printf '   %bAvailable remotes:%b\n' "$GRAY" "$RST"
for r in $REMOTES; do
  printf '     %b-%b %s\n' "$GRAY" "$RST" "$r"
done
println
DEFAULT_REMOTE="$(echo "$REMOTES" | awk '{print $1}')"
printf '   Default: %b%s%b (just press Enter)\n' "$GREEN" "$DEFAULT_REMOTE" "$RST"
printf '   %bYour remote:%b ' "$CYAN" "$RST"
read -r REMOTE_INPUT
RCLONE_REMOTE="${REMOTE_INPUT:-$DEFAULT_REMOTE}"
println

# ── Résumé ───────────────────────────────────────────────────
printf '%b════════════════════════════════════════%b\n' "$GRAY" "$RST"
printf '%bConfiguration summary%b\n' "$BOLD" "$RST"
printf '%b════════════════════════════════════════%b\n' "$GRAY" "$RST"
printf '  Drive Folder ID : %b%s%b\n' "$BOLD" "$DRIVE_ID" "$RST"
printf '  Folder to archive: %b%s%b\n' "$BOLD" "${DESKTOP_PATH:-~/Desktop (default)}" "$RST"
printf '  rclone remote   : %b%s%b\n' "$BOLD" "$RCLONE_REMOTE" "$RST"
printf '%b════════════════════════════════════════%b\n' "$GRAY" "$RST"
println
printf '   %bProceed? [Y/n]%b ' "$CYAN" "$RST"
read -r CONFIRM
CONFIRM="${CONFIRM:-Y}"
case "$CONFIRM" in
  [Yy]*|"") ;;
  *) info "Aborted."; exit 0 ;;
esac
println

# ═══════════════════════════════════════════════════════════
#  INSTALLATION
# ═══════════════════════════════════════════════════════════

printf '%bInstalling…%b\n\n' "$BOLD" "$RST"

# Step 1: Create secrets/.env
do_write_env() {
  mkdir -p "$SECRETS_DIR"
  cat > "$ENV_FILE" << EOF
# PKarchives — Configuration
PKARCHIVES_DRIVE_FOLDER_ID="${DRIVE_ID}"
PKARCHIVES_DESKTOP_PATH="${DESKTOP_PATH}"
PKARCHIVES_RCLONE_REMOTE="${RCLONE_REMOTE}"
EOF
}

do_write_env &
if spin $! "Writing secrets/.env"; then
  ok "Configuration written to secrets/.env"
else
  fail "Failed to write configuration"
  exit 1
fi

# Step 2: Verify rclone remote
if rclone listremotes 2>/dev/null | grep -q "^${RCLONE_REMOTE}$"; then
  ok "Remote '${RCLONE_REMOTE}' verified"
else
  fail "Remote '${RCLONE_REMOTE}' not found"
  info "Configure it with: rclone config"
  exit 1
fi

# Step 3: Build the app
if [ -f "$DIR/build.sh" ]; then
  (
    cd "$DIR" && bash build.sh
  ) >/tmp/pkarch_build_$$.log 2>&1 &
  if spin $! "Building PKarchives.app (compiling Swift…)"; then
    ok "App compiled successfully"
  else
    fail "Build failed"
    cat /tmp/pkarch_build_$$.log 2>/dev/null | tail -5
    rm -f /tmp/pkarch_build_$$.log
    exit 1
  fi
  rm -f /tmp/pkarch_build_$$.log
else
  pending "build.sh not found, skipping compilation"
fi

# ═══════════════════════════════════════════════════════════
#  DONE
# ═══════════════════════════════════════════════════════════

println
printf '%b╔══════════════════════════════════════════╗%b\n' "$GREEN" "$RST"
printf '%b║%b  %b✓  Installation complete!%b                %b║%b\n' "$GREEN" "$RST" "$BOLD" "$RST" "$GREEN" "$RST"
printf '%b╚══════════════════════════════════════════╝%b\n' "$GREEN" "$RST"
println
printf '  %bLaunch the app:%b\n' "$GRAY" "$RST"
printf '    %bopen release/PKarchives.app%b\n' "$CYAN" "$RST"
println
printf '  %bEdit config later:%b\n' "$GRAY" "$RST"
printf '    %b%s%b\n' "$CYAN" "$ENV_FILE" "$RST"
println
