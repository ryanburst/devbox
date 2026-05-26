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

`devbox setup docker` symlinks `~/.local/bin/docker` to Docker Desktop’s CLI at `/mnt/wsl/docker-desktop/cli-tools/` (only present when WSL integration is enabled).

**Do not** rely on `docker.exe` from `C:\Program Files\Docker\...` — that prints *“could not be found in this WSL 2 distro”* until integration is on.

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
| *could not be found in this WSL 2 distro* | Enable WSL integration for **your** distro in Docker Desktop; `wsl --shutdown`; `devbox setup docker` (removes bad `docker.exe` wrappers) |
| `Cannot connect to the Docker daemon` | Start Docker Desktop; disable Resource Saver / wake engine; enable WSL integration; `wsl --shutdown` |
| `/usr/bin/docker` is a **directory** | `sudo rm -rf /usr/bin/docker` then `sudo ln -s /mnt/wsl/docker-desktop/cli-tools/usr/bin/docker /usr/bin/docker` |
| `permission denied` on socket | Ensure integration is on for **this** distro (not only docker-desktop) |
| Slow or weird behavior | Repo must be under `~/code`, not `/mnt/c/...` |
| Two Docker installs | Remove WSL engine: `sudo apt remove docker.io containerd runc` |

See also [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
