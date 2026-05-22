# Reset devbox (retry install from scratch)

Undo what `bash install.sh` and `devbox setup` changed on **this WSL machine**. The devbox **git clone is not deleted** so you can run install again from the same folder.

## Quick reset (CLI + shell only)

Back to “cloned repo, never ran `install.sh`” for PATH and `~/.bashrc`:

```bash
devbox reset
exec bash
cd ~/devbox
bash install.sh
devbox setup
```

## Full reset (CLI + shell + toolchain)

Also removes fnm, global pnpm/turbo (if npm works), optional pnpm store, corporate CA, and `config/env.local`:

```bash
devbox reset --full
exec bash
cd ~/devbox
bash install.sh
devbox setup
```

## Options

| Flag | Effect |
|------|--------|
| `--full` | fnm, npm globals, pnpm store (prompt), system CA, `config/env.local` (prompt) |
| `--yes` | Skip confirmation prompts |
| `--purge-code` | Remove `~/code` (prompt) |
| `--keep-code` | Default — keep `~/code` |

## What gets removed

| Item | Default reset | `--full` |
|------|---------------|----------|
| `~/.local/bin/devbox` | yes | yes |
| `# devbox` blocks in `~/.bashrc` | yes (backup `~/.bashrc.bak.*`) | yes |
| `~/.local/share/fnm`, `~/.fnm` | no | yes |
| Global `pnpm`, `turbo` | no | yes |
| `~/.pnpm-store` | no | prompt |
| `/usr/local/share/ca-certificates/devbox-corporate.crt` | no | prompt (sudo) |
| `~/devbox` clone | **never** | **never** |
| Clones under `~/code` | no | no (unless `--purge-code`) |

## Windows (optional)

Zscaler export on the host:

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\.devbox" -ErrorAction SilentlyContinue
```

## Nuclear: remove WSL Ubuntu entirely

See README discussion or unregister only the Ubuntu distro:

```powershell
wsl --shutdown
wsl --unregister Ubuntu
```

`docker-desktop` WSL distros are unchanged.
