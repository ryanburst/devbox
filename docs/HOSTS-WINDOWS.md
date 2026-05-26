# Hosts file: WSL vs Windows browser

`just setup` (and similar) usually edits **`/etc/hosts` inside WSL**. That works for `curl` in Ubuntu.

**Windows browsers** (Edge, Chrome) use:

`C:\Windows\System32\drivers\etc\hosts`

They do **not** read WSL’s `/etc/hosts`. Symptom: `just setup` succeeded, but `http://something.local:8900` does not resolve in the browser on Windows.

## Fix

After your repo setup in WSL:

```bash
# 1. Confirm entries exist in WSL
grep -E '\.local|127\.0\.0\.1' /etc/hosts | grep -v '127.0.0.1\s*localhost'

# 2. Sync to Windows (UAC / Admin prompt)
devbox setup hosts
```

Run **`devbox setup hosts` from WSL** (normal Ubuntu terminal). Devbox prepares:

`%LOCALAPPDATA%\devbox\apply-dev-hosts.ps1`

### Corporate elevation (no domain-admin password)

Many companies block **Run as administrator** (domain password) but allow **Run with elevated access** on **PowerShell** — often **not** on `.cmd` or `.ps1` files in Explorer.

**Recommended workflow:**

1. In WSL: `devbox setup hosts`
2. On Windows: **Start** → search **PowerShell**
3. Right-click **Windows PowerShell** → **Run with elevated access** (company menu)
4. In that window, paste:

```powershell
cd $env:LOCALAPPDATA\devbox
powershell -ExecutionPolicy Bypass -File .\apply-dev-hosts.ps1
```

5. Wait for **Success**, press Enter to close
6. Optional: `ipconfig /flushdns`

**Win+R** → `%LOCALAPPDATA%\devbox` opens the folder; read **`START-HERE-hosts.txt`** there.

If a window flashes and closes, open **`apply-dev-hosts.log`** (often “not elevated” — you must start from step 2–3, not double-click a file).

Do **not** rely on devbox’s automatic UAC popup unless `DEVBOX_HOSTS_USE_RUNAS=1` (personal machines).

Elevated PowerShell often **cannot** run `wsl` — always start from WSL for `devbox setup hosts`, then finish on Windows as above.

Or:

```bash
bash ~/devbox/scripts/sync-hosts-to-windows.sh
```

### Manual fallback (elevated Notepad)

If UAC automation is blocked:

1. In **WSL**: `grep '\.local' /etc/hosts`
2. **Windows** → Notepad **Run as administrator** → open `C:\Windows\System32\drivers\etc\hosts`
3. Paste the same `127.0.0.1 yourname.local` lines, save
4. `ipconfig /flushdns` in Admin PowerShell

Then in **PowerShell (Admin)** optional:

```powershell
ipconfig /flushdns
```

## URL shape

The hosts file maps **hostname → IP** only, not port.

| Correct | Wrong |
|---------|--------|
| `http://company.local:8900` | Putting `:8900` in the hosts file |
| Entry: `127.0.0.1 company.local` | Expecting hosts to set the port |

Verify the app is listening on that port in WSL:

```bash
curl -sI "http://company.local:8900"   # or your hostname
```

From **Windows** PowerShell:

```powershell
curl.exe -sI "http://company.local:8900"
```

If WSL works but Windows does not, sync hosts (above). If neither works, check the dev server bind address (`0.0.0.0` vs `127.0.0.1`) and that containers/services are up.

## Manual edit (Windows)

1. Notepad **as Administrator** → open `C:\Windows\System32\drivers\etc\hosts`
2. Add the same lines as in WSL `/etc/hosts` (e.g. `127.0.0.1 company.local`)
3. Save, flush DNS

## For repo maintainers

Document that Windows developers must run `devbox setup hosts` after `just setup`, or provide a Windows script that edits the Windows hosts file directly.
