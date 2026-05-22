# Troubleshooting

## `curl: unable to get local issuer certificate`

Corporate TLS inspection (common with Zscaler). The root CA is not in WSL’s trust store yet.

1. Run `devbox setup tls` (after `bash install.sh`)
2. Verify: `curl -fsSL https://nodejs.org/dist/index.json | head -c 80`
3. Re-run `devbox setup`

## `can't get remote versions file` (fnm)

fnm cannot fetch `https://nodejs.org/dist/index.json`. Usually the same TLS issue as curl.

```bash
export SSL_CERT_FILE=$HOME/devbox/config/zscaler-root.cer   # if you have the file
fnm ls-remote | head
```

Fix CA in WSL: `devbox setup tls`, then `devbox setup`.

## `pnpm install` very slow

Repo is probably on a Windows mount.

```bash
pwd   # should be /home/<you>/code/..., NOT /mnt/c/...
```

Move clone to `~/code`. See [ARCHITECTURE.md](ARCHITECTURE.md).

## npm / scripts blocked

You are likely in **PowerShell** or **cmd**, not WSL.

```powershell
wsl
cd ~/code/your-repo
pnpm install
```

Windows policy does not apply to Linux bash in WSL.

## `sync-zscaler-ca.sh` fails

| Error | Cause |
|-------|--------|
| `run this from WSL` | Run inside Ubuntu, not a Docker-only shell |
| `PowerShell not found` | No `/mnt/c/Windows/...` — use [CORPORATE-TLS.md](CORPORATE-TLS.md) Method 2 |
| `No Zscaler certificates found` | Zscaler not installed/connected on Windows |

## `devbox` command not found

```bash
cd ~/devbox
bash install.sh
exec bash
```

Or temporarily:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Git clone auth fails

Use HTTPS from WSL; authenticate via **Git Credential Manager on Windows** (browser SSO). No SSH required.

## Docker

devbox does not run your app in Docker. Use `docker compose` only for services (Postgres, Redis). App commands stay `pnpm dev` in WSL.

## Re-run bootstrap

Safe to run again to upgrade pinned tooling:

```bash
cd ~/devbox && git pull && devbox setup
```
