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

Many companies block classic **Run as administrator** (domain admin + password) but allow **Run with elevated access** (business justification).

1. In WSL: `devbox setup hosts`
2. On Windows: **Win+R** → `%LOCALAPPDATA%\devbox`
3. Right-click **`apply-dev-hosts.cmd`** → **Run with elevated access**  
   (use `.cmd` so the window stays open; `.ps1` alone may flash and close on error)

   Or open PowerShell via your company’s elevated-access menu, then:

```powershell
cd $env:LOCALAPPDATA\devbox
.\apply-dev-hosts.cmd
```

If a window disappears immediately, open **`apply-dev-hosts.log`** in the same folder for the error (often “not elevated”).

4. `ipconfig /flushdns`

Do **not** rely on the automatic UAC popup from devbox unless you set `DEVBOX_HOSTS_USE_RUNAS=1` (personal machines only).

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
