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
- **Schema:** Uses multi-file YAML manifests (version 1.10.0 recommended, 1.9.0 also supported)
- **Supported Installers:** MSIX, MSI, APPX, EXE only (scripts are not supported)

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

## Summary

- Only analyze **diffs** and **local package manifests**.
- Never run expensive global scans.
- Never crawl the entire `manifests/` directory.
- Keep all search operations **package-scoped** for reliability.
