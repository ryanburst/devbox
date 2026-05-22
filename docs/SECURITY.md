# devbox security model

devbox is a **machine bootstrap** repository, not a runtime dependency of application code.

## Threat model

- **Install time:** Developer runs `bash install.sh` from a trusted clone of this repo on their WSL distro.
- **Daily use (typical):** Developer runs `pnpm` / repo scripts in `~/code` without invoking devbox.
- **Optional CLI:** `devbox repo` may source trusted profile/hook files — see below.

## Scope

| In scope | Out of scope |
|----------|----------------|
| Toolchain install (fnm, pnpm, turbo) | Application repo CI/CD |
| WSL CA trust for corporate TLS | Windows script execution policy (bypassed by using WSL, not by weakening Windows) |
| Optional `devbox` CLI helpers | Mandatory per-repo devbox configuration |

## Controls implemented

| Control | Location |
|---------|----------|
| Pinned fnm release + SHA-256 verify | `config/versions.sh`, `install.sh` |
| Pinned `pnpm` / `turbo` versions | `config/versions.sh`, `install.sh` |
| Corporate CA before HTTPS downloads | `install.sh` (`configure_corporate_ca` before `fnm install`) |
| No `curl \| bash` installer | `install.sh` |
| No `npm strict-ssl false` | use `DEVBOX_CA_CERT_FILE` |
| Repo path canonicalization | `bin/devbox` `resolve_repo_dir` |
| Opt-in `.devbox/hooks.sh` | `--trust-hooks` or `DEVBOX_TRUST_HOOKS=1` |
| `DEVBOX_ROOT` / `CODE_DIR` override gate | `DEVBOX_ALLOW_OVERRIDE=1` |
| Safe `devbox env` output | allowlist + secret key redaction |
| Ownership checks | `devbox doctor` |
| `config/env.local` / exported CAs not committed | `.gitignore` |

## Network egress (install)

- `github.com` — fnm release artifact
- `registry.npmjs.org` — global `pnpm`, `turbo`, Node via fnm
- `nodejs.org` — fnm version index and Node binaries

## Zscaler (one-time host → WSL)

`scripts/sync-zscaler-ca.sh` is a **machine onboarding** helper: it exports CAs from Windows stores into WSL `config/` for `install.sh`. It is not used by application repositories.

Prerequisites: Zscaler on Windows; WSL interop. Alternative: manual CA file from IT — [CORPORATE-TLS.md](CORPORATE-TLS.md).

## Recommendations for enterprises

1. Mirror fnm/npm artifacts internally where required.
2. Distribute corporate root CA via MDM or IT docs (`DEVBOX_CA_CERT_FILE`).
3. Document that `devbox repo --trust-hooks` runs arbitrary shell from a repo.
4. `chmod 600 config/env.local` after creation.
5. Keep application repos free of devbox-specific required hooks unless explicitly reviewed.

## Updating pinned versions

1. Edit `config/versions.sh`.
2. For fnm bumps, copy SHA-256 from the [GitHub release](https://github.com/Schniz/fnm/releases) asset `digest` field.
3. Re-run `bash install.sh` and `devbox doctor`.
