# devbox security model

Summary for corporate security review.

## Threat model

- **Install time:** Administrator/developer runs `bash install.sh` from a trusted clone of this repo.
- **Daily use:** Developer runs `devbox repo <name>` only on repositories they trust.
- **Out of scope:** Malicious code inside a cloned repo (mitigated by opt-in hooks and path validation).

## Controls implemented

| Control | Location |
|---------|----------|
| Pinned fnm release + SHA-256 verify | `config/versions.sh`, `install.sh` |
| Pinned `pnpm` / `turbo` versions | `config/versions.sh`, `install.sh` |
| No `curl \| bash` installer | `install.sh` |
| No `npm strict-ssl false` | removed; use `DEVBOX_CA_CERT_FILE` |
| Repo path canonicalization | `bin/devbox` `resolve_repo_dir` |
| Opt-in `.devbox/hooks.sh` | `--trust-hooks` or `DEVBOX_TRUST_HOOKS=1` |
| `DEVBOX_ROOT` / `CODE_DIR` override gate | `DEVBOX_ALLOW_OVERRIDE=1` |
| Safe `devbox env` output | allowlist + secret key redaction |
| Ownership checks | `devbox doctor` |
| `config/env.local` not committed | `.gitignore` |

## Network egress (install)

- `github.com` — fnm release artifact
- `registry.npmjs.org` — global `pnpm`, `turbo`, Node via fnm

## Recommendations for enterprises

1. Mirror fnm/npm artifacts internally and point installs at mirrors.
2. Distribute `DEVBOX_CA_CERT_FILE` via MDM or IT docs instead of disabling TLS verification.
3. Document that `devbox repo --trust-hooks` is equivalent to running arbitrary repo shell code.
4. Set `chmod 600 config/env.local` after creation.

## Updating pinned versions

1. Edit `config/versions.sh`.
2. For fnm bumps, copy SHA-256 from the [GitHub release](https://github.com/Schniz/fnm/releases) asset `digest` field.
3. Re-run `install.sh` and `devbox doctor`.
