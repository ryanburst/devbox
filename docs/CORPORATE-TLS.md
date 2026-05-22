# Corporate TLS (Zscaler and inspection proxies)

WSL Ubuntu does **not** automatically trust certificates installed on Windows. Until the corporate root is added in WSL, `curl`, `fnm`, and `npm` fail with errors like:

- `unable to get local issuer certificate`
- `can't get remote versions file: error sending request for url`

`install.sh` installs the CA **before** downloading fnm or Node when `DEVBOX_CA_CERT_FILE` is set in `config/env.local`.

## Recommended order (interactive)

```bash
cd ~/devbox
devbox setup tls    # guided: Zscaler export, cert file, or skip
devbox setup        # full wizard including install.sh
```

Or manually:

```bash
# 1. Configure CA (pick one method below)
# 2. Verify curl
curl -fsSL https://nodejs.org/dist/index.json | head -c 80

# 3. Run bootstrap
bash install.sh
```

## Method 1 — sync from Windows (WSL interop)

Requires: WSL2, Zscaler on Windows, `powershell.exe` available from WSL (`/mnt/c/Windows/...`).

```bash
cd ~/devbox
bash scripts/sync-zscaler-ca.sh
bash install.sh
```

This runs `scripts/windows/Export-ZscalerCa.ps1` on the **host**, writes `config/zscaler-root.cer`, and sets `config/env.local`.

## Method 2 — Export on Windows, copy to WSL

Use when sync cannot run from WSL (no interop) or you prefer manual control.

**Windows PowerShell** (repo on Windows filesystem):

```powershell
cd C:\Users\<You>\devbox
.\scripts\windows\Export-ZscalerCa.ps1
# Output: %USERPROFILE%\.devbox\certs\zscaler-root.cer
```

**WSL:**

```bash
cp /mnt/c/Users/<You>/.devbox/certs/zscaler-root.cer ~/devbox/config/zscaler-root.cer
printf '%s\n' 'export DEVBOX_CA_CERT_FILE=$HOME/devbox/config/zscaler-root.cer' >> ~/devbox/config/env.local
chmod 600 ~/devbox/config/env.local
bash ~/devbox/install.sh
```

## Method 3 — IT-provided certificate

```bash
cp /path/to/company-root.pem ~/devbox/config/company-root.pem
cp config/env.example config/env.local
# Set: export DEVBOX_CA_CERT_FILE=$HOME/devbox/config/company-root.pem
chmod 600 config/env.local
bash install.sh
```

## What install.sh does

1. Copies the cert to `/usr/local/share/ca-certificates/`
2. Runs `update-ca-certificates`
3. Sets `SSL_CERT_FILE` and `NODE_EXTRA_CA_CERTS` for fnm, curl, and npm

## List Zscaler certs (no export)

```powershell
.\scripts\windows\Export-ZscalerCa.ps1 -ListOnly
```

## Proxy

If your company requires an HTTP proxy, set in `config/env.local` **before** `install.sh`:

```bash
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
export NO_PROXY=localhost,127.0.0.1,.company.com
```

Do **not** use `npm config set strict-ssl false`.
