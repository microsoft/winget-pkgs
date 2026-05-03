---
applyTo: "manifests/**/*"
---

# Windows Package Manager Community Repository - Copilot Instructions

## Repository Overview

This is the **Windows Package Manager (WinGet)** community repository containing **~415,000+ manifest files** for software packages installable via `winget`. The repository is a **manifest-only** repository - no application code, just YAML metadata files describing how to install Windows applications.

**Key Facts:**
- **Primary Language:** YAML manifest files, PowerShell scripts for tooling
- **Target Runtime:** Windows 10/11, Windows Package Manager client
- **Size:** Large repository with alphabetically organized manifests
- **Schema:** Uses multi-file YAML manifests (version 1.12.0 recommended, 1.10.0 also supported)
- **Supported Installers:** msix, appx, msi, exe, zip (with nested type), portable, font (font only in `fonts/` root)
- **Scripts are expressly prohibited** as installers (`.bat`, `.ps1`, etc.)

## Critical: How This Repository Works

**This is NOT a traditional code repository.** You typically work with **manifest files only**, not application source code. Each PR should modify **exactly one package** (one manifest set).

### Manifest Structure (Multi-File Format Required)

Manifests are located in: `manifests/<first-letter>/<Publisher>/<Package>/<Version>/`

For example: `manifests/m/Microsoft/WindowsTerminal/1.0.1401.0/`

**Required files per version:**
1. `<PackageIdentifier>.yaml` - Version file (references other files)
2. `<PackageIdentifier>.installer.yaml` - Installer details, URLs, SHA256
3. `<PackageIdentifier>.locale.en-US.yaml` - Default locale metadata

**File Naming:** Must match `PackageIdentifier` exactly (case-sensitive).

## Instruction Priority

The instructions in the **Performance Rules**, **Allowed Local Searches**, and **Explicit Required Behavior** sections are **mandatory**.
They override all other information in this file.

Copilot must always follow these rules when performing PR reviews, even if other documentation in this file describes general repository behavior.

## Performance Rules (Very Important)

This repository contains a very large directory: `manifests/`.
Copilot must **never recursively scan or search the entire `manifests/` folder** during PR reviews.

Large-scale searches cause severe performance issues and timeouts.

## Allowed Local Searches (Package-Scoped Only)

When Copilot needs to compare or validate manifest conventions (for example, `ReleaseDate`, `InstallerSha256`, or schema field placement):

### Copilot is allowed to:
- Search **ONLY within the package folder of the manifest being modified**.
- This package folder follows the structure: `manifests/<first-letter>/<Publisher>/<Package>/<Version>/`

### Copilot MUST NOT:
- Search sibling publishers
- Search unrelated packages
- Search the entire `manifests/` directory
- Perform global searches to find examples
- Use `search_dir` on `manifests/` or any directory wider than the package root

## Allowed Searches Outside the Manifests Directory

Copilot is allowed to search in **documentation folders** to understand schema rules, authoring guidelines, and repository conventions. These include, but are not limited to:

- `doc/`
- `schemas/`
- `README.md`
- `CONTRIBUTING.md`
- `PULL_REQUEST_TEMPLATE.md`
- Any other non-manifest documentation files

These locations are safe to search because they contain guidance, not large numbers of manifest files.

However, **Copilot must still avoid recursive searches of the `manifests/` directory**, except for the package-scoped searches described earlier.

---

## Explicit Required Behavior

When reviewing a PR:

- Focus on **only the changed manifest files** and their immediate package folder.
- If searching for "similar manifests" or examples:
- Restrict the search scope to the **same package root**, e.g.:

  For:
  ```
  manifests/m/Microsoft/WSL/2.6.2/
  ```
  Only search within:
  ```
  manifests/m/Microsoft/WSL/
  manifests/m/Microsoft/
  ```

- DO NOT search:
  ```
  manifests/m/*
  manifests/*
  ```
  or the entire repo for matching fields

- If broader repo context seems needed:
  - **Skip the global search** and exactly say: "Global search prevented by repository instructions."
  - Continue the review using only local context

---

## Review Guidance: What Constitutes an Actual Problem

This section defines what the review agent should and should not flag. The goal is high signal-to-noise — only flag real issues, not style preferences.

