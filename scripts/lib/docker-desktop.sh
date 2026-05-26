# Use Docker Desktop on Windows from WSL (no Docker Engine inside Ubuntu).
# Expects Docker Desktop installed with WSL integration enabled for this distro.

devbox_windows_docker_exe() {
  local candidate
  for candidate in \
    "/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe" \
    "/mnt/c/Program Files/Docker/Docker/DockerCli.exe"; do
    if [[ -f "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
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

devbox_install_docker_wrappers() {
  local docker_exe wrapper_bin
  docker_exe="$(devbox_windows_docker_exe)" || return 1
  wrapper_bin="${HOME}/.local/bin"
  mkdir -p "$wrapper_bin"

  cat >"${wrapper_bin}/docker" <<EOF
#!/usr/bin/env sh
# devbox — Docker Desktop on Windows (WSL integration)
exec "$docker_exe" "\$@"
EOF
  chmod 755 "${wrapper_bin}/docker"

  cat >"${wrapper_bin}/docker-compose" <<'EOF'
#!/usr/bin/env sh
exec docker compose "$@"
EOF
  chmod 755 "${wrapper_bin}/docker-compose"

  printf '%s' "${wrapper_bin}/docker"
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
  cat <<'EOF'
Docker Desktop (Windows) — required for docker / docker compose in WSL:

  1. Install Docker Desktop and start it (whale icon in the system tray).
  2. Settings -> General -> enable "Use the WSL 2 based engine".
  3. Settings -> Resources -> WSL Integration -> turn ON your Ubuntu distro.
  4. Apply & Restart.
  5. From PowerShell: wsl --shutdown   then open Ubuntu again.

Do not install the Docker Engine (docker.io) inside WSL — only use Docker Desktop.

Then run: devbox setup docker
EOF
}

devbox_docker_working() {
  command -v docker >/dev/null 2>&1 || return 1
  devbox_ensure_docker_host
  docker version >/dev/null 2>&1
}

devbox_docker_compose_working() {
  devbox_ensure_docker_host
  docker compose version >/dev/null 2>&1
}

devbox_configure_docker() {
  export PATH="${HOME}/.local/bin:${PATH}"
  devbox_warn_docker_conflicts

  if ! devbox_docker_working; then
    if devbox_windows_docker_exe >/dev/null; then
      devbox_install_docker_wrappers >/dev/null || return 1
      hash -r 2>/dev/null || true
    fi
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

  devbox_print_docker_desktop_instructions >&2
  return 1
}

devbox_docker_status() {
  if devbox_docker_working && devbox_docker_compose_working; then
    printf 'ok'
    return 0
  fi
  if ! devbox_windows_docker_exe >/dev/null; then
    printf 'Docker Desktop not found on Windows — install from docker.com/products/docker-desktop'
    return 1
  fi
  if [[ ! -S /var/run/docker.sock && ! -S "${HOME}/.docker/run/docker.sock" ]]; then
    printf 'start Docker Desktop and enable WSL integration for this distro'
    return 1
  fi
  printf 'run: devbox setup docker'
  return 1
}
