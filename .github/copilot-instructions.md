# Copilot Instructions for winget-pkgs

## Repository Overview

This is the **Windows Package Manager (WinGet) community repository** — a manifest-only repo containing ~415,000+ YAML files describing how to install Windows applications via `winget`. There is no application source code here. The tooling is PowerShell scripts in `Tools/`.

## ⚠️ Critical Performance Rule

**Never recursively scan or search the `manifests/` directory.** It contains hundreds of thousands of files and will cause severe performance issues. Only search within the specific package folder being modified (e.g., `manifests/m/Microsoft/WindowsTerminal/`).

## Manifest Structure

Each package version lives in `manifests/<first-letter>/<Publisher>/<Package>/<Version>/` and requires three files:

| File | ManifestType | Purpose |
|------|-------------|---------|
| `<Id>.yaml` | `version` | Version metadata, links other files |
| `<Id>.installer.yaml` | `installer` | Installer URLs, SHA256 hashes, architecture, installer type |
| `<Id>.locale.en-US.yaml` | `defaultLocale` | Package name, publisher, description, license |

Additional `<Id>.locale.<tag>.yaml` files provide optional translations.

**Key rules:**
- File and folder names are case-sensitive and must match the `PackageIdentifier` exactly
- The version folder name must match `PackageVersion` exactly
- The first directory under `manifests/` is the **lowercase** first letter of the publisher
- Each YAML file includes a `# yaml-language-server: $schema=...` comment pointing to its JSON schema
- Recommended schema version: **1.12.0** (1.10.0 also accepted)
- Supported installer types: MSIX, MSI, APPX, EXE, and font files only — no scripts

## PR Conventions

- Each PR must modify **exactly one package** (one manifest set for one version)
- PRs to `manifests/` trigger an Azure DevOps validation pipeline that runs file validation, URL scanning, SmartScreen checks, manifest policy checks, installation verification, and installer metadata validation
- PRs are auto-merged when the `Validation-Completed` label is applied (squash merge)
- Contributors must sign the Microsoft CLA

## Validation and Testing Commands

Validate a manifest locally:
```powershell
winget validate --manifest <path-to-version-folder>
```

Test installation locally:
```powershell
winget settings --enable LocalManifestFiles
winget install --manifest <path-to-version-folder>
```

Test in Windows Sandbox (preferred — isolated environment):
```powershell
.\Tools\SandboxTest.ps1 <path-to-version-folder>
```

## Tooling

| Tool | Purpose |
|------|---------|
| `Tools/YamlCreate.ps1` | Interactive manifest creation/update helper |
| `Tools/SandboxTest.ps1` | Test manifests in Windows Sandbox |
| `Tools/PRTest.ps1` | PR testing utilities |
| `Tools/Modules/YamlCreate/` | PowerShell module supporting YamlCreate |

**Manifest creation** is best done with [winget-create](https://github.com/microsoft/winget-create):
```powershell
wingetcreate new <InstallerURL>       # New package
wingetcreate update <PackageId>       # Update existing package
```

## CI/CD

- **GitHub Actions**: PSScriptAnalyzer (lints `*.ps1`/`*.psm1` on PR/push) and spell checking
- **Azure DevOps**: Validation and publish pipelines for manifest PRs (defined in `DevOpsPipelineDefinitions/`)

Run PSScriptAnalyzer locally on PowerShell scripts:
```powershell
Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
Get-ChildItem -Recurse -Filter *.ps1 | Invoke-ScriptAnalyzer
```

## Code Style

- YAML: 2-space indentation, CRLF line endings, UTF-8, trailing whitespace trimmed
- YAML fields are PascalCased and must not be duplicated
- PowerShell: follows PSScriptAnalyzer rules
- See `.editorconfig` for full formatting rules
