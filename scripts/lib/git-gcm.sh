# Wire WSL git to Git Credential Manager on Windows (HTTPS + browser SSO).
# Expects nothing; safe to source from devbox doctor / setup.

devbox_find_windows_gcm() {
  local candidate
  for candidate in \
    "/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe" \
    "/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager-core.exe" \
    "/mnt/c/Program Files (x86)/Git/mingw64/bin/git-credential-manager.exe"; do
    if [[ -f "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

devbox_configure_git_gcm() {
  local gcm current
  if ! grep -qi microsoft /proc/version 2>/dev/null; then
    printf 'devbox: Git GCM wiring is for WSL only\n' >&2
    return 1
  fi
  if ! command -v git >/dev/null 2>&1; then
    printf 'devbox: git not found — sudo apt install -y git\n' >&2
    return 1
  fi
  gcm="$(devbox_find_windows_gcm)" || {
    printf 'devbox: Git Credential Manager not found under /mnt/c/Program Files/Git/\n' >&2
    printf 'devbox: install Git for Windows and choose the GCM credential helper\n' >&2
    return 1
  fi
  current="$(git config --global --get credential.helper 2>/dev/null || true)"
  if [[ "$current" == "$gcm" ]]; then
    return 0
  fi
  git config --global credential.helper "$gcm"
  git config --global credential.https://dev.azure.com.useHttpPath true
  return 0
}

devbox_git_gcm_status() {
  local gcm current
  if ! command -v git >/dev/null 2>&1; then
    printf 'missing'
    return 1
  fi
  current="$(git config --global --get credential.helper 2>/dev/null || true)"
  gcm="$(devbox_find_windows_gcm 2>/dev/null || true)"
  if [[ -n "$gcm" && "$current" == "$gcm" ]]; then
    printf 'ok'
    return 0
  fi
  if [[ -z "$current" || "$current" == "store" || "$current" == "cache" ]]; then
    printf 'not configured (WSL git will not open browser SSO)'
    return 1
  fi
  if [[ -n "$gcm" ]]; then
    printf 'custom helper (expected Windows GCM): %s' "$current"
    return 1
  fi
  printf 'helper=%s (Windows GCM not found)' "${current:-<unset>}"
  return 1
}
