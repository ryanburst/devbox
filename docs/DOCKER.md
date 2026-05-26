# Docker Desktop from WSL

devbox does **not** install Docker Engine inside Ubuntu. Use **Docker Desktop on Windows** and talk to it from WSL.

## One-time (Windows)

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/).
2. Start Docker Desktop (whale icon running).
3. **Settings → General** → enable **Use the WSL 2 based engine**.
4. **Settings → Resources → WSL Integration** → enable your **Ubuntu** distro.
5. **Apply & Restart**.
6. In PowerShell: `wsl --shutdown`, then open Ubuntu again.

Do **not** `sudo apt install docker.io` in WSL — it conflicts with Docker Desktop.

## One-time (WSL)

```bash
cd ~/devbox && git pull
devbox setup docker
devbox doctor
docker run --rm hello-world
```

`devbox setup docker` adds `~/.local/bin/docker` wrappers that call the Windows CLI when needed.

## Daily use

```bash
cd ~/code/your-app
docker compose up -d
pnpm dev
```

Run `docker` and `docker compose` in **WSL bash**, not PowerShell (unless you prefer Windows for compose only).

## Troubleshooting

| Symptom | Fix |
|--------|-----|
| `docker: command not found` | `devbox setup docker` |
| `Cannot connect to the Docker daemon` | Start Docker Desktop; enable WSL integration; `wsl --shutdown` |
| `permission denied` on socket | Ensure integration is on for **this** distro (not only docker-desktop) |
| Slow or weird behavior | Repo must be under `~/code`, not `/mnt/c/...` |
| Two Docker installs | Remove WSL engine: `sudo apt remove docker.io containerd runc` |

See also [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
