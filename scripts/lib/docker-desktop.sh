# Use Docker Desktop on Windows from WSL (no Docker Engine inside Ubuntu).
# Requires Docker Desktop WSL integration enabled for this distro.

devbox_wsl_distro_name() {
  if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    printf '%s' "$WSL_DISTRO_NAME"
    return 0
  fi
  basename "$(wslpath -w "$HOME" 2>/dev/null || true)" 2>/dev/null | tr -d '\r' || true
}

devbox_docker_desktop_cli() {
  local candidate
  for candidate in \
    /mnt/wsl/docker-desktop/cli-tools/usr/bin/docker \
    /mnt/wsl/docker-desktop/cli-tools/usr/local/bin/docker; do
    if [[ -x "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

devbox_docker_desktop_installed_on_windows() {
  [[ -f "/mnt/c/Program Files/Docker/Docker/Docker Desktop.exe" ]] \
    || [[ -f "/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe" ]]
}

devbox_ensure_docker_host() {
  if [[ -n "${DOCKER_HOST:-}" ]]; then
    return 0
  fi
  if [[ -S /var/run/docker.sock ]]; then
    return 0
  fi
  if [[ -S "${HOME}/.docker/run/docker.sock" ]]; then
    export DOCKER_HOST="unix://${HOME}/.docker/run/docker.sock"
  fi
}

devbox_is_devbox_windows_exe_wrapper() {
  [[ -f "${HOME}/.local/bin/docker" ]] \
    && grep -q 'docker.exe' "${HOME}/.local/bin/docker" 2>/dev/null
}

devbox_remove_windows_exe_wrappers() {
  if devbox_is_devbox_windows_exe_wrapper; then
    rm -f "${HOME}/.local/bin/docker" "${HOME}/.local/bin/docker-compose"
    printf '==> removed docker.exe wrappers (they fail without WSL integration)\n'
  fi
}

devbox_install_docker_cli_symlinks() {
  local docker_cli compose_cli wrapper_bin
  docker_cli="$(devbox_docker_desktop_cli)" || return 1
  wrapper_bin="${HOME}/.local/bin"
  mkdir -p "$wrapper_bin"
  ln -sf "$docker_cli" "${wrapper_bin}/docker"
  compose_cli="/mnt/wsl/docker-desktop/cli-tools/usr/bin/docker-compose"
  if [[ -x "$compose_cli" ]]; then
    ln -sf "$compose_cli" "${wrapper_bin}/docker-compose"
  else
    cat >"${wrapper_bin}/docker-compose" <<'EOF'
#!/usr/bin/env sh
exec docker compose "$@"
EOF
    chmod 755 "${wrapper_bin}/docker-compose"
  fi
  printf '%s' "${wrapper_bin}/docker"
}

devbox_docker_integration_ready() {
  devbox_docker_desktop_cli >/dev/null
}

devbox_docker_stderr_indicates_no_integration() {
  local err="$1"
  echo "$err" | grep -qi 'could not be found in this WSL'
}

devbox_diagnose_docker_symlinks() {
  local distro
  distro="$(devbox_wsl_distro_name 2>/dev/null || echo '<your-ubuntu-distro>')"

  if [[ -d /usr/bin/docker && ! -L /usr/bin/docker ]]; then
    printf '  problem: /usr/bin/docker is a directory (should be a symlink)\n'
    printf '  fix:\n'
    printf '    sudo rm -rf /usr/bin/docker\n'
    printf '    sudo ln -s /mnt/wsl/docker-desktop/cli-tools/usr/bin/docker /usr/bin/docker\n'
  fi

  if ! devbox_docker_integration_ready; then
    printf '  problem: Docker Desktop CLI not mounted at /mnt/wsl/docker-desktop/cli-tools/\n'
    printf '  fix (Windows): Docker Desktop -> Settings -> Resources -> WSL Integration\n'
    printf '    Enable distro: %s\n' "$distro"
    printf '    Apply & Restart, then PowerShell: wsl --shutdown\n'
    printf '  tip: wake Docker Desktop if Resource Saver paused the engine (whale icon)\n'
  fi
}

devbox_warn_docker_conflicts() {
  if command -v systemctl >/dev/null 2>&1 && systemctl is-active docker >/dev/null 2>&1; then
    printf 'warning: WSL docker.service is active — conflicts with Docker Desktop\n' >&2
    printf 'warning: sudo systemctl disable --now docker\n' >&2
  fi
  if command -v dpkg >/dev/null 2>&1 && dpkg -l docker.io 2>/dev/null | grep -q '^ii'; then
    printf 'warning: docker.io installed in WSL — remove to avoid conflicts with Docker Desktop\n' >&2
    printf 'warning: sudo apt remove -y docker.io containerd runc\n' >&2
  fi
}

devbox_print_docker_desktop_instructions() {
  local distro
  distro="$(devbox_wsl_distro_name 2>/dev/null || echo 'Ubuntu')"
  cat <<EOF
Docker Desktop (Windows) — enable WSL integration for this distro:

  1. Start Docker Desktop (whale icon — not "Resource Saver" / paused).
  2. Settings -> General -> "Use the WSL 2 based engine" (on).
  3. Settings -> Resources -> WSL Integration:
       Enable integration with additional distros: ON
       Check: ${distro}
  4. Apply & Restart.
  5. PowerShell: wsl --shutdown
  6. Open Ubuntu again, then: devbox setup docker

Verify in WSL: ls -l /mnt/wsl/docker-desktop/cli-tools/usr/bin/docker

Do not use docker.exe from Windows — integration injects the Linux CLI.
Do not apt install docker.io in WSL.
EOF
}

devbox_docker_working() {
  local err
  command -v docker >/dev/null 2>&1 || return 1
  devbox_ensure_docker_host
  err="$(docker info 2>&1)" || true
  if devbox_docker_stderr_indicates_no_integration "$err"; then
    return 1
  fi
  docker info >/dev/null 2>&1
}

devbox_docker_compose_working() {
  devbox_ensure_docker_host
  docker compose version >/dev/null 2>&1
}

devbox_configure_docker() {
  export PATH="${HOME}/.local/bin:/usr/local/bin:/usr/bin:${PATH}"
  devbox_warn_docker_conflicts
  devbox_remove_windows_exe_wrappers

  if ! devbox_docker_desktop_installed_on_windows; then
    printf 'devbox: Docker Desktop not found on Windows\n' >&2
    devbox_print_docker_desktop_instructions >&2
    return 1
  fi

  if ! devbox_docker_integration_ready; then
    printf 'devbox: Docker Desktop WSL integration is not active for this distro\n' >&2
    devbox_diagnose_docker_symlinks >&2
    devbox_print_docker_desktop_instructions >&2
    return 1
  fi

  if ! command -v docker >/dev/null 2>&1 \
    || devbox_is_devbox_windows_exe_wrapper \
    || ! devbox_docker_working; then
    devbox_install_docker_cli_symlinks >/dev/null || return 1
    hash -r 2>/dev/null || true
  fi

  devbox_ensure_docker_host

  if devbox_docker_working; then
    printf '==> docker client: %s\n' "$(docker version --format '{{.Client.Version}}' 2>/dev/null \
      || docker --version 2>/dev/null | head -1 || echo unknown)"
    if docker version --format '{{.Server.Version}}' >/dev/null 2>&1; then
      printf '==> docker server: %s (Docker Desktop)\n' "$(docker version --format '{{.Server.Version}}')"
    fi
    if devbox_docker_compose_working; then
      printf '==> docker compose: %s\n' "$(docker compose version 2>/dev/null | head -1)"
      return 0
    fi
    printf 'warning: docker compose failed — update Docker Desktop\n' >&2
    return 1
  fi

  printf 'devbox: docker info failed\n' >&2
  devbox_diagnose_docker_symlinks >&2
  devbox_print_docker_desktop_instructions >&2
  return 1
}

devbox_docker_status() {
  local err
  if devbox_docker_working && devbox_docker_compose_working; then
    printf 'ok'
    return 0
  fi
  if ! devbox_docker_desktop_installed_on_windows; then
    printf 'install Docker Desktop on Windows'
    return 1
  fi
  if ! devbox_docker_integration_ready; then
    printf 'enable WSL integration for %s in Docker Desktop' "$(devbox_wsl_distro_name 2>/dev/null || echo Ubuntu)"
    return 1
  fi
  if command -v docker >/dev/null 2>&1; then
    err="$(docker info 2>&1)" || true
    if devbox_docker_stderr_indicates_no_integration "$err"; then
      printf 'remove docker.exe wrapper — run: devbox setup docker'
      return 1
    fi
  fi
  printf 'run: devbox setup docker'
  return 1
}
