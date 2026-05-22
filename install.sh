#!/usr/bin/env bash
# devbox — one-time WSL2 machine bootstrap (not required inside application repos).
set -euo pipefail

DEVBOX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config/versions.sh
source "$DEVBOX_ROOT/config/versions.sh"
# shellcheck source=scripts/lib/corporate-ca.sh
source "$DEVBOX_ROOT/scripts/lib/corporate-ca.sh"

NODE_VERSION="${DEVBOX_NODE_VERSION:-$NODE_VERSION_DEFAULT}"
PNPM_STORE="${DEVBOX_PNPM_STORE:-$HOME/.pnpm-store}"
CODE_DIR="${DEVBOX_CODE_DIR:-$HOME/code}"
FNM_INSTALL_DIR="${HOME}/.local/share/fnm"

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

verify_sha256() {
  local file="$1" expected="$2"
  local actual
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$file" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  else
    die "sha256sum or shasum required to verify fnm download"
  fi
  [[ "$actual" == "$expected" ]] || die "checksum mismatch for $file (expected $expected)"
}

install_fnm() {
  if command -v fnm >/dev/null 2>&1; then
    log "fnm already installed ($(fnm --version 2>/dev/null || true))"
    return 0
  fi

  local arch asset expected tmp zip_url
  arch="$(uname -m)"
  case "$arch" in
    x86_64 | amd64)
      asset="fnm-linux.zip"
      expected="$FNM_SHA256_LINUX"
      ;;
    aarch64 | arm64)
      asset="fnm-arm64.zip"
      expected="$FNM_SHA256_ARM64"
      ;;
    *)
      die "unsupported architecture for fnm: $arch"
      ;;
  esac

  zip_url="https://github.com/Schniz/fnm/releases/download/v${FNM_VERSION}/${asset}"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  log "installing fnm v${FNM_VERSION} (${asset})"
  curl -fsSL "$zip_url" -o "$tmp/fnm.zip"
  verify_sha256 "$tmp/fnm.zip" "$expected"

  mkdir -p "$FNM_INSTALL_DIR"
  unzip -oq "$tmp/fnm.zip" -d "$FNM_INSTALL_DIR"
  chmod 755 "$FNM_INSTALL_DIR/fnm" 2>/dev/null || chmod 755 "$FNM_INSTALL_DIR"/fnm* 2>/dev/null || true
  export PATH="$FNM_INSTALL_DIR:$PATH"
  hash -r 2>/dev/null || true
  command -v fnm >/dev/null 2>&1 || die "fnm binary missing after extract"
  log "fnm installed to $FNM_INSTALL_DIR"
}

activate_fnm() {
  export PATH="${FNM_INSTALL_DIR}:${HOME}/.fnm:${PATH}"
  if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --shell bash)"
  else
    die "fnm not on PATH — re-run install.sh"
  fi
}

validate_node_version() {
  [[ "$NODE_VERSION" =~ ^[0-9]+(\.[0-9]+)*(-[a-zA-Z0-9.]+)?$ ]] \
    || die "invalid DEVBOX_NODE_VERSION: $NODE_VERSION"
}

install_node_stack() {
  activate_fnm
  validate_node_version
  log "installing Node ${NODE_VERSION}"
  fnm install "$NODE_VERSION"
  fnm use "$NODE_VERSION"
  fnm default "$NODE_VERSION"
  node -v
  npm -v
}

configure_corporate_ca() {
  if [[ -z "${DEVBOX_CA_CERT_FILE:-}" ]]; then
    if grep -qi microsoft /proc/version 2>/dev/null; then
      warn "DEVBOX_CA_CERT_FILE not set — run: devbox setup tls"
    fi
    return 0
  fi
  [[ -f "$DEVBOX_CA_CERT_FILE" ]] || die "DEVBOX_CA_CERT_FILE not found: $DEVBOX_CA_CERT_FILE"
  log "installing corporate CA certificate"
  devbox_apply_corporate_ca "$DEVBOX_CA_CERT_FILE" \
    || warn "could not install CA into system store (using SSL_CERT_FILE for this session)"
  devbox_export_ssl_certs
  log "SSL_CERT_FILE set for curl/fnm/npm"
}

install_global_tools() {
  activate_fnm
  devbox_export_ssl_certs
  log "installing pnpm@${PNPM_VERSION} and turbo@${TURBO_VERSION}"
  npm install -g "pnpm@${PNPM_VERSION}" "turbo@${TURBO_VERSION}"
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
  chmod 755 "$DEVBOX_ROOT/bin/devbox"
  log "devbox CLI linked to ~/.local/bin/devbox"
}

patch_shell_rc() {
  if [[ "${DEVBOX_PATCH_SHELL:-}" != "1" ]]; then
    log "skipping .bashrc patch (set DEVBOX_PATCH_SHELL=1 to enable)"
    return 0
  fi
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
[[ -f "\$DEVBOX_ROOT/config/env.local" ]] && source "\$DEVBOX_ROOT/config/env.local"
EOF
  log "updated $rc"
}

main() {
  log "devbox machine bootstrap (root: $DEVBOX_ROOT)"
  install_apt_baseline
  configure_corporate_ca
  devbox_export_ssl_certs
  install_fnm
  install_node_stack
  install_global_tools
  configure_pnpm
  ensure_workspace
  install_devbox_cli
  patch_shell_rc
  log "done — clone team repos into ~/code (devbox not required per repo)"
  log "next: exec bash && devbox doctor"
  log "tip: export DEVBOX_PATCH_SHELL=1 before install to auto-configure bash"
}

main "$@"
