#!/usr/bin/env bash
# Sync dev hostnames from WSL /etc/hosts to Windows hosts (for Edge/Chrome on Windows).
set -euo pipefail

DEVBOX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PS_SCRIPT="$DEVBOX_ROOT/scripts/windows/Sync-DevHostsFromWsl.ps1"

log() { printf '==> %s\n' "$*"; }
die() { printf 'sync-hosts-to-windows: %s\n' "$*" >&2; exit 1; }

if ! grep -qi microsoft /proc/version 2>/dev/null; then
  die "run from WSL on Windows"
fi

find_powershell() {
  local c
  for c in \
    /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe \
    /mnt/c/Windows/System32/pwsh.exe; do
    [[ -f "$c" ]] && printf '%s' "$c" && return 0
  done
  return 1
}

powershell_win_path() {
  wslpath -w "$1"
}

PS_EXE="$(find_powershell)" || die "PowerShell not found"
PS_FILE_WIN="$(powershell_win_path "$PS_SCRIPT")"

log "syncing dev hosts from WSL /etc/hosts to Windows (UAC prompt)"
log "preview in WSL: grep -E '\\.local|127\\.0\\.0\\.1' /etc/hosts | grep -v localhost"

"$PS_EXE" -NoProfile -ExecutionPolicy Bypass -File "$PS_FILE_WIN" ${WSL_DISTRO_NAME:+-Distro "$WSL_DISTRO_NAME"}

log "done — open URLs in Windows browser (not only inside WSL)"
