# Building the portable executable

The readable PowerShell files are the source of truth. `Rescue Files.exe` is a generated release artifact and is intentionally excluded from Git.

## Requirements

- Windows PowerShell 5.1
- The `ps2exe` PowerShell Gallery module, version 1.0.18

From Windows PowerShell, install the builder for the current user:

```powershell
Install-Module ps2exe -RequiredVersion 1.0.18 -Scope CurrentUser
```

Then run this command from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\build\Build-PortableExe.ps1" -Version 1.0.0.0
```

The one-process execution-policy bypass is needed on Windows computers that block local scripts. It does not permanently change the computer's execution policy.

The result is `dist\Rescue Files.exe`. It is a console executable with an administrator manifest. The build combines the main script and core module in a temporary location, invokes PS2EXE, and removes the temporary combined script afterward.

The executable is not a native rewrite. PS2EXE embeds the PowerShell program in a Windows executable host. No separate project files need to accompany it on the rescue computer.

## Release signing

Sign public releases with a trusted Windows code-signing certificate. Signing reduces frightening SmartScreen and antivirus warnings, although reputation systems can still warn about a new release. Never commit a signing certificate or its password to this repository.

The Windows CI job builds the same executable and uploads it as the `Rescue-Files-portable` workflow artifact. CI does not sign it.
