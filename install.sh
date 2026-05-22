#!/usr/bin/env bash
# devbox — install the devbox CLI on PATH. Run devbox setup for toolchain (Node, pnpm, TLS).
set -euo pipefail

DEVBOX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
usage: bash install.sh [options]

  Installs the devbox CLI to ~/.local/bin and prepares ~/code.
  Does not install Node, pnpm, or corporate TLS — use devbox setup for that.

options:
  --toolchain   Run full toolchain install (same as devbox setup step 2)
  -h, --help    Show this help
EOF
}

install_apt_minimal() {
  if ! command -v apt-get >/dev/null 2>&1; then
    return 0
  fi
  if command -v curl >/dev/null 2>&1; then
    return 0
  fi
  log "installing curl for devbox setup (sudo may prompt)"
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates
}

install_devbox_cli() {
  mkdir -p "$HOME/.local/bin"
  ln -sf "$DEVBOX_ROOT/bin/devbox" "$HOME/.local/bin/devbox"
  chmod 755 "$DEVBOX_ROOT/bin/devbox"
  log "devbox CLI linked to ~/.local/bin/devbox"
}

ensure_workspace() {
  local code_dir="${DEVBOX_CODE_DIR:-$HOME/code}"
  mkdir -p "$code_dir"
  log "workspace: $code_dir"
}

patch_shell_rc_cli() {
  local marker="# devbox"
  local rc="$HOME/.bashrc"
  [[ -f "$rc" ]] || touch "$rc"
  if grep -qF "$marker" "$rc" 2>/dev/null; then
    log "shell already has devbox CLI block ($rc)"
    return 0
  fi
  cat >>"$rc" <<EOF

$marker
export DEVBOX_ROOT="$DEVBOX_ROOT"
export PATH="\$HOME/.local/bin:\$PATH"
[[ -f "\$DEVBOX_ROOT/config/env.local" ]] && source "\$DEVBOX_ROOT/config/env.local"
EOF
  log "updated $rc (CLI only — devbox setup adds fnm)"
}

install_cli() {
  if grep -qi microsoft /proc/version 2>/dev/null; then
    log "WSL detected"
  else
    warn "not running under WSL — continuing anyway"
  fi
  log "devbox CLI install (root: $DEVBOX_ROOT)"
  install_apt_minimal
  install_devbox_cli
  ensure_workspace
  patch_shell_rc_cli
  log "done — run: exec bash"
  log "next: devbox setup   (TLS, Node, pnpm, turbo)"
}

main() {
  case "${1:-}" in
    -h | --help)
      usage
      exit 0
      ;;
    --toolchain)
      shift
      exec bash "$DEVBOX_ROOT/scripts/install-toolchain.sh" "$@"
      ;;
    "")
      install_cli
      ;;
    *)
      die "unknown option: $1 (try: bash install.sh --help)"
      ;;
  esac
}

main "$@"
