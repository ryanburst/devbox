# New developer onboarding

Checklist to go from a corporate Windows laptop to working on any team repo. **You only clone devbox once**; other projects use standard `git` + `pnpm`.

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

## Phase 2 — Base packages (WSL Ubuntu)

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git ca-certificates unzip build-essential
```

## Phase 3 — Corporate TLS (if `curl` fails HTTPS)

Symptom: `curl: unable to get local issuer certificate`

**Option A — Zscaler + WSL interop** (run from WSL after cloning devbox in Phase 4):

```bash
cd ~/devbox
bash scripts/sync-zscaler-ca.sh
```

**Option B — IT-provided CA file:**

```bash
cp /path/from/it/company-root.cer ~/devbox/config/company-root.cer
cp config/env.example config/env.local
chmod 600 config/env.local
# Edit env.local: export DEVBOX_CA_CERT_FILE=$HOME/devbox/config/company-root.cer
```

**Option C — Export on Windows host** (no WSL interop): see [CORPORATE-TLS.md](CORPORATE-TLS.md).

Verify before install:

```bash
curl -fsSL https://nodejs.org/dist/index.json | head -c 80 && echo OK
```

## Phase 4 — Clone and run devbox (WSL)

```bash
git clone https://github.com/ryanburst/devbox.git ~/devbox
cd ~/devbox
export DEVBOX_PATCH_SHELL=1   # optional: auto-configure ~/.bashrc
bash install.sh
exec bash
devbox doctor
```

## Phase 5 — First application repo (no devbox required)

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
```

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Clone repos under `C:\` or `/mnt/c/...` | Use `~/code` in WSL |
| Run `pnpm` in PowerShell | Use WSL bash only |
| Skip corporate CA before `install.sh` | Run sync or set `DEVBOX_CA_CERT_FILE`, then re-run `install.sh` |
| Expect devbox inside every repo | Only clone devbox once on the machine |

## Getting help

- `devbox doctor` — toolchain and paths
- [ARCHITECTURE.md](ARCHITECTURE.md) — design intent
- [SECURITY.md](SECURITY.md) — security review summary
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — TLS, fnm, performance
