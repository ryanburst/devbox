#!/usr/bin/env bash
# Reset devbox machine install (reverse install.sh + optional toolchain from devbox setup).
set -euo pipefail

DEVBOX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'reset-devbox: %s\n' "$*" >&2; exit 1; }

RESET_FULL=0
RESET_YES=0
RESET_KEEP_CODE=1

usage() {
  cat <<EOF
usage: devbox reset [options]

  Undo devbox install on this machine (CLI, shell config; optional full toolchain).

options:
  --full        Also remove fnm, global pnpm/turbo, pnpm store, corporate CA
  --yes, -y     Skip confirmation prompts
  --keep-code   Keep ~/code (default)
  --purge-code  Remove ~/code directory
  -h, --help    Show this help

Does not delete the devbox git clone at DEVBOX_ROOT.
After reset, run: bash install.sh && devbox setup
EOF
}

prompt_confirm() {
  local msg="$1"
  if [[ "$RESET_YES" == "1" ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    die "refusing to reset without --yes (non-interactive)"
  fi
  local reply
  printf '%s [y/N] ' "$msg"
  read -r reply </dev/tty || die "read failed"
  reply="$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')"
  [[ "$reply" == "y" || "$reply" == "yes" ]]
}

remove_bashrc_devbox_blocks() {
  local rc="$HOME/.bashrc"
  [[ -f "$rc" ]] || return 0
  if ! grep -qE '^# devbox' "$rc" 2>/dev/null; then
    log "no devbox blocks in $rc"
    return 0
  fi
  cp "$rc" "${rc}.bak.$(date +%Y%m%d%H%M%S)"
  local tmp
  tmp="$(mktemp)"
  awk '
    BEGIN { skip = 0 }
    /^# devbox/ { skip = 1; next }
    skip && /^[[:space:]]*$/ { skip = 0; next }
    skip { next }
    { print }
  ' "$rc" >"$tmp"
  mv "$tmp" "$rc"
  log "removed devbox blocks from $rc (backup saved)"
}

remove_devbox_cli() {
  if [[ -L "$HOME/.local/bin/devbox" || -f "$HOME/.local/bin/devbox" ]]; then
    rm -f "$HOME/.local/bin/devbox"
    log "removed ~/.local/bin/devbox"
  else
    log "no ~/.local/bin/devbox symlink"
  fi
}

remove_corporate_ca() {
  if [[ -f /usr/local/share/ca-certificates/devbox-corporate.crt ]]; then
    if prompt_confirm "Remove devbox corporate CA from system trust (sudo)?"; then
      sudo rm -f /usr/local/share/ca-certificates/devbox-corporate.crt
      if command -v update-ca-certificates >/dev/null 2>&1; then
        sudo update-ca-certificates --fresh 2>/dev/null || sudo update-ca-certificates
      fi
      log "removed devbox-corporate.crt from system trust"
    fi
  fi
}

remove_toolchain() {
  log "toolchain cleanup (--full)"

  if [[ -d "$HOME/.local/share/fnm" || -d "$HOME/.fnm" ]]; then
    rm -rf "$HOME/.local/share/fnm" "$HOME/.fnm"
    log "removed fnm directories"
  fi

  if [[ -d "$HOME/.local/state/fnm" ]]; then
    rm -rf "$HOME/.local/state/fnm"
    log "removed ~/.local/state/fnm"
  fi

  if command -v npm >/dev/null 2>&1; then
    npm uninstall -g pnpm turbo 2>/dev/null || warn "could not npm uninstall -g pnpm turbo"
  fi

  if [[ -f "$HOME/.local/bin/just" ]]; then
    rm -f "$HOME/.local/bin/just"
    log "removed ~/.local/bin/just"
  fi

  for wrapper in docker docker-compose; do
    if [[ -L "$HOME/.local/bin/$wrapper" || -f "$HOME/.local/bin/$wrapper" ]]; then
      case "$wrapper" in
        docker | docker-compose)
          if [[ -L "$HOME/.local/bin/$wrapper" ]] \
            && readlink "$HOME/.local/bin/$wrapper" 2>/dev/null | grep -q 'docker-desktop'; then
            rm -f "$HOME/.local/bin/$wrapper"
            log "removed ~/.local/bin/$wrapper"
          elif [[ -f "$HOME/.local/bin/$wrapper" ]] \
            && grep -q 'docker.exe' "$HOME/.local/bin/$wrapper" 2>/dev/null; then
            rm -f "$HOME/.local/bin/$wrapper"
            log "removed ~/.local/bin/$wrapper (windows exe wrapper)"
          fi
          ;;
      esac
    fi
  done

  if [[ -d "$HOME/.pnpm-store" ]]; then
    if prompt_confirm "Remove pnpm store at ~/.pnpm-store?"; then
      rm -rf "$HOME/.pnpm-store"
      log "removed ~/.pnpm-store"
    fi
  fi

  remove_corporate_ca

  local env_local="$DEVBOX_ROOT/config/env.local"
  if [[ -f "$env_local" ]] && prompt_confirm "Remove $env_local?"; then
    rm -f "$env_local"
    log "removed config/env.local"
  fi
}

remove_code_dir() {
  local code_dir="${DEVBOX_CODE_DIR:-$HOME/code}"
  if [[ -d "$code_dir" ]]; then
    if prompt_confirm "Remove workspace directory $code_dir?"; then
      rm -rf "$code_dir"
      log "removed $code_dir"
    fi
  fi
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --full) RESET_FULL=1; shift ;;
      --yes | -y) RESET_YES=1; shift ;;
      --keep-code) RESET_KEEP_CODE=1; shift ;;
      --purge-code) RESET_KEEP_CODE=0; shift ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
  done

  printf 'devbox reset — undo machine install (clone at %s is kept)\n' "$DEVBOX_ROOT"
  if [[ "$RESET_FULL" == "1" ]]; then
    printf '  Mode: full (CLI + shell + toolchain)\n'
  else
    printf '  Mode: CLI + shell only (use --full for fnm/pnpm/CA)\n'
  fi

  if ! prompt_confirm "Continue?"; then
    printf 'Cancelled.\n'
    exit 0
  fi

  remove_devbox_cli
  remove_bashrc_devbox_blocks

  if [[ "$RESET_FULL" == "1" ]]; then
    remove_toolchain
  fi

  if [[ "$RESET_KEEP_CODE" == "0" ]]; then
    remove_code_dir
  fi

  if grep -qi microsoft /proc/version 2>/dev/null; then
    warn "optional: remove Windows export dir: rm -rf /mnt/c/Users/<you>/.devbox"
  fi

  log "reset complete"
  log "next: exec bash"
  log "then:  cd ~/devbox && bash install.sh && devbox setup"
}

main "$@"
