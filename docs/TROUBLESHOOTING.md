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

## `corporate-ca.sh: No such file` / `.local/scripts/lib/corporate-ca.sh`

`devbox` on PATH is a symlink at `~/.local/bin/devbox`. If root detection fails, devbox looks under `~/.local/scripts/...` instead of `~/devbox/scripts/...`.

**Fix (have your friend run in WSL):**

```bash
cd ~/devbox
git pull
bash install.sh
exec bash
devbox setup tls
```

**Workaround without fixing PATH:**

```bash
cd ~/devbox
git pull
bash ~/devbox/bin/devbox setup tls
```

**Verify:**

```bash
readlink -f ~/.local/bin/devbox    # should end with .../devbox/bin/devbox
ls ~/devbox/scripts/lib/corporate-ca.sh
```

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

## Git clone auth fails / no browser SSO

WSL ships its own `git`. It does **not** use Windows Git Credential Manager unless you wire it up. Symptom: `git clone https://...` hangs, fails with 401/403, or never opens a browser.

### Fix (recommended)

1. On **Windows**, install [Git for Windows](https://git-scm.com/download/win) and choose **Git Credential Manager** as the credential helper.
2. In **WSL**:

```bash
cd ~/devbox && git pull
devbox setup git
git config --global --get credential.helper   # should point at .../git-credential-manager.exe
```

3. Clone from `~/code`:

```bash
cd ~/code
git clone https://github.yourcompany.com/team/your-app.git
```

A Windows dialog or browser tab should open for SSO.

`devbox setup git` installs a wrapper at `~/.local/bin/git-credential-manager` so Git does not split `Program Files` paths (error: `/mnt/c/Program: not found`).

### Verify GCM is reachable from WSL

```bash
"/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe" --version
~/.local/bin/git-credential-manager --version
```

### Still no prompt?

- **Stale credentials:** Windows → Credential Manager → remove entries for `git:https://...` or your host, then clone again.
- **SSH URL:** GCM only works for **HTTPS** remotes (`https://...`), not `git@...`.
- **GitHub Enterprise:** use the full `https://github.company.com/...` clone URL.
- **Azure DevOps:** `devbox setup git` sets `credential.https://dev.azure.com.useHttpPath true`.

### Workaround

Clone once from **Windows** (PowerShell in a folder on `C:\`), or use SSH keys in WSL — devbox standard path is HTTPS + GCM.

## Local hostname works in WSL but not in Windows browser

`just setup` updated `/etc/hosts` in **WSL only**. Edge/Chrome on Windows use the **Windows** hosts file.

```bash
grep '\.local' /etc/hosts
devbox setup hosts    # run from WSL, not from elevated PowerShell
```

Elevated PowerShell often has no `wsl` — use `devbox setup hosts` from Ubuntu, then `cd $env:USERPROFILE\AppData\Local\devbox` in elevated PowerShell (not `$env:LOCALAPPDATA` — corporate profiles often break that). See [HOSTS-WINDOWS.md](HOSTS-WINDOWS.md).

See [HOSTS-WINDOWS.md](HOSTS-WINDOWS.md). Use `http://name.local:PORT` — the port is not part of the hosts file.

## Docker

See [DOCKER.md](DOCKER.md) for Docker Desktop + WSL integration.

| Symptom | Fix |
|--------|-----|
| `docker: command not found` | `devbox setup docker` |
| *could not be found in this WSL 2 distro* | Docker Desktop → WSL Integration → enable **$WSL_DISTRO_NAME**; Apply; `wsl --shutdown`; `devbox setup docker` |
| Cannot connect to daemon | Start Docker Desktop; wake from Resource Saver; WSL Integration ON; `wsl --shutdown` |
| `/usr/bin/docker` is a directory | `sudo rm -rf /usr/bin/docker && sudo ln -s /mnt/wsl/docker-desktop/cli-tools/usr/bin/docker /usr/bin/docker` |
| Conflicts / wrong daemon | `sudo apt remove docker.io containerd runc`; disable `sudo systemctl disable --now docker` |

devbox does not run your app in Docker. Use `docker compose` for services (Postgres, Redis). App commands stay `pnpm dev` in WSL.

## Re-run bootstrap

Safe to run again to upgrade pinned tooling:

```bash
cd ~/devbox && git pull && devbox setup
```
