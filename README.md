# devbox

One-time setup for corporate Windows laptops: prepare WSL2, then develop any team repo with normal `git` + `pnpm`. Application projects do **not** need devbox installed.

---

## Prerequisites

### Windows (host)

- Windows 11 with permission to install WSL (first time only)
- [Git for Windows](https://git-scm.com/download/win) with **Git Credential Manager** (HTTPS clone + browser SSO)
- [Zscaler Client Connector](https://www.zscaler.com/) installed and connected (if your company uses Zscaler / TLS inspection)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) — optional; only for local services (`docker compose`)
- VS Code or Cursor — optional

### WSL2 (after install)

- Ubuntu distro (installed below)
- Network access to `github.com`, `nodejs.org`, and `registry.npmjs.org` (or your internal mirrors)

---

## Install

### 1. Install WSL2 + Ubuntu

Run in **Windows PowerShell** (not WSL yet):

```powershell
wsl --install -d Ubuntu
```

Restart if prompted, then verify and open Ubuntu:

```powershell
wsl -l -v
wsl --set-default Ubuntu
wsl
```

Create your Linux username when prompted.

### 2. Update Ubuntu (recommended)

Run in **WSL (Ubuntu)**:

```bash
sudo apt update && sudo apt upgrade -y
```

### 3. Clone devbox and install the CLI

```bash
git clone https://github.com/ryanburst/devbox.git ~/devbox
cd ~/devbox
bash install.sh
exec bash
```

`install.sh` puts the `devbox` command on your PATH, creates `~/code`, and updates `~/.bashrc` for the CLI. It does **not** install Node yet.

### 4. Run devbox setup (toolchain + TLS)

```bash
devbox setup
```

The interactive wizard will:

1. Check HTTPS and configure **corporate TLS / Zscaler** if needed
2. Install **fnm**, **Node 22**, **pnpm**, and **turbo** (pinned versions)
3. Optionally add **fnm** to `~/.bashrc`
4. Run **`devbox doctor`**

If you only need to fix TLS first:

```bash
devbox setup tls
```

### 5. Verify

```bash
devbox doctor
node -v
pnpm -v
curl -fsSL https://nodejs.org/dist/index.json | head -c 80 && echo " TLS OK"
```

### 6. Clone your first team repo

devbox is **not** required inside the repo.

```bash
cd ~/code
git clone https://github.yourcompany.com/team/your-app.git
cd your-app
pnpm install
pnpm dev
```

Use your repo’s README for ports, `.env`, and `docker compose`.

---

## Daily usage

**Windows** — open WSL only:

```powershell
wsl
```

**WSL** — work in your project:

```bash
cd ~/code/your-app
git pull
pnpm install
pnpm dev
```

Do **not** run `pnpm` or repo scripts in PowerShell; use WSL bash.

**Clone location:** always under `~/code` in WSL — not `C:\...` or `/mnt/c/...` (much slower).

---

## Quick reference

| Command | When |
|---------|------|
| `bash install.sh` | Once, after cloning devbox (installs CLI) |
| `devbox setup` | Once, after `install.sh` (TLS + Node + pnpm) |
| `devbox doctor` | When something looks wrong |
| `devbox setup tls` | HTTPS / certificate errors only |

---

## Troubleshooting

| Problem | Action |
|---------|--------|
| `curl: unable to get local issuer certificate` | `devbox setup tls` |
| `can't get remote versions file` (fnm) | Same — TLS must work before toolchain |
| `devbox: command not found` | `cd ~/devbox && bash install.sh && exec bash` |
| Very slow `pnpm install` | Repo must be in `~/code`, not `/mnt/c/...` |

More: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) · TLS detail: [docs/CORPORATE-TLS.md](docs/CORPORATE-TLS.md)

---

## Optional: devbox CLI helpers

Not required for building or running application repos.

```bash
devbox              # menu (interactive terminal)
devbox list         # repos under ~/code
devbox repo <name>  # cd into ~/code/<name> with optional env profile
```

Per-repo files (optional): `.devbox/profile.env`, `.devbox/hooks.sh` (hooks require `--trust-hooks`).

---

## Optional: Docker for local services

```bash
cd ~/code/your-app
docker compose up -d
```

Run the app with `pnpm dev` in WSL, not on `C:\`.

---

## What devbox is (and is not)

| devbox is | devbox is not |
|-----------|----------------|
| Laptop bootstrap (`install.sh` + `devbox setup`) | A dependency in every application repo |
| Pinned Node / pnpm / turbo in WSL | A replacement for your repo’s scripts |
| `~/code` workspace convention | A dev container on `C:\` for daily `pnpm` |

After setup, a normal day is `wsl` → `cd ~/code/my-app` → `pnpm dev`. No devbox in the project.

---

## Why WSL2

- **Policy:** Many corporate Windows images block npm lifecycle scripts; they run in WSL Linux.
- **Speed:** `node_modules` on the WSL filesystem (`~/code`) is much faster than on `C:\` or `/mnt/c/...`.
- **Git auth:** HTTPS via Git Credential Manager on Windows; clone into `~/code` from WSL.

---

## Architecture

```text
Windows  →  Git + GCM, Docker Desktop, VS Code, Zscaler (launcher only)
WSL2     →  Node, pnpm, turbo, all installs and repo scripts
~/code   →  all team repository clones
```

[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) · [docs/ONBOARDING.md](docs/ONBOARDING.md)

---

## Configuration

| File | Purpose |
|------|---------|
| `config/versions.sh` | Pinned fnm, Node, pnpm, turbo |
| `config/env.local` | Proxy, CA path (copy from `config/env.example`; gitignored) |

---

## Documentation

| Doc | Audience |
|-----|----------|
| [ONBOARDING.md](docs/ONBOARDING.md) | Full checklist |
| [CORPORATE-TLS.md](docs/CORPORATE-TLS.md) | Zscaler / manual CA |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Support |
| [SECURITY.md](docs/SECURITY.md) | Security review |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Design / platform |
