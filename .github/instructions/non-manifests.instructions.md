---
applyTo: "!manifests/**/*"
---

# Windows Package Manager Community Repository - Copilot Instructions

## Repository Overview

This is the **Windows Package Manager (WinGet)** community repository containing **~415,000+ manifest files** for software packages installable via `winget`. This repository primarily contains Windows Package Manager manifests, but also includes tooling, documentation, schemas, and CI configuration.

**Key Facts:**
- **Primary Language:** YAML manifest files, PowerShell scripts for tooling
- **Target Runtime:** Windows 10/11, Windows Package Manager client
- **Size:** Large repository with alphabetically organized manifests
- **Schema:** Uses multi-file YAML manifests (version 1.10.0 recommended, 1.9.0 also supported)
- **Supported Installers:** MSIX, MSI, APPX, EXE only (scripts are not supported)

## Critical: How This Repository Works

**This is NOT a traditional code repository.** You typically work with manifest files only **or modifying tooling, documentation, or infrastructure files**, not application source code.

## Instruction Priority

The instructions in the **Performance Rules**, **Allowed Local Searches**, and **Explicit Required Behavior** sections are **mandatory**.  
They override all other information in this file.

Copilot must always follow these rules when performing PR reviews, even if other documentation in this file describes general repository behavior.

## Performance Rules (Very Important)

This repository contains a very large directory: `manifests/`.  
Copilot must **never recursively scan or search the entire `manifests/` folder** during PR reviews. This rule applies even when the pull request does not modify any manifest files.

Large-scale searches cause severe performance issues and timeouts.

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

When reviewing a non-manifest PR:

- Focus on the files changed in the pull request.
- Use nearby documentation, tooling, or configuration files for context when helpful.
- Avoid unnecessary repository-wide searches.

If broader repository context seems needed:

- **Skip the global search** and exactly say: "Global search prevented by repository instructions."
- Continue the review using only the available non-manifest context.
- Do not attempt to search the `manifests/` directory under any circumstances.

---

## Summary

- Only analyze **diffs** and **relevant non-manifest files.**
- Never run expensive global scans.
- Never crawl the entire `manifests/` directory.
- Keep all search operations **package-scoped** for reliability.
