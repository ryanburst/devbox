#!/usr/bin/env bash
# Sync dev hostnames from WSL /etc/hosts to Windows hosts (for Edge/Chrome on Windows).
# WSL reads /etc/hosts; elevated PowerShell only edits Windows hosts (no wsl in Admin).
set -euo pipefail

DEVBOX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PS_SCRIPT="$DEVBOX_ROOT/scripts/windows/Sync-DevHostsFromWsl.ps1"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
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

# Extract dev lines from WSL /etc/hosts (same rules as Sync-DevHostsFromWsl.ps1)
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
log "opening elevated PowerShell (UAC) — Admin session does not use WSL"
log "approve the prompt, then check the green success message in the Admin window"

"$PS_EXE" -NoProfile -ExecutionPolicy Bypass -File "$PS_FILE_WIN" -InputFile "$LINES_FILE_WIN"

log "done — if the Admin window reported success, test in Windows browser"
log "optional (Admin PowerShell): ipconfig /flushdns"
