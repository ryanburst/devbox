# Troubleshooting

## `curl: (77) error adding trust anchors` / `0 added, 0 removed`

Windows `Export-Certificate` often produced **DER** `.cer` files. curl and `update-ca-certificates` need **PEM**.

```bash
cd ~/devbox
git pull
# Re-export or convert:
devbox setup tls
# Or manually:
openssl x509 -in config/zscaler-root.cer -inform DER \
  -out config/corporate-ca.pem -outform PEM
export DEVBOX_CA_CERT_FILE=$HOME/devbox/config/corporate-ca.pem
devbox setup tls
```

Verify:

```bash
openssl x509 -in ~/devbox/config/corporate-ca.pem -noout -subject
curl -fsSL https://nodejs.org/dist/index.json | head -c 80
```

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

## Retry install from scratch

```bash
devbox reset          # CLI + ~/.bashrc
# or: devbox reset --full   # + fnm, pnpm, CA, etc.
exec bash
cd ~/devbox && bash install.sh && devbox setup
```

Details: [RESET.md](RESET.md)

## `.local/scripts/lib/corporate-ca.sh: No such file`

The `devbox` on PATH is a symlink under `~/.local/bin`. An older CLI resolved the repo as `~/.local` instead of `~/devbox`.

```bash
cd ~/devbox
git pull
bash install.sh
exec bash
devbox setup
```

Or once: `bash ~/devbox/bin/devbox setup`

## `DEVBOX_ROOT override ignored`

Stale `DEVBOX_ROOT` in the shell (often from `~/.bashrc` after a re-clone). Fixed in current `bin/devbox`; update and run:

```bash
unset DEVBOX_ROOT
devbox setup
```

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
