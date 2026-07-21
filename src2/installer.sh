#!/usr/bin/env bash
# PKarchives Go installer — style Riptide
# Usage:
#   curl -fsSL <url>/installer.sh | sh
#   bash installer.sh

# Re-exec sous bash (curl|sh passe par sh)
if [ -z "${BASH_VERSION:-}" ]; then
  if [ -f "$0" ] && [ -t 0 ]; then
    exec bash "$0" "$@"
  else
    _pkarch_reexec="$(mktemp "${TMPDIR:-/tmp}/pkarchives-install.XXXXXX.sh")"
    cat > "$_pkarch_reexec"
    export _pkarch_reexec
    exec bash "$_pkarch_reexec" "$@"
  fi
fi

set -o pipefail

TMP="$(mktemp -d)"
INSTDIR="$TMP/pkarchives-installer"
LOGFILE="$TMP/install.log"
trap 'rm -rf "$TMP"; [ -n "${_pkarch_reexec:-}" ] && rm -f "$_pkarch_reexec"' EXIT

# ── Helpers ───────────────────────────────────────────────────
RST="$(printf '\033[0m')"
BOLD="$(printf '\033[1m')"
GREEN="$(printf '\033[0;32m')"
RED="$(printf '\033[0;31m')"
YELLOW="$(printf '\033[0;33m')"
CYAN="$(printf '\033[0;36m')"
GRAY="$(printf '\033[0;90m')"

ok()    { printf '%b✓%b %s\n' "$GREEN" "$RST" "$1"; }
fail()  { printf '%b✗%b %s\n' "$RED" "$RST" "$1"; }
info()  { printf '%bℹ%b  %s\n' "$CYAN" "$RST" "$1"; }
step()  { printf '%b→%b %s\n' "$CYAN" "$RST" "$1"; }

cleanup_and_fail() {
  echo "" >&2
  echo "Installation did not complete. See the log above." >&2
  exit 1
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "This installer needs '$1', but it was not found."
    echo "   Please install it and run again." >&2
    exit 1
  fi
}

# ── Vérifications ─────────────────────────────────────────────
need_cmd rclone
need_cmd git

# ── Bannière ──────────────────────────────────────────────────
echo ""
printf '%b%b' "$BOLD" "$CYAN"
cat <<'BAN'
  ╦  ╦╔═╗╦  ╦╔╦╗╔═╗╦ ╦╦╔╗╔╔═╗
  ║║║║╠═╣║  ║ ║ ║║║║║║║║║╠═╣
  ╚╩╝╩╩ ╩╩═╝╩ ╩ ╚╩╝╚╩╝╚╝╚╝╩ ╩
BAN
printf '%b' "$RST"
printf '%b  Go TUI edition — Archives your Desktop to Google Drive%b\n' "$GRAY" "$RST"
echo ""

# ── Détection système ─────────────────────────────────────────
OS_LC="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in x86_64|amd64) ARCH="amd64" ;; aarch64|arm64) ARCH="arm64" ;; esac

printf '%bSystem:%b  %s/%s\n' "$GRAY" "$RST" "$OS_LC" "$ARCH"
printf '%brclone:%b  %s\n' "$GRAY" "$RST" "$(rclone version 2>/dev/null | head -1)"
echo ""

# ── Vérifier Go ───────────────────────────────────────────────
GO_CMD=""
GO_WAS_PRESENT=0

go_is_new_enough() {
  local ver major minor
  ver="$("$1" version 2>/dev/null | awk '{print $3}')"
  ver="${ver#go}"
  case "$ver" in [0-9]*.[0-9]*) ;; *) return 1 ;; esac
  major="${ver%%.*}"
  minor="${ver#*.}"; minor="${minor%%.*}"
  [ "$major" -eq 1 ] && [ "$minor" -ge 23 ]
}

if [ -x "$HOME/.local/go/bin/go" ] && go_is_new_enough "$HOME/.local/go/bin/go"; then
  GO_CMD="$HOME/.local/go/bin/go"
  GO_WAS_PRESENT=1
elif command -v go >/dev/null 2>&1 && go_is_new_enough "$(command -v go)"; then
  GO_CMD="go"
  GO_WAS_PRESENT=1
fi

# ── Installer Go si manquant ──────────────────────────────────
install_go() {
  local gover url
  gover="$(curl -fsSL https://go.dev/VERSION?m=text | head -1)"
  if [ -z "$gover" ]; then
    fail "Could not determine the latest Go version."
    cleanup_and_fail
  fi
  url="https://go.dev/dl/${gover}.${OS_LC}-${ARCH}.tar.gz"
  echo "Downloading $gover for ${OS_LC}/${ARCH}…"
  if ! curl -fsSL "$url" -o "$TMP/go.tgz" >>"$LOGFILE" 2>&1; then
    fail "Failed to download Go"
    cleanup_and_fail
  fi
  mkdir -p "$HOME/.local"
  if ! tar -C "$HOME/.local" -xzf "$TMP/go.tgz" >>"$LOGFILE" 2>&1; then
    fail "Failed to extract Go"
    cleanup_and_fail
  fi
  GO_CMD="$HOME/.local/go/bin/go"
  echo "$gover"
}

