# devbox architecture

## Purpose

**devbox is a one-time machine bootstrap** for corporate Windows laptops. It prepares WSL2 Ubuntu so developers can clone and work on **any** team repository using normal tooling (`git`, `pnpm`, repo scripts).

Application repos **do not need** devbox as a dependency. No `devbox` package in `package.json`, no required `.devbox/` folder. Optional helpers exist for teams that want them.

## Problem being solved

| Constraint | Approach |
|------------|----------|
| Windows blocks npm lifecycle / script execution (AppLocker, etc.) | Run all Node tooling **inside WSL2 Linux**, not on Windows |
| `pnpm install` slow on `C:\` or `/mnt/c/...` | Clone repos under **`~/code`** on the WSL ext4 filesystem |
| Inconsistent Node/pnpm across developers | Pinned versions in `config/versions.sh` + `install.sh` |
| TLS inspection (e.g. Zscaler) breaks `curl` / fnm / npm | Install corporate root CA into **WSL** trust store before downloads |
| SSH complexity on enterprise GitHub | HTTPS + Git Credential Manager on **Windows** |

## Layers

```text
┌─────────────────────────────────────────────────────────┐
│  Windows (thin host — launcher only)                     │
│  • Git + Git Credential Manager (HTTPS clone)            │
│  • Docker Desktop (optional service containers)          │
│  • VS Code / Cursor (optional)                           │
│  • Zscaler Client Connector (network / TLS inspection)   │
│  • Does NOT run: pnpm, npm scripts, turbo, repo hooks    │
└──────────────────────────┬──────────────────────────────┘
                           │  wsl
┌──────────────────────────▼──────────────────────────────┐
│  WSL2 Ubuntu (primary development runtime)               │
│  • fnm + Node + pnpm + turbo (from devbox setup / install-toolchain) │
│  • ~/code — all git clones                               │
│  • ~/.pnpm-store — fast package cache                    │
│  • Corporate CA in system trust (for curl, fnm, npm)     │
└─────────────────────────────────────────────────────────┘
```

## What devbox installs (once per machine)

**`bash install.sh`** (CLI only):

- `devbox` command on `PATH` (`~/.local/bin`)
- `~/code` workspace directory
- Minimal `~/.bashrc` block (`DEVBOX_ROOT`, PATH)
- Optional: `curl` via apt if missing (for `devbox setup`)

**`devbox setup`** (toolchain + TLS):

- System packages (`curl`, `git`, `build-essential`, …)
- Corporate CA trust (when configured)
- fnm + pinned Node LTS
- Global `pnpm` and `turbo` (pinned)
- Optional: fnm in `~/.bashrc`

## What devbox does *not* require for daily work

After bootstrap, a typical day:

```bash
wsl
cd ~/code/my-app
git pull
pnpm install
pnpm dev
```

That uses the **machine** Node/pnpm setup. The app repo only needs its usual files (e.g. `package.json`, `pnpm-lock.yaml`, `.nvmrc` if stricter than the default).

## Optional devbox features (not required per repo)

| Feature | Use when |
|---------|----------|
| `devbox doctor` | Verify laptop setup / support |
| `devbox repo <name>` | Convenience: `cd` + load env profile |
| `~/devbox/profiles/<repo>.env` | Shared env defaults for a repo name |
| `<repo>/.devbox/profile.env` | Repo-specific env (optional) |
| `devbox repo --trust-hooks` | Run `.devbox/hooks.sh` on trusted repos only |

## What we intentionally avoid

- **Docker as the primary dev runtime** with the repo on `C:\` — slow I/O and extra TLS complexity.
- **Dev Containers on Windows mounts** for monorepo `pnpm` — same performance issue unless the workspace is WSL-backed.
- **Disabling TLS verification** (`strict-ssl false`) — use corporate CA in WSL instead.
- **Requiring devbox inside every application repository** — devbox is the laptop kit, not an app framework.

Docker remains **optional** for infrastructure only (Postgres, Redis, etc.) via `docker compose`.

## Corporate TLS (Zscaler)

Zscaler installs roots on **Windows**. WSL has a **separate** trust store — you must copy/install the CA into Ubuntu **before** `fnm install` / `npm` downloads succeed.

Preferred: **`bash install.sh`** then **`devbox setup`** (wizard runs TLS before toolchain).

Other paths:

1. **WSL + interop:** `bash scripts/sync-zscaler-ca.sh` (called from the TLS wizard).
2. **Manual:** IT provides a `.cer` / `.pem`; set `DEVBOX_CA_CERT_FILE` in `config/env.local`.
3. **Host-only export:** Run `scripts/windows/Export-ZscalerCa.ps1` on Windows, copy into WSL `config/`.

See [CORPORATE-TLS.md](CORPORATE-TLS.md).

## Repository layout

| Path | Role |
|------|------|
| `install.sh` | Install devbox CLI + `~/code` (run once after clone) |
| `scripts/install-toolchain.sh` | Node/pnpm/turbo (run via `devbox setup`, or `install.sh --toolchain`) |
| `config/versions.sh` | Pinned fnm / pnpm / turbo / Node |
| `config/env.local` | Machine-specific proxy, CA path (gitignored) |
| `bin/devbox` | Optional CLI |
| `scripts/windows/` | One-time host helpers (cert export), not used by application repos |
| `docs/` | Architecture, onboarding, security |

## Success criteria for a new developer

1. `wsl` opens Ubuntu; `devbox doctor` passes.
2. `curl https://nodejs.org/dist/index.json` works (TLS OK).
3. `cd ~/code && git clone <any-team-repo> && pnpm install` works without devbox in that repo.
4. Windows never runs `pnpm` or repo postinstall scripts.
