# Git HTTPS auth (Windows SSO + WSL)

Enterprise clones use **HTTPS** and **Git Credential Manager (GCM)** on Windows so sign-in opens in the browser or a Windows dialog (SSO, MFA, device code). WSL ships its own `git`; it does **not** use Windows GCM until you wire it up.

**Standard path:** GCM on Windows → `devbox setup git` in WSL → `git clone` under `~/code`.

Application repos do **not** need devbox installed; only the machine bootstrap once.

---

## One-time (Windows) — enable GCM

GCM is bundled with [Git for Windows](https://git-scm.com/download/win). You must install or repair Git with GCM selected as the credential helper.

### Fresh install

1. Download and run the Git for Windows installer.
2. On the credential-helper step, choose **Git Credential Manager** (not “None” and not a plain credential store only).
3. Finish the install.

### Already have Git for Windows

**Modify install:** Settings → Apps → **Git** → **Modify** → step through until you can select **Git Credential Manager**, then apply.

**Or set via config** (PowerShell or Git Bash on Windows):

```powershell
git config --global credential.helper manager
```

On older bundles the helper name may be `manager-core` instead of `manager`:

```powershell
git config --global credential.helper manager-core
```

### Verify on Windows

```powershell
git --version
git config --global --get credential.helper
# expect: manager  (or manager-core)

& "C:\Program Files\Git\mingw64\bin\git-credential-manager.exe" --version
```

Test SSO from Windows (optional but confirms GCM before WSL):

```powershell
git clone https://github.yourcompany.com/org/some-repo.git
```

A browser tab or Windows sign-in should appear. Use your company’s **HTTPS** clone URL.

---

## One-time (WSL) — use Windows GCM from Linux git

After GCM works on Windows:

```bash
cd ~/devbox && git pull   # if you already have devbox
devbox setup git
devbox doctor             # should show git credential (Windows GCM): ok
```

`devbox setup git`:

- Prompts for **name** and **email** (when run in a TTY) and sets `git config --global user.name` / `user.email`
- Points WSL `git config --global credential.helper` at `~/.local/bin/git-credential-manager`
- Forwards to `C:\Program Files\Git\mingw64\bin\git-credential-manager.exe`
- Avoids broken paths when Git lives under `Program Files` (error: `/mnt/c/Program: not found`)
- Sets `credential.https://dev.azure.com.useHttpPath true` for Azure DevOps

Verify from WSL:

```bash
git config --global --get credential.helper
"/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe" --version
~/.local/bin/git-credential-manager --version
```

---

## Clone team repos (WSL)

Use **HTTPS** remotes only (`https://...`). SSH (`git@...`) does not use GCM.

```bash
cd ~/code
git clone https://github.yourcompany.com/team/your-app.git
cd your-app
pnpm install
```

On first clone (or after expired tokens), expect a **Windows** browser or dialog — not a prompt inside the Ubuntu terminal.

| Host | Notes |
|------|--------|
| **GitHub Enterprise** | Full URL: `https://github.company.com/org/repo.git` |
| **Azure DevOps** | HTTPS URL; `useHttpPath` is set by `devbox setup git` |
| **GitLab / other** | HTTPS + GCM; host must match your SSO provider |

---

## Troubleshooting

| Symptom | Fix |
|--------|-----|
| `401` / `403` / hang on `git clone` in WSL | Run `devbox setup git`; confirm GCM on Windows (above) |
| No browser / no Windows prompt | Install or repair Git for Windows with GCM; run `devbox setup git`; clone with `https://` |
| `/mnt/c/Program: not found` | Run `devbox setup git` (wrapper fixes spaced paths) |
| `devbox: Git Credential Manager not found` | Install Git for Windows; confirm `git-credential-manager.exe` under `C:\Program Files\Git\mingw64\bin\` |
| Works in PowerShell, not in WSL | Expected until `devbox setup git` — WSL git is separate |
| Wrong or old password | Windows → **Credential Manager** → **Windows Credentials** → remove `git:https://...` for your host → clone again |
| Using `git@host:org/repo.git` | Switch remote to HTTPS or use SSH keys (not the devbox default — see below) |

### SSH remotes (not the default)

devbox does **not** generate or install SSH keys. The standard path is **HTTPS + Git Credential Manager** so SSO/MFA runs in the Windows browser. If your team requires `git@host:...` remotes, configure SSH yourself in WSL (`ssh-keygen`, add the public key to your Git host, `ssh-agent`). That is outside the devbox bootstrap.
| Clone under `/mnt/c/...` | Use `~/code` in WSL (see [ARCHITECTURE.md](ARCHITECTURE.md)) |
| TLS / certificate errors on clone | Fix corporate CA first: [CORPORATE-TLS.md](CORPORATE-TLS.md), `devbox setup tls` |

### Workaround

Clone once from **Windows** (PowerShell) into `C:\Users\You\...`, or copy into WSL — prefer fixing GCM + `devbox setup git` and cloning into `~/code`.

---

## Related

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — quick index for git auth
- [ONBOARDING.md](ONBOARDING.md) — full checklist
- `devbox setup git` — CLI command
- `devbox doctor` — reports GCM status
