# Wire WSL git to Git Credential Manager on Windows (HTTPS + browser SSO).
# Expects nothing; safe to source from devbox doctor / setup.

devbox_gcm_wrapper_path() {
  printf '%s/.local/bin/git-credential-manager' "${HOME:?}"
}

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

devbox_install_gcm_wrapper() {
  local gcm="$1" wrapper
  wrapper="$(devbox_gcm_wrapper_path)"
  mkdir -p "$(dirname "$wrapper")"
  cat >"$wrapper" <<EOF
#!/usr/bin/env sh
# devbox — forwards to Windows Git Credential Manager (path may contain spaces)
exec "$gcm" "\$@"
EOF
  chmod 755 "$wrapper"
  printf '%s' "$wrapper"
}

devbox_configure_git_gcm() {
  local gcm wrapper current
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
  }
  wrapper="$(devbox_install_gcm_wrapper "$gcm")"
  current="$(git config --global --get credential.helper 2>/dev/null || true)"
  if [[ "$current" == "$wrapper" ]]; then
    return 0
  fi
  git config --global credential.helper "$wrapper"
  git config --global credential.https://dev.azure.com.useHttpPath true
  return 0
}

devbox_git_gcm_status() {
  local gcm current wrapper expected
  if ! command -v git >/dev/null 2>&1; then
    printf 'missing'
    return 1
  fi
  current="$(git config --global --get credential.helper 2>/dev/null || true)"
  wrapper="$(devbox_gcm_wrapper_path)"
  gcm="$(devbox_find_windows_gcm 2>/dev/null || true)"
  expected="$wrapper"

  if [[ "$current" == "$expected" && -x "$expected" ]]; then
    printf 'ok'
    return 0
  fi
  # Legacy broken config: unquoted path under /mnt/c/Program Files/...
  if [[ "$current" == *"/mnt/c/Program"* ]]; then
    printf 'broken (path has spaces — run: devbox setup git)'
    return 1
  fi
  if [[ -z "$current" || "$current" == "store" || "$current" == "cache" ]]; then
    printf 'not configured (WSL git will not open browser SSO)'
    return 1
  fi
  if [[ -n "$gcm" ]]; then
    printf 'custom helper (expected %s): %s' "$expected" "$current"
    return 1
  fi
  printf 'helper=%s (Windows GCM not found)' "${current:-<unset>}"
  return 1
}
