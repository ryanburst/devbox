# Optional per-repo devbox files

**Application repos do not need these files** to build or run. They are optional conveniences when using `devbox repo <name>`.

| File | Purpose |
|------|---------|
| `profile.env` | Extra environment variables for `devbox repo` |
| `hooks.sh` | Shell run only with `devbox repo --trust-hooks` (trusted repos) |

Copy into your repo as `.devbox/profile.env` or `.devbox/hooks.sh` only if your team wants this pattern.

Normal workflow without devbox in the repo:

```bash
cd ~/code/your-app
pnpm install && pnpm dev
```
