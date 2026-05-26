# Interactive setup (sourced by bin/devbox). Expects DEVBOX_ROOT, die, warn, log helpers.

DEVBOX_SETUP_NONINTERACTIVE="${DEVBOX_SETUP_NONINTERACTIVE:-0}"

devbox_is_tty() {
  [[ -t 0 && -t 1 ]]
}

devbox_prompt_yn() {
  local prompt="$1" default="${2:-n}" reply
  if [[ "$DEVBOX_SETUP_NONINTERACTIVE" == "1" ]]; then
    [[ "$default" == "y" ]]
    return
  fi
  if ! devbox_is_tty; then
    [[ "$default" == "y" ]]
    return
  fi
  local hint="y/N"
  [[ "$default" == "y" ]] && hint="Y/n"
  while true; do
    printf '%s [%s] ' "$prompt" "$hint"
    read -r reply </dev/tty || return 1
    reply="${reply:-$default}"
    reply="$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')"
    case "$reply" in
      y | yes) return 0 ;;
      n | no) return 1 ;;
      *) printf '  Enter y or n.\n' ;;
    esac
  done
}

devbox_prompt_choice() {
  local reply
  if ! devbox_is_tty; then
    printf '%s' "${1:-1}"
    return 0
  fi
  printf '%s\n' "$2"
  printf 'Choice: '
  read -r reply </dev/tty || return 1
  printf '%s' "$reply"
}

devbox_step_tls_status() {
  if devbox_test_https; then
    printf '  TLS: ok (nodejs.org reachable)\n'
    return 0
  fi
  printf '  TLS: failed (corporate inspection / missing CA)\n'
  return 1
}

devbox_setup_tls_interactive() {
  local choice cert_path win_user win_cert

  printf '\n── Corporate TLS ──\n'

  if devbox_step_tls_status; then
    if devbox_prompt_yn "Re-apply CA from config/env.local anyway?" n; then
      devbox_load_env_local
      if [[ -n "${DEVBOX_CA_CERT_FILE:-}" ]]; then
        devbox_apply_corporate_ca "$DEVBOX_CA_CERT_FILE" \
          && printf '  Applied CA: %s\n' "$DEVBOX_CA_CERT_FILE" \
          || warn "could not apply $DEVBOX_CA_CERT_FILE"
      fi
    fi
    return 0
  fi

  printf '\nHTTPS is failing. Common on Zscaler / corporate proxies.\n\n'

  if devbox_wsl_interop_available; then
    choice="$(devbox_prompt_choice "1" \
      "  1) Export Zscaler CA from Windows (recommended)
  2) Use an existing certificate file
  3) Copy from Windows user .devbox/certs (if you exported on host)
  4) Skip for now")"
  else
    choice="$(devbox_prompt_choice "2" \
      "  1) Use an existing certificate file
  2) Skip for now")"
    [[ "$choice" == "1" ]] && choice="2"
    [[ "$choice" == "2" ]] && choice="4"
  fi

  case "$choice" in
    1)
      printf '\nRunning Zscaler export...\n'
      bash "$DEVBOX_ROOT/scripts/sync-zscaler-ca.sh" || warn "Zscaler export failed"
      devbox_load_env_local
      ;;
    2)
      printf 'Path to .cer or .pem (e.g. ~/devbox/config/company-root.cer): '
      read -r cert_path </dev/tty || return 1
      cert_path="${cert_path/#\~/$HOME}"
      [[ -f "$cert_path" ]] || die "file not found: $cert_path"
      devbox_prepare_corporate_ca "$cert_path" >/dev/null \
        || die "invalid cert or openssl missing — install: sudo apt install -y openssl"
      printf '  Normalized CA to config/corporate-ca.pem\n'
      ;;
    3)
      win_user="$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n' || true)"
      [[ -n "$win_user" ]] || die "could not detect Windows username"
      win_cert="/mnt/c/Users/${win_user}/.devbox/certs/zscaler-root.cer"
      [[ -f "$win_cert" ]] || die "not found: $win_cert — export on Windows first"
      mkdir -p "$DEVBOX_ROOT/config"
      cp -f "$win_cert" "$DEVBOX_ROOT/config/zscaler-root.cer"
      chmod 600 "$DEVBOX_ROOT/config/zscaler-root.cer"
      devbox_prepare_corporate_ca "$DEVBOX_ROOT/config/zscaler-root.cer" >/dev/null \
        || die "could not convert cert to PEM — install openssl"
      printf '  Copied cert and wrote config/corporate-ca.pem\n'
      ;;
    4 | *)
      warn "skipped TLS setup — install/fnm may fail until CA is configured"
      return 0
      ;;
  esac

  devbox_load_env_local
  if [[ -n "${DEVBOX_CA_CERT_FILE:-}" ]]; then
    printf '\nInstalling CA into WSL trust store (sudo)...\n'
    devbox_apply_corporate_ca "$DEVBOX_CA_CERT_FILE" \
      || warn "could not install CA into system store"
  fi

  printf '\nVerifying HTTPS...\n'
  if devbox_test_https; then
    printf '  TLS: ok\n'
  else
    warn "TLS still failing — see docs/CORPORATE-TLS.md"
    return 1
  fi
}

