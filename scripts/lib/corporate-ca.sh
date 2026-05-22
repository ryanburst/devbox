# Shared corporate TLS helpers (sourced by install-toolchain.sh, sync-zscaler-ca.sh, devbox CLI).
# Expects DEVBOX_ROOT to be set.

devbox_env_local() {
  printf '%s/config/env.local' "${DEVBOX_ROOT:?}"
}

devbox_corporate_ca_pem_path() {
  printf '%s/config/corporate-ca.pem' "${DEVBOX_ROOT:?}"
}

# Convert Windows Export-Certificate output (often DER) to PEM for curl/update-ca-certificates.
devbox_convert_cert_to_pem() {
  local src="$1" dest="$2"
  src="${src/#\~/$HOME}"

  [[ -f "$src" ]] || return 1
  command -v openssl >/dev/null 2>&1 || return 1

  if openssl x509 -in "$src" -inform PEM -noout 2>/dev/null; then
    openssl x509 -in "$src" -inform PEM -out "$dest" -outform PEM 2>/dev/null
    return 0
  fi
  if openssl x509 -in "$src" -inform DER -out "$dest" -outform PEM 2>/dev/null; then
    return 0
  fi
  return 1
}

# Normalize CA to config/corporate-ca.pem; update env.local. Prints PEM path on stdout.
devbox_prepare_corporate_ca() {
  local src="${1:-}"
  local pem subject
  pem="$(devbox_corporate_ca_pem_path)"

  if [[ -z "$src" ]]; then
    src="${DEVBOX_CA_CERT_FILE:-}"
  fi
  src="${src/#\~/$HOME}"
  [[ -n "$src" && -f "$src" ]] || return 1

  mkdir -p "$(dirname "$pem")"
  if ! devbox_convert_cert_to_pem "$src" "$pem"; then
    return 1
  fi
  chmod 600 "$pem" 2>/dev/null || true

  subject="$(openssl x509 -in "$pem" -noout -subject 2>/dev/null || true)"
  if [[ -z "$subject" ]]; then
    return 1
  fi

  devbox_write_ca_to_env_local "$pem" || return 1
  printf '%s' "$pem"
  return 0
}

devbox_export_ssl_certs() {
  local pem="${DEVBOX_CA_CERT_FILE:-}"
  pem="${pem/#\~/$HOME}"
  if [[ -z "$pem" || ! -f "$pem" ]]; then
    return 0
  fi
  if ! openssl x509 -in "$pem" -inform PEM -noout 2>/dev/null; then
    return 0
  fi
  export SSL_CERT_FILE="$pem"
  export NODE_EXTRA_CA_CERTS="$pem"
  export CURL_CA_BUNDLE="$pem"
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
  local pem out

  if ! pem="$(devbox_prepare_corporate_ca "$cert_file")"; then
    printf 'devbox: could not convert CA to PEM (invalid or missing openssl)\n' >&2
    printf 'devbox: try re-export: devbox setup tls\n' >&2
    printf 'devbox: check file: openssl x509 -in %s -inform DER -noout -subject\n' \
      "${cert_file:-$DEVBOX_CA_CERT_FILE}" >&2
    return 1
  fi

  if command -v update-ca-certificates >/dev/null 2>&1; then
    sudo cp "$pem" /usr/local/share/ca-certificates/devbox-corporate.crt
    sudo chmod 644 /usr/local/share/ca-certificates/devbox-corporate.crt
    out="$(sudo update-ca-certificates 2>&1)" || true
    printf '%s\n' "$out"
    if echo "$out" | grep -qE 'added: [1-9]'; then
      printf '==> corporate CA added to system trust store\n'
    else
      printf 'warning: update-ca-certificates reported 0 added — using PEM for curl/npm only\n' >&2
      printf 'warning: subject: %s\n' "$(openssl x509 -in "$pem" -noout -subject 2>/dev/null || echo unknown)" >&2
    fi
  else
    printf 'warning: update-ca-certificates not found — using PEM env vars only\n' >&2
  fi

  export DEVBOX_CA_CERT_FILE="$pem"
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
  local env_local pem
  env_local="$(devbox_env_local)"
  if [[ -f "$env_local" ]]; then
    # shellcheck source=/dev/null
    source "$env_local"
  fi
  # Re-normalize if env points at raw .cer from an older run
  if [[ -n "${DEVBOX_CA_CERT_FILE:-}" && -f "${DEVBOX_CA_CERT_FILE}" ]]; then
    if ! openssl x509 -in "${DEVBOX_CA_CERT_FILE}" -inform PEM -noout 2>/dev/null; then
      if pem="$(devbox_prepare_corporate_ca "$DEVBOX_CA_CERT_FILE" 2>/dev/null)"; then
        export DEVBOX_CA_CERT_FILE="$pem"
      fi
    fi
  fi
}
