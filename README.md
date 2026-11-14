# Zellij Chocolatey packages

Chocolatey packages for [Zellij](https://github.com/zellij-org/zellij), the terminal workspace / multiplexer.

| Package | What it is |
| --- | --- |
| `zellij.portable` | Downloads the official `zellij-x86_64-pc-windows-msvc.zip` from GitHub releases, verifies its SHA256, extracts it and shims `zellij.exe` / `zellij-terminal.exe` onto PATH. |
| `zellij` | Meta package that depends on the exact matching `zellij.portable` version. This is what users install. |

```powershell
choco install zellij
```

## Layout

```
zellij.portable/
  zellij.portable.nuspec
  tools/chocolateyInstall.ps1     # url + checksum rewritten by update.ps1
  tools/zellij-terminal.exe.gui   # tells the shim generator zellij-terminal is a GUI app
zellij/
  zellij.nuspec                   # depends on zellij.portable [x.y.z]
update.ps1                        # bump to latest (or -Tag) release and pack into .\out
.github/workflows/update.yml      # daily: update, test install, commit, push to Chocolatey
```

## Updating locally

```powershell
.\update.ps1                 # latest release, no-op if already current
.\update.ps1 -Tag v0.46.0    # specific release
.\update.ps1 -Force          # repack even if unchanged
```

## Testing locally (elevated PowerShell)

```powershell
choco install zellij --source "$PWD\out" -y
zellij --version
choco uninstall zellij zellij.portable -y
```

## Publishing

1. Create an account at <https://community.chocolatey.org> and copy your API key from your account page.
2. Push the dependency first, then the meta package:

   ```powershell
   choco push out\zellij.portable.<version>.nupkg --source https://push.chocolatey.org/ --api-key <key>
   choco push out\zellij.<version>.nupkg          --source https://push.chocolatey.org/ --api-key <key>
   ```

3. For automatic updates, add the key as the `CHOCO_API_KEY` repository secret. The workflow runs daily and can be triggered manually.

New packages go through community moderation (automated validation + verification, then a human reviewer) before they are listed.
