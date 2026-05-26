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

Or:

```bash
bash ~/devbox/scripts/sync-hosts-to-windows.sh
```

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
