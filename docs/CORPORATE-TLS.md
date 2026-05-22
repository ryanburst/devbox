# Corporate TLS (Zscaler and inspection proxies)

WSL Ubuntu does **not** automatically trust certificates installed on Windows. Until the corporate root is added in WSL, `curl`, `fnm`, and `npm` fail with errors like:

- `unable to get local issuer certificate`
- `can't get remote versions file: error sending request for url`

`devbox setup` configures TLS **before** installing the toolchain.

## Recommended order

```bash
cd ~/devbox
bash install.sh          # devbox CLI on PATH
exec bash
devbox setup             # TLS first, then toolchain
```

TLS only:

```bash
devbox setup tls
```

After `install.sh`, use `devbox` (not `bash bin/devbox`).

Or manually:

```bash
# 1. Configure CA (pick one method below)
# 2. Verify curl
curl -fsSL https://nodejs.org/dist/index.json | head -c 80

# 3. Run toolchain
devbox setup
```

## Method 1 — sync from Windows (WSL interop)

Requires: WSL2, Zscaler on Windows, `powershell.exe` available from WSL.

```bash
cd ~/devbox
bash scripts/sync-zscaler-ca.sh
devbox setup tls    # apply CA + verify
```

## Method 2 — Export on Windows, copy to WSL

**Windows PowerShell:**

```powershell
cd C:\Users\<You>\devbox
.\scripts\windows\Export-ZscalerCa.ps1
```

**WSL:**

```bash
cp /mnt/c/Users/<You>/.devbox/certs/zscaler-root.cer ~/devbox/config/zscaler-root.cer
devbox setup tls
```

## Method 3 — IT-provided certificate

```bash
cp /path/to/company-root.pem ~/devbox/config/company-root.pem
cp config/env.example config/env.local
# Set: export DEVBOX_CA_CERT_FILE=$HOME/devbox/config/company-root.pem
chmod 600 config/env.local
devbox setup tls
```

## What the toolchain install does

When `DEVBOX_CA_CERT_FILE` is set, `scripts/install-toolchain.sh`:

1. Copies the cert to `/usr/local/share/ca-certificates/`
2. Runs `update-ca-certificates`
3. Sets `SSL_CERT_FILE` and `NODE_EXTRA_CA_CERTS` for fnm, curl, and npm

## List Zscaler certs (no export)

```powershell
.\scripts\windows\Export-ZscalerCa.ps1 -ListOnly
```

## Proxy

If your company requires an HTTP proxy, set in `config/env.local` **before** `devbox setup`:

```bash
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
export NO_PROXY=localhost,127.0.0.1,.company.com
```

Do **not** use `npm config set strict-ssl false`.
