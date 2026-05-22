# Shared corporate TLS helpers (sourced by install.sh, sync-zscaler-ca.sh, devbox CLI).
# Expects DEVBOX_ROOT to be set.

devbox_env_local() {
  printf '%s/config/env.local' "${DEVBOX_ROOT:?}"
}

devbox_export_ssl_certs() {
  if [[ -n "${DEVBOX_CA_CERT_FILE:-}" && -f "$DEVBOX_CA_CERT_FILE" ]]; then
    export SSL_CERT_FILE="$DEVBOX_CA_CERT_FILE"
    export NODE_EXTRA_CA_CERTS="$DEVBOX_CA_CERT_FILE"
    export CURL_CA_BUNDLE="$DEVBOX_CA_CERT_FILE"
  fi
}

devbox_write_ca_to_env_local() {
  local cert_path="$1"
  local env_local
  env_local="$(devbox_env_local)"
  cert_path="${cert_path/#\~/$HOME}"

  [[ -f "$cert_path" ]] || return 1

  mkdir -p "$(dirname "$env_local")"
  touch "$env_local"
  chmod 600 "$env_local" 2>/dev/null || true

  if grep -q '^DEVBOX_CA_CERT_FILE=' "$env_local" 2>/dev/null; then
    if command -v sed >/dev/null 2>&1; then
      sed -i "s|^DEVBOX_CA_CERT_FILE=.*|export DEVBOX_CA_CERT_FILE=$cert_path|" "$env_local"
    else
      return 1
    fi
  else
    {
      echo "# Corporate CA — set by devbox"
      echo "export DEVBOX_CA_CERT_FILE=$cert_path"
    } >>"$env_local"
  fi
  chmod 600 "$env_local"
  export DEVBOX_CA_CERT_FILE="$cert_path"
  return 0
}

devbox_apply_corporate_ca() {
  local cert_file="${1:-${DEVBOX_CA_CERT_FILE:-}}"
  cert_file="${cert_file/#\~/$HOME}"
  [[ -n "$cert_file" && -f "$cert_file" ]] || return 1

  if command -v update-ca-certificates >/dev/null 2>&1; then
    sudo cp "$cert_file" /usr/local/share/ca-certificates/devbox-corporate.crt
    sudo chmod 644 /usr/local/share/ca-certificates/devbox-corporate.crt
    sudo update-ca-certificates
  fi
  devbox_export_ssl_certs
  return 0
}

devbox_test_https() {
  devbox_export_ssl_certs
  curl -fsSL --max-time 15 https://nodejs.org/dist/index.json >/dev/null 2>&1
}

devbox_wsl_interop_available() {
  grep -qi microsoft /proc/version 2>/dev/null \
    && [[ -f /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe ]]
}

devbox_load_env_local() {
  local env_local
  env_local="$(devbox_env_local)"
  if [[ -f "$env_local" ]]; then
    # shellcheck source=/dev/null
    source "$env_local"
  fi
}
