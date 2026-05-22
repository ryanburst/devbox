#!/usr/bin/env bash
# devbox one-time WSL2 bootstrap: fnm, Node 22, pnpm, turbo, workspace layout.
set -euo pipefail

DEVBOX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE_VERSION="${DEVBOX_NODE_VERSION:-22}"
PNPM_STORE="${DEVBOX_PNPM_STORE:-$HOME/.pnpm-store}"
CODE_DIR="${DEVBOX_CODE_DIR:-$HOME/code}"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

if grep -qi microsoft /proc/version 2>/dev/null; then
  log "WSL detected"
else
  warn "not running under WSL — continuing anyway (Linux/macOS dev installs are fine)"
fi

if ! command -v curl >/dev/null 2>&1; then
  die "curl is required; run: sudo apt install -y curl"
fi

# Optional corporate overrides (copy config/env.example → config/env.local)
ENV_LOCAL="$DEVBOX_ROOT/config/env.local"
if [[ -f "$ENV_LOCAL" ]]; then
  # shellcheck source=/dev/null
  source "$ENV_LOCAL"
  log "loaded $ENV_LOCAL"
fi

install_apt_baseline() {
  if ! command -v apt-get >/dev/null 2>&1; then
    warn "apt-get not found — skip system packages"
    return 0
  fi
  log "installing system packages (sudo may prompt)"
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl git ca-certificates unzip build-essential
}

install_fnm() {
  if command -v fnm >/dev/null 2>&1; then
    log "fnm already installed"
    return 0
  fi
  log "installing fnm"
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
}

activate_fnm() {
  export PATH="${HOME}/.local/share/fnm:${HOME}/.fnm:${PATH}"
  if [[ -d "${HOME}/.local/share/fnm" ]]; then
    eval "$(fnm env --shell bash)"
  elif [[ -d "${HOME}/.fnm" ]]; then
    eval "$(fnm env --shell bash)"
  else
    die "fnm install did not complete — check network/proxy settings"
  fi
}

install_node_stack() {
  activate_fnm
  log "installing Node ${NODE_VERSION}"
  fnm install "$NODE_VERSION"
  fnm use "$NODE_VERSION"
  fnm default "$NODE_VERSION"
  node -v
  npm -v
}

install_global_tools() {
  activate_fnm
  log "installing pnpm and turbo"
  if [[ "${DEVBOX_NPM_STRICT_SSL:-}" == "false" ]]; then
    npm config set strict-ssl false
    warn "npm strict-ssl disabled (corporate TLS inspection workaround)"
  fi
  npm install -g pnpm turbo
  pnpm -v
  turbo --version
}

configure_pnpm() {
  activate_fnm
  mkdir -p "$PNPM_STORE"
  pnpm config set store-dir "$PNPM_STORE"
  log "pnpm store: $(pnpm config get store-dir)"
}

ensure_workspace() {
  mkdir -p "$CODE_DIR"
  log "workspace: $CODE_DIR"
}

install_devbox_cli() {
  mkdir -p "$HOME/.local/bin"
  ln -sf "$DEVBOX_ROOT/bin/devbox" "$HOME/.local/bin/devbox"
  log "devbox CLI linked to ~/.local/bin/devbox"
}

patch_shell_rc() {
  local marker="# devbox"
  local rc="$HOME/.bashrc"
  [[ -f "$rc" ]] || touch "$rc"
  if grep -qF "$marker" "$rc" 2>/dev/null; then
    log "shell already configured ($rc)"
    return 0
  fi
  cat >>"$rc" <<EOF

$marker
export DEVBOX_ROOT="$DEVBOX_ROOT"
export PATH="\$HOME/.local/bin:\$HOME/.local/share/fnm:\$PATH"
if command -v fnm >/dev/null 2>&1; then
  eval "\$(fnm env --shell bash)"
fi
EOF
  log "updated $rc"
}

main() {
  log "devbox install (root: $DEVBOX_ROOT)"
  install_apt_baseline
  install_fnm
  install_node_stack
  install_global_tools
  configure_pnpm
  ensure_workspace
  install_devbox_cli
  patch_shell_rc
  log "done — run: exec bash   then: devbox doctor"
}

main "$@"
