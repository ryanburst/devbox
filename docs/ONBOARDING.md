# New developer onboarding

Checklist to go from a corporate Windows laptop to working on any team repo. **Clone devbox once**; other projects use standard `git` + `pnpm` only.

## Prerequisites (Windows — usually pre-installed)

- [ ] Windows 11 with admin rights to install WSL (first time only)
- [ ] Git for Windows + Git Credential Manager
- [ ] Docker Desktop (optional — only if your team uses `docker compose` for local services)
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

## Phase 2 — Clone devbox and run setup (WSL)

Optional but recommended before the wizard (OS updates only — `install.sh` installs build tools):

```bash
sudo apt update && sudo apt upgrade -y
```

Clone and start the **interactive setup wizard** (handles TLS, `apt` packages, fnm, Node, pnpm, turbo):

```bash
git clone https://github.com/ryanburst/devbox.git ~/devbox
cd ~/devbox
bash bin/devbox setup
```

Use `bash bin/devbox setup` the first time — the `devbox` command is added to your PATH during setup.

The wizard will:

1. Test HTTPS (`nodejs.org`) and offer **Corporate TLS / Zscaler** if it fails (export from Windows, cert file path, or skip)
2. Run **`install.sh`** (sudo for system packages and CA trust)
3. Optionally add a **`~/.bashrc`** block (`PATH`, fnm, `env.local`)
4. Run **`devbox doctor`**

Then reload your shell:

```bash
exec bash
devbox doctor
```

### TLS problems only

```bash
cd ~/devbox
bash bin/devbox setup tls
```

If the wizard cannot reach Windows (no WSL interop), see [CORPORATE-TLS.md](CORPORATE-TLS.md) for manual export on the host.

## Phase 3 — First application repo (no devbox required)

```bash
mkdir -p ~/code
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
devbox repo your-app          # cd + optional profile env
devbox doctor                 # when something breaks
devbox                          # interactive menu
```

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Clone repos under `C:\` or `/mnt/c/...` | Use `~/code` in WSL |
| Run `pnpm` in PowerShell | Use WSL bash only |
| Run `install.sh` before TLS on Zscaler networks | Use `devbox setup` or `devbox setup tls` first |
| Run `devbox` before setup completes | Use `bash ~/devbox/bin/devbox setup` |
| Expect devbox inside every repo | Only clone devbox once on the machine |

## Getting help

- `devbox doctor` — toolchain, paths, HTTPS
- [ARCHITECTURE.md](ARCHITECTURE.md) — design intent
- [SECURITY.md](SECURITY.md) — security review summary
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — TLS, fnm, performance
