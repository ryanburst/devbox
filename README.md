# devbox

A standardized WSL2-based development environment for engineering teams.

## Overview

devbox provides a fast, consistent Linux development environment on Windows using WSL2.

It standardizes:

* Node.js (via fnm)

* pnpm package management

* Git HTTPS authentication via Git Credential Manager

* Optional Docker service containers

* Per-repo environment profiles

## Architecture

* **Windows**: Git + Docker Desktop + WSL launcher only

* **WSL2 Ubuntu**: primary development environment

* **Node.js**: fnm-managed

* **Package manager**: pnpm

* **Services**: Docker (optional, for dependencies only)

## First-Time Setup (Windows)

### 1. Install WSL2 + Ubuntu

*Run this command in Windows PowerShell:*

```powershell
wsl --install -d Ubuntu
```

Restart your machine after installation.

### 2. Verify WSL installation

*Run this command in Windows PowerShell:*

```powershell
wsl -l -v
```

You should see:

* Ubuntu

* docker-desktop

### 3. Launch Ubuntu

*Run this command in Windows PowerShell:*

```powershell
wsl
```

Create your UNIX user when prompted.

## WSL Setup (Ubuntu)

### Update system packages

*Run these commands inside your WSL Ubuntu terminal:*

```bash
sudo apt update && sudo apt upgrade -y
```

### Install required tools

*Run this command inside your WSL Ubuntu terminal:*

```bash
sudo apt install -y curl git ca-certificates unzip build-essential
```

## Install devbox

### Clone repository

*Run these commands inside your WSL Ubuntu terminal:*

```bash
git clone https://github.com/<your-org>/devbox ~/devbox
cd ~/devbox
```

### Run installer

*Run this command inside your WSL Ubuntu terminal:*

```bash
# optional: auto-configure ~/.bashrc
export DEVBOX_PATCH_SHELL=1
bash install.sh
```

Pinned toolchain versions live in `config/versions.sh`. See [docs/SECURITY.md](docs/SECURITY.md) for the corporate security model.

## Post Install

Restart shell (or open a new terminal):

*Run this command inside your WSL Ubuntu terminal:*

```bash
exec bash
```

If you skipped `DEVBOX_PATCH_SHELL=1`, add `~/.local/bin` and fnm to your PATH manually, or re-run install with that variable set.

Verify installation:

*Run these commands inside your WSL Ubuntu terminal:*

```bash
devbox doctor
node -v
pnpm -v
```

### Corporate proxy / TLS (optional)

If installs fail behind SSL inspection, install your organization root CA — do not disable TLS verification.

#### Zscaler (automated from WSL)

Requires **Zscaler Client Connector** installed on Windows (certificates present in Windows stores).

*Run inside WSL from your devbox clone:*

```bash
bash scripts/sync-zscaler-ca.sh
bash install.sh
```

This script:

1. Runs `scripts/windows/Export-ZscalerCa.ps1` on Windows
2. Copies the cert to `config/zscaler-root.cer` (gitignored)
3. Writes `DEVBOX_CA_CERT_FILE` in `config/env.local`

List certs without exporting:

```powershell
# Windows PowerShell
.\scripts\windows\Export-ZscalerCa.ps1 -ListOnly
```

#### Manual / other vendors

```bash
cp config/env.example config/env.local
chmod 600 config/env.local
# Set DEVBOX_CA_CERT_FILE=/path/to/company-root-ca.pem
bash install.sh
```

## devbox CLI

After install, `devbox` is on your PATH.

| Command | Purpose |
|---------|---------|
| `devbox doctor` | Check Node, pnpm, WSL, workspace paths, and file ownership |
| `devbox list` | List folders under `~/code` |
| `devbox repo <name>` | `cd` into `~/code/<name>` with profile env loaded |
| `devbox repo <name> --trust-hooks` | Same, and run `.devbox/hooks.sh` (trusted repos only) |
| `devbox env [profile]` | Show allowlisted profile variables (secrets redacted) |

### Per-repo profiles (optional)

In a project repo:

```bash
mkdir -p .devbox
```

Create `.devbox/profile.env`:

```bash
NODE_VERSION=22
API_URL=http://localhost:3000
```

Optional `.devbox/hooks.sh` runs only with explicit trust (arbitrary shell code):

```bash
devbox repo my-repo --trust-hooks
# or: export DEVBOX_TRUST_HOOKS=1
```

Shared team profiles live in `~/devbox/profiles/<repo-name>.env`.

## Workspace Convention

All repositories must live in:

*Inside your WSL Ubuntu filesystem:*

```bash
~/code
```

Example:

*Run these commands inside your WSL Ubuntu terminal:*

```bash
cd ~/code
git clone https://github.company.com/team/repo.git
```

## Daily Usage

Start WSL:

*Run this command in Windows PowerShell or the Windows Command Prompt:*

```powershell
wsl
```

Navigate to project:

*Run this command inside your WSL Ubuntu terminal:*

```bash
cd ~/code/repo
```

Install dependencies:

*Run this command inside your WSL Ubuntu terminal:*

```bash
pnpm install
```

Run development server:

*Run this command inside your WSL Ubuntu terminal:*

```bash
pnpm dev
```

## Performance Notes

* Always work inside WSL filesystem (`~/code`)

* Avoid `/mnt/c` for repositories (slow)

* pnpm store located at `~/.pnpm-store`

## Docker Usage (Optional)

Docker is used only for supporting services:

*Run this command inside your WSL Ubuntu terminal, in the directory containing your `docker-compose.yml` file:*

```bash
docker compose up -d
```

Examples:

* Postgres

* Redis

* Local infrastructure services

## Authentication

* Uses HTTPS GitHub Enterprise URLs

* Git Credential Manager (browser login)

* No SSH keys required

## Troubleshooting

Restart WSL:

*Run this command in Windows PowerShell:*

```powershell
wsl --shutdown
```

Slow installs:
Ensure repo is inside:

*Your WSL Ubuntu filesystem:*

```bash
~/code
```

NOT:

*A mounted Windows directory:*

```bash
/mnt/c/...
```

## Summary

devbox provides:

* Fast WSL2 Linux dev environment

* Standard Node + pnpm setup

* Consistent team onboarding

* Optional Docker service layer
