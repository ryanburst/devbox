# devbox

**One-time bootstrap for corporate Windows laptops** — prepares WSL2 Ubuntu so developers can clone any team repo and use standard `git` + `pnpm` without installing devbox into those projects.

## What devbox is

| devbox is | devbox is not |
|-----------|----------------|
| Machine setup automation (`install.sh`) | A dependency inside application repos |
| Pinned Node / pnpm / turbo on WSL | A replacement for each repo’s `package.json` scripts |
| `~/code` + TLS conventions | A Docker-first dev container on `C:\` |
| Optional CLI (`devbox doctor`, `devbox repo`) | Required for `pnpm dev` to work |

**After bootstrap**, daily work looks like any normal monorepo:

```bash
wsl
cd ~/code/your-app
pnpm install && pnpm dev
```

## Why WSL2 (not Windows or container-on-`C:\`)

- **Policy:** Corporate Windows often blocks npm lifecycle scripts; they run fine in **WSL Linux bash**.
- **Speed:** `pnpm` and `node_modules` on the WSL filesystem (`~/code`) are much faster than on `C:\` or `/mnt/c/...`.
- **Simplicity:** No per-project devbox config required; optional helpers only.

Docker is **optional** for local **services** (Postgres, Redis) — not the primary place to run `pnpm dev`.

## Architecture (short)

```text
Windows  →  Git + GCM, Docker Desktop, VS Code, Zscaler (launcher only)
WSL2     →  Node, pnpm, turbo, all installs and repo scripts
~/code   →  every team repository clone
```

Details: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## New developer checklist

Full steps: **[docs/ONBOARDING.md](docs/ONBOARDING.md)**

1. **Windows:** `wsl --install -d Ubuntu` → restart → `wsl`
2. **WSL:** `sudo apt update` and install base packages (see onboarding doc)
3. **TLS (if needed):** [docs/CORPORATE-TLS.md](docs/CORPORATE-TLS.md) — **before** `install.sh` if `curl` fails HTTPS
4. **Bootstrap:**

```bash
git clone https://github.com/ryanburst/devbox.git ~/devbox
cd ~/devbox
export DEVBOX_PATCH_SHELL=1   # optional: add devbox to ~/.bashrc
bash install.sh
exec bash
devbox doctor
```

5. **Any project** (devbox not required in the repo):

```bash
cd ~/code
git clone https://github.yourcompany.com/team/your-app.git
cd your-app
pnpm install
pnpm dev
```

## Corporate TLS (Zscaler)

If `curl` or `fnm` fail with certificate errors, configure trust **before** `install.sh`:

```bash
# WSL with Windows interop (one-time)
bash scripts/sync-zscaler-ca.sh

# Verify
curl -fsSL https://nodejs.org/dist/index.json | head -c 80

bash install.sh
```

Host-only export (no WSL→PowerShell): [docs/CORPORATE-TLS.md](docs/CORPORATE-TLS.md)

## Optional: devbox CLI

Convenience only — **not** needed for application builds.

| Command | Purpose |
|---------|---------|
| `devbox doctor` | Verify WSL toolchain, paths, ownership |
| `devbox list` | List directories in `~/code` |
| `devbox repo <name>` | `cd ~/code/<name>` and load optional env profile |
| `devbox repo <name> --trust-hooks` | Also run trusted `.devbox/hooks.sh` |

Optional per-repo files (teams that want them):

- `.devbox/profile.env` — extra env vars
- `.devbox/hooks.sh` — only with `--trust-hooks` (arbitrary shell; trusted repos)

Shared profiles: `~/devbox/profiles/<repo-name>.env`

## Workspace rule

Clone **only** under the WSL Linux home — not Windows drives:

```bash
~/code/my-repo     # yes
/mnt/c/Users/...   # no — slow
```

pnpm store: `~/.pnpm-store` (configured by `install.sh`)

## Docker (optional services)

From a repo that includes compose files:

```bash
cd ~/code/my-app
docker compose up -d
```

Run app code with `pnpm` in WSL, not inside a dev container on `C:\`.

## Authentication

- HTTPS Git remote URLs
- Git Credential Manager on **Windows** (browser / SSO)
- No SSH keys required for standard setup

## Configuration

| File | Purpose |
|------|---------|
| `config/versions.sh` | Pinned fnm, Node, pnpm, turbo |
| `config/env.local` | Machine proxy, CA path (gitignored) — copy from `config/env.example` |
| `config/zscaler-root.cer` | Exported CA (gitignored) |

Security: [docs/SECURITY.md](docs/SECURITY.md)

## Troubleshooting

[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — TLS, fnm, slow installs, sync script errors.

## Documentation index

| Doc | Audience |
|-----|----------|
| [ONBOARDING.md](docs/ONBOARDING.md) | New hires |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Leads / platform |
| [CORPORATE-TLS.md](docs/CORPORATE-TLS.md) | Zscaler / proxy setup |
| [SECURITY.md](docs/SECURITY.md) | Security review |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Support |

## Summary

devbox prepares the **laptop once**; teams ship normal repos. Use WSL + `~/code` for speed and policy compliance; keep Windows as a thin launcher.