if [ -z "$GO_CMD" ]; then
  cat <<'MSG'

  PKarchives (Go edition) is written in Go. Go is a free, open-source programming
  language made by Google. Installing it lets your computer build PKarchives from
  source — it is safe and widely used.

MSG
  ans="Y"
  if [ -t 0 ]; then
    read -r -p "Download and install Go now? [Y/n] " ans
  fi
  case "$ans" in
    ""|Y|y|yes|YES) ;;
    *) echo "Aborted. Install Go yourself (https://go.dev/dl) and rerun."; exit 0 ;;
  esac
  GO_VER="$(install_go)"
  GO_ACTION="installed"
else
  GO_VER="$("$GO_CMD" version | head -1)"
  GO_ACTION="already-present"
fi

# ── PATH ──────────────────────────────────────────────────────
export PATH="$HOME/.local/go/bin:$HOME/go/bin:$PATH"

# ── Cloner et build ───────────────────────────────────────────
REPO_URL="${PKARCHIVES_REPO:-https://github.com/clm/PKarchives.git}"

echo ""
step "Cloning repository…"
if ! git clone --quiet "$REPO_URL" "$INSTDIR" >>"$LOGFILE" 2>&1; then
  fail "Failed to clone repository"
  cleanup_and_fail
fi
ok "Repository cloned"

echo ""
step "Building PKarchives (compiling Go TUI…)"

export GOFLAGS=-mod=mod
export GOPATH="${GOPATH:-$HOME/go}"

if ! ( cd "$INSTDIR/src2" && "$GO_CMD" mod tidy >>"$LOGFILE" 2>&1 && "$GO_CMD" build -o "$HOME/go/bin/pkarchives" . >>"$LOGFILE" 2>&1 ); then
  fail "Build failed"
  tail -n 20 "$LOGFILE" >&2
  cleanup_and_fail
fi
ok "Binary installed to ~/go/bin/pkarchives"

# ── Config ────────────────────────────────────────────────────
CONF_FILE="$HOME/.pkarchives.conf"

if [ ! -f "$CONF_FILE" ] || ! grep -q "PKARCHIVES_DRIVE_FOLDER_ID" "$CONF_FILE" 2>/dev/null; then
  echo ""
  printf '%b═══ Configuration ═══%b\n' "$CYAN" "$RST"
  echo ""
  printf '1. Google Drive Folder ID\n'
  printf '   Example: https://drive.google.com/drive/folders/%b1GFBhH-BbuWq33_YMOUcJIGovPN3q5NXv%b\n' "$GREEN" "$RST"
  while true; do
    printf '   %bYour ID:%b ' "$CYAN" "$RST"
    read -r DRIVE_ID
    [ -n "$DRIVE_ID" ] && break
    printf '   %b⚠  required%b\n' "$YELLOW" "$RST"
  done

  printf '\n2. rclone remote\n'
  REMOTES=$(rclone listremotes 2>/dev/null | tr '\n' ' ')
  printf '   Available: %b%s%b\n' "$GRAY" "$REMOTES" "$RST"
  DEFAULT_REMOTE=$(echo "$REMOTES" | awk '{print $1}')
  printf '   Default [%b%s%b]: ' "$GREEN" "$DEFAULT_REMOTE" "$RST"
  read -r REMOTE
  REMOTE="${REMOTE:-$DEFAULT_REMOTE}"

  cat > "$CONF_FILE" << EOF
PKARCHIVES_DRIVE_FOLDER_ID="${DRIVE_ID}"
PKARCHIVES_RCLONE_REMOTE="${REMOTE}"
EOF
  ok "Config written to $CONF_FILE"
fi

# ── Done ──────────────────────────────────────────────────────
echo ""
printf '%b╔══════════════════════════════════════════╗%b\n' "$GREEN" "$RST"
printf '%b║%b  %b✓  Installation complete!%b                %b║%b\n' "$GREEN" "$RST" "$BOLD" "$RST" "$GREEN" "$RST"
printf '%b╚══════════════════════════════════════════╝%b\n' "$GREEN" "$RST"
echo ""
printf '  %bRun it now:%b\n' "$GRAY" "$RST"
printf '    %bpkarchives%b\n' "$CYAN" "$RST"
echo ""
printf '  %bConfig:%b %b%s%b\n' "$GRAY" "$RST" "$CYAN" "$CONF_FILE" "$RST"
echo ""
