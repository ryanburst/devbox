#!/usr/bin/env bash
# Sync dev hostnames from WSL /etc/hosts to Windows hosts (for Edge/Chrome on Windows).
# Prepares %LOCALAPPDATA%\devbox\ for corporate "Run with elevated access" (no domain UAC).
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

win_username() {
  local user
  user="$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n' || true)"
  [[ -n "$user" ]] || die "could not detect Windows username"
  printf '%s' "$user"
}

powershell_win_path() {
  wslpath -w "$1"
}

extract_dev_host_lines() {
  local line trimmed
  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="${line#"${line%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue
    [[ "$trimmed" =~ ^127\.0\.0\.1[[:space:]]+localhost([[:space:]]|$) ]] && continue
    [[ "$trimmed" =~ ^::1[[:space:]] ]] && continue
    if [[ "$trimmed" == *".local"* ]] || [[ "$trimmed" =~ ^127\.0\.0\.1[[:space:]]+[^[:space:]] ]]; then
      printf '%s\n' "$trimmed"
    fi
  done < /etc/hosts
}

PS_EXE="$(find_powershell)" || die "PowerShell not found"
PS_FILE_WIN="$(powershell_win_path "$PS_SCRIPT")"
WIN_USER="$(win_username)"
LINES_FILE="/mnt/c/Users/${WIN_USER}/AppData/Local/Temp/devbox-hosts-lines.txt"
DEVBOX_WIN="/mnt/c/Users/${WIN_USER}/AppData/Local/devbox"
mkdir -p "$(dirname "$LINES_FILE")"

log "reading dev entries from WSL /etc/hosts"
if ! extract_dev_host_lines | sort -u >"$LINES_FILE"; then
  die "could not read /etc/hosts"
fi
if [[ ! -s "$LINES_FILE" ]]; then
  die "no dev host lines in /etc/hosts — run repo setup first (e.g. just setup)"
fi

log "entries to sync:"
sed 's/^/  /' "$LINES_FILE"

LINES_FILE_WIN="$(powershell_win_path "$LINES_FILE")"
log "preparing Windows hosts bundle (no domain-admin UAC)"

"$PS_EXE" -NoProfile -ExecutionPolicy Bypass -File "$PS_FILE_WIN" \
  -InputFile "$LINES_FILE_WIN" -PrepareOnly

log ""
log "On Windows: right-click apply-dev-hosts.cmd → Run with elevated access"
log "If the window closes, read: %LOCALAPPDATA%\\devbox\\apply-dev-hosts.log"
log "Folder: $(wslpath -w "$DEVBOX_WIN" 2>/dev/null || echo "%LOCALAPPDATA%\\devbox")"
log "Optional after success: ipconfig /flushdns"