### ✅ DO Flag These as Actual Problems

1. **Wrong field usage**
   - A copyright notice (e.g., `Copyright © 2024 Contoso`) placed in the `License` field
   - A license name (e.g., `MIT`, `Apache 2.0`) placed in the `Copyright` field
   - License-like text in `Copyright`, or copyright-like text in `License`

2. **Mismatched identifiers or versions**
   - `PackageIdentifier` not matching the folder path (case-sensitive)
   - `PackageVersion` not matching the version folder name

3. **Singleton manifest type** — Singleton manifests (`ManifestType: singleton`) are prohibited in the community repository. Only multi-file manifests are accepted.

4. **Scripts as installers** — `.bat`, `.cmd`, `.ps1`, `.vbs`, and other script files are expressly disallowed as installer types.

5. **Agreements with body text from non-verified developer** — The `Agreement` field (agreement body text) is only allowed for verified developers. Community PRs must not include `Agreement` text; only `AgreementLabel` and `AgreementUrl` are permitted.

6. **Installer URLs from unofficial sources** — Installer URLs should be discoverable on the publisher's official website or CDN. URLs pointing to unofficial mirrors or unrelated third-party hosts are a concern.

7. **Architecture mismatch** — The `Architecture` field should reflect the installed binaries, not the installer itself. An x86 installer that installs x64 binaries should declare `x64`.

### ❌ Do NOT Flag These (Not Actionable Issues)

1. **`License` not matching SPDX format** — The `License` field is free-form text. Values like `MIT`, `Apache 2.0`, `GPLv2`, `Freeware`, `Proprietary`, or `Copyright (c) Contoso` are all acceptable. Do not require exact SPDX identifiers.

2. **Minor formatting** — Trailing whitespace, missing periods, inconsistent casing, and similar style issues do not impact the functionality and should not be flagged in review.

3. **Optional fields being absent** — Many fields are optional: `Author`, `Description`, `Tags`, `ReleaseNotes`, `ReleaseNotesUrl`, `Moniker`, `LicenseUrl`, `CopyrightUrl`, `PublisherUrl`, `PublisherSupportUrl`, `PrivacyUrl`, etc. Their absence is not a problem even if previous versions had them.

4. **Version format style** — WinGet supports many version formats (semver, date-based, build numbers, etc.). Do not flag unconventional version strings unless they cause an actual sorting or matching issue.

5. **Field order within the YAML** — YAML field order within a manifest file does not need to match a specific sequence.

---

## Field Semantics Reference

### `License` vs `Copyright`

These are distinct and commonly confused:

| Field | Purpose | Examples | Common Mistake |
|-------|---------|---------|---------------|
| `License` | The license governing use/distribution of the software. **Free-form text, no SPDX requirement.** | `MIT`, `Apache 2.0`, `GPL-3.0`, `Freeware`, `Proprietary`, `Commercial` | Putting a copyright notice here |
| `Copyright` | The copyright notice for the package. | `Copyright © 2024 Contoso Ltd.`, `Copyright (c) Contoso` | Putting the license name here |

> From the schema docs: *"Please note that a copyright is not considered a license. If there is no available information on a product's license, 'Proprietary' should be the value in this field."*

### Installer Types

| Type | Notes |
|------|-------|
| `msix` / `appx` | MSIX/APPX packages |
| `msi` | Windows Installer packages |
| `exe` | EXE-based installers |
| `zip` | Compressed archives; requires `NestedInstallerType` and `NestedInstallerFiles` |
| `portable` | Portable executables |
| `font` | Font files; **only permitted in `fonts/` root, not `manifests/`** |

---

## Key Policies Summary (from doc/Policies.md and doc/Authoring.md)

- **Silent install required**: Installers may display a UI, but users must not need to interact with it for successful installation.
- **Singleton manifests prohibited**: Multi-file format only.
- **Agreements**: Manifests containing agreements require a Microsoft review. Only verified developers may include `Agreement` body text.
- **Font files**: Must be submitted under the `fonts/` root, not `manifests/`.

---

## Summary

- Only analyze **diffs** and **local package manifests**.
- Never run expensive global scans.
- Never crawl the entire `manifests/` directory.
- Keep all search operations **package-scoped** for reliability.
