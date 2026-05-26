# New developer onboarding

Checklist to go from a corporate Windows laptop to working on any team repo. **Clone devbox once**; other projects use standard `git` + `pnpm` only.

## Prerequisites (Windows — usually pre-installed)

- [ ] Windows 11 with admin rights to install WSL (first time only)
- [ ] Git for Windows + Git Credential Manager
- [ ] Docker Desktop on Windows with **WSL Integration** enabled for Ubuntu (if repos use `docker compose`)
- [ ] VS Code or Cursor (optional)
- [ ] Zscaler Client Connector connected (if your company uses Zscaler)

## Phase 1 — WSL2 (Windows PowerShell)

```powershell
wsl --install -d Ubuntu
```

Restart if prompted. Then:

```powershell
wsl -l -v
wsl --set-default Ubuntu
wsl
```

Create your Linux username when prompted.

## Phase 2 — Clone devbox and install CLI (WSL)

Optional OS updates:

```bash
sudo apt update && sudo apt upgrade -y
```

Clone and install the **devbox CLI** (does not install Node yet):

```bash
git clone https://github.com/ryanburst/devbox.git ~/devbox
cd ~/devbox
bash install.sh
exec bash
```

`install.sh` links `devbox` to `~/.local/bin`, creates `~/code`, and adds a minimal `~/.bashrc` block.

## Phase 3 — Run devbox setup (WSL)

```bash
devbox setup
```

The wizard will:

1. Test HTTPS and configure **corporate TLS / Zscaler** if needed
2. Install the **toolchain** (apt packages, fnm, Node, pnpm, just, turbo)
3. Optionally add **fnm** to `~/.bashrc`
4. Configure **Docker** (`devbox setup docker` — after Docker Desktop is running on Windows)
5. Run **`devbox doctor`**

TLS only:

```bash
devbox setup tls
```

Manual fallback: [CORPORATE-TLS.md](CORPORATE-TLS.md).

## Phase 4 — First application repo (no devbox required)

```bash
cd ~/code
git clone https://github.yourcompany.com/team/your-app.git
cd your-app
pnpm install
pnpm dev
```

Use the repo’s own README for ports, env files, and compose.

## Daily workflow (after onboarding)

```powershell
# Windows — open Linux only
wsl
```

```bash
cd ~/code/your-app
git pull
pnpm install
pnpm dev
```

## Optional: devbox CLI helpers

```bash
devbox list
devbox repo your-app
devbox doctor
devbox                    # interactive menu
```

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Skip `install.sh` and run `devbox setup` from clone path only | Run `bash install.sh` first so `devbox` is on PATH |
| Clone repos under `C:\` or `/mnt/c/...` | Use `~/code` in WSL |
| Run `pnpm` in PowerShell | Use WSL bash only |
| Run toolchain before TLS on Zscaler networks | Use `devbox setup` (TLS runs first) or `devbox setup tls` |
| Expect devbox inside every repo | Only clone devbox once on the machine |

## Getting help

- `devbox doctor` — toolchain, paths, HTTPS
- [ARCHITECTURE.md](ARCHITECTURE.md) — design intent
- [SECURITY.md](SECURITY.md) — security review summary
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — TLS, fnm, performance
