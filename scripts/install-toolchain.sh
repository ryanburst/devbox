#!/usr/bin/env bash
# devbox — WSL toolchain bootstrap (fnm, Node, pnpm, turbo). Run via: devbox setup
set -euo pipefail

DEVBOX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=config/versions.sh
source "$DEVBOX_ROOT/config/versions.sh"
# shellcheck source=lib/corporate-ca.sh
source "$DEVBOX_ROOT/scripts/lib/corporate-ca.sh"

NODE_VERSION="${DEVBOX_NODE_VERSION:-$NODE_VERSION_DEFAULT}"
PNPM_STORE="${DEVBOX_PNPM_STORE:-$HOME/.pnpm-store}"
CODE_DIR="${DEVBOX_CODE_DIR:-$HOME/code}"
FNM_INSTALL_DIR="${HOME}/.local/share/fnm"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

if ! command -v curl >/dev/null 2>&1; then
  die "curl is required — run: devbox setup (installs packages) or: sudo apt install -y curl"
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
    curl git ca-certificates unzip build-essential openssl
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
  # RETURN trap must be cleared before leaving the function — otherwise it runs
  # again when main() returns and $tmp is out of scope (set -u: unbound variable).
  trap 'rm -rf "$tmp"; trap - RETURN' RETURN

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

  rm -rf "$tmp"
  trap - RETURN
}

activate_fnm() {
  export PATH="${FNM_INSTALL_DIR}:${HOME}/.fnm:${PATH}"
  if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --shell bash)"
  else
    die "fnm not on PATH — re-run: devbox setup"
  fi
}

validate_node_version() {
  [[ "$NODE_VERSION" =~ ^[0-9]+(\.[0-9]+)*(-[a-zA-Z0-9.]+)?$ ]] \
    || die "invalid DEVBOX_NODE_VERSION: $NODE_VERSION"
}

configure_npm() {
  activate_fnm
  command -v npm >/dev/null 2>&1 || return 0
  # Node ships npm 10.x; suppress "npm 11 available" noise during bootstrap.
  npm config set update-notifier false --location=user >/dev/null 2>&1 || true
  npm config set fund false --location=user >/dev/null 2>&1 || true
}

npm_quiet() {
  NPM_CONFIG_UPDATE_NOTIFIER=false NPM_CONFIG_FUND=false NPM_CONFIG_AUDIT=false \
    npm "$@"
}

install_node_stack() {
  activate_fnm
  validate_node_version
  log "installing Node ${NODE_VERSION}"
  fnm install "$NODE_VERSION"
  fnm use "$NODE_VERSION"
  fnm default "$NODE_VERSION"
  configure_npm
  node -v
  printf '%s\n' "$(npm_quiet -v 2>/dev/null)"
}

configure_corporate_ca() {
  if [[ -z "${DEVBOX_CA_CERT_FILE:-}" ]]; then
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
  npm_quiet install -g --loglevel=error "pnpm@${PNPM_VERSION}" "turbo@${TURBO_VERSION}"
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

patch_shell_rc_toolchain() {
  local marker="# devbox"
  local rc="$HOME/.bashrc"
  [[ -f "$rc" ]] || touch "$rc"

  if grep -q 'fnm env' "$rc" 2>/dev/null; then
    log "shell already has fnm configured ($rc)"
    return 0
  fi

  if ! grep -qF "$marker" "$rc" 2>/dev/null; then
    warn "no devbox block in $rc — run: bash install.sh first"
    return 0
  fi

  cat >>"$rc" <<EOF
# devbox toolchain (fnm)
export PATH="\$HOME/.local/share/fnm:\$PATH"
if command -v fnm >/dev/null 2>&1; then
  eval "\$(fnm env --shell bash)"
fi
EOF
  log "added fnm to $rc"
}

patch_shell_rc_full() {
  if [[ "${DEVBOX_PATCH_SHELL:-}" != "1" ]]; then
    return 0
  fi
  local marker="# devbox"
  local rc="$HOME/.bashrc"
  [[ -f "$rc" ]] || touch "$rc"
  if grep -q 'fnm env' "$rc" 2>/dev/null; then
    log "shell already configured ($rc)"
    return 0
  fi
  if grep -qF "$marker" "$rc" 2>/dev/null; then
    patch_shell_rc_toolchain
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
  log "devbox toolchain install (root: $DEVBOX_ROOT)"
  install_apt_baseline
  configure_corporate_ca
  devbox_export_ssl_certs
  install_fnm
  install_node_stack
  install_global_tools
  configure_pnpm
  ensure_workspace
  patch_shell_rc_full
  patch_shell_rc_toolchain
  log "done — clone team repos into ~/code (devbox not required per repo)"
  log "next: exec bash && devbox doctor"
}

main "$@"
