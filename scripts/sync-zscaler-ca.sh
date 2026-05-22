#!/usr/bin/env bash
# One-time machine onboarding: export Zscaler CA from Windows into devbox config (WSL).
# Not used by application repos. See docs/CORPORATE-TLS.md.
set -euo pipefail

DEVBOX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/corporate-ca.sh
source "$DEVBOX_ROOT/scripts/lib/corporate-ca.sh"
PS_SCRIPT="$DEVBOX_ROOT/scripts/windows/Export-ZscalerCa.ps1"
DEST_CERT="$DEVBOX_ROOT/config/zscaler-root.cer"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'sync-zscaler-ca warning: %s\n' "$*" >&2; }
die() { printf 'sync-zscaler-ca: %s\n' "$*" >&2; exit 1; }

if ! grep -qi microsoft /proc/version 2>/dev/null; then
  die "run this from WSL (exports certs from the Windows certificate store)"
fi

find_powershell() {
  local candidate
  for candidate in \
    /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe \
    /mnt/c/Windows/System32/pwsh.exe; do
    if [[ -f "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

win_username() {
  local user
  user="$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n' || true)"
  [[ -n "$user" ]] || die "could not detect Windows username (cmd.exe unavailable)"
  printf '%s' "$user"
}

powershell_win_path() {
  local unix_path="$1"
  if command -v wslpath >/dev/null 2>&1; then
    wslpath -w "$unix_path"
    return 0
  fi
  die "wslpath not found — cannot invoke PowerShell with WSL path"
}

PS_EXE="$(find_powershell)" || die "PowerShell not found under /mnt/c/Windows/..."
WIN_USER="$(win_username)"
WIN_OUT="/mnt/c/Users/${WIN_USER}/.devbox/certs/zscaler-root.cer"
PS_FILE_WIN="$(powershell_win_path "$PS_SCRIPT")"

log "exporting Zscaler CA via Windows PowerShell"
"$PS_EXE" -NoProfile -ExecutionPolicy Bypass -File "$PS_FILE_WIN" | sed 's/\r$//'

[[ -f "$WIN_OUT" ]] || die "export failed: $WIN_OUT not created"

mkdir -p "$(dirname "$DEST_CERT")"
cp -f "$WIN_OUT" "$DEST_CERT"
chmod 600 "$DEST_CERT"
log "copied cert to $DEST_CERT"

# Optional bundle (multiple Zscaler certs)
WIN_BUNDLE="/mnt/c/Users/${WIN_USER}/.devbox/certs/zscaler-root.bundle.cer"
if [[ -f "$WIN_BUNDLE" ]]; then
  cp -f "$WIN_BUNDLE" "$DEVBOX_ROOT/config/zscaler-root.bundle.cer"
  chmod 600 "$DEVBOX_ROOT/config/zscaler-root.bundle.cer"
  log "copied bundle to config/zscaler-root.bundle.cer"
fi

log "converting CA to PEM (Windows .cer is often DER)..."
if ! devbox_prepare_corporate_ca "$DEST_CERT" >/dev/null; then
  die "could not convert $DEST_CERT to PEM — install openssl: sudo apt install -y openssl"
fi
log "normalized CA: $(devbox_corporate_ca_pem_path)"
log "updated $(devbox_env_local)"

log "done — run: devbox setup tls   (after: bash install.sh)"