devbox_setup_wizard() {
  printf 'devbox setup — machine bootstrap wizard\n'
  printf 'Prepares WSL for any repo under ~/code (devbox not required per project).\n\n'

  if grep -qi microsoft /proc/version 2>/dev/null; then
    printf '  Environment: WSL2\n'
  else
    warn "not detected as WSL — wizard is intended for WSL on corporate Windows"
  fi

  devbox_load_env_local

  printf '\n── Step 1: Corporate TLS ──\n'
  if ! devbox_step_tls_status; then
    devbox_setup_tls_interactive || true
  else
    printf '  Skipping — HTTPS already works.\n'
    if [[ -f "$(devbox_env_local)" ]] && grep -q DEVBOX_CA_CERT_FILE "$(devbox_env_local)" 2>/dev/null; then
      if devbox_prompt_yn "Apply configured CA to system trust store?" y; then
        devbox_apply_corporate_ca "${DEVBOX_CA_CERT_FILE:-}" || warn "apply failed"
      fi
    fi
  fi

  printf '\n── Step 2: Toolchain (Node, pnpm, just, turbo) ──\n'
  if command -v node >/dev/null 2>&1 && command -v pnpm >/dev/null 2>&1 && command -v just >/dev/null 2>&1; then
    printf '  node: %s\n' "$(node -v 2>/dev/null || echo missing)"
    printf '  pnpm: %s\n' "$(pnpm -v 2>/dev/null || echo missing)"
    printf '  just: %s\n' "$(just --version 2>/dev/null || echo missing)"
    if devbox_prompt_yn "Re-run toolchain install to refresh pinned versions?" n; then
      bash "$DEVBOX_ROOT/scripts/install-toolchain.sh"
    fi
  else
    if devbox_prompt_yn "Install toolchain now? (Node, pnpm, just, turbo)" y; then
      bash "$DEVBOX_ROOT/scripts/install-toolchain.sh"
    else
      warn "skipped toolchain — run: devbox setup"
    fi
  fi

  printf '\n── Step 3: Shell (fnm in ~/.bashrc) ──\n'
  if grep -q 'fnm env' "$HOME/.bashrc" 2>/dev/null; then
    printf '  ~/.bashrc already configures fnm\n'
  elif devbox_prompt_yn "Add fnm to ~/.bashrc?" y; then
    DEVBOX_PATCH_SHELL=1 bash "$DEVBOX_ROOT/scripts/install-toolchain.sh"
  fi

  printf '\n── Step 4: Docker Desktop (WSL) ──\n'
  if devbox_docker_working && devbox_docker_compose_working; then
    printf '  docker: ok (Docker Desktop)\n'
  else
    if devbox_prompt_yn "Configure docker for Docker Desktop on Windows?" y; then
      devbox_configure_docker || warn "docker not ready — see docs/DOCKER.md"
    else
      warn "skipped docker — repos using docker compose will need: devbox setup docker"
    fi
  fi

  printf '\n── Step 5: Health check ──\n'
  cmd_doctor

  printf '\nSetup complete. Clone any team repo:\n'
  printf '  cd ~/code && git clone <url> && cd <repo> && pnpm install\n'
}

devbox_interactive_menu() {
  local choice
  printf 'devbox — interactive menu\n\n'
  choice="$(devbox_prompt_choice "1" \
    "  1) Setup wizard (new machine)
  2) Corporate TLS / Zscaler
  3) Install toolchain only
  4) Docker Desktop (WSL)
  5) doctor
  6) list repos in ~/code
  7) Reset devbox install
  8) help
  9) Exit")"

  case "$choice" in
    1) devbox_setup_wizard ;;
    2) devbox_setup_tls_interactive ;;
    3) bash "$DEVBOX_ROOT/scripts/install-toolchain.sh" ;;
    4) devbox_configure_docker || true ;;
    5) cmd_doctor ;;
    6) cmd_list ;;
    7) bash "$DEVBOX_ROOT/scripts/reset-devbox.sh" ;;
    8) usage ;;
    9 | q) exit 0 ;;
    *) die "invalid choice: $choice" ;;
  esac
}
