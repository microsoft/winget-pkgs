---
name: create-winget-pkg-skill
description: Create or update WinGet package manifests for a specified PackageIdentifier, including SHA256 hashing of installer URLs, and register the results in YAML following the specified schema.
license: MIT
metadata:
  author: Kazushi Kamegawa
  version: "1.0"
---

# create-winget-pkg-skill

## When to use this skill

Use this skill when:
- The user wants to create WinGet package manifests.
- The user wants to add a new package or update an existing package by PackageIdentifier.
- The task requires computing SHA256 hashes for one or more installer URLs and writing them into YAML.

## Instructions

1. Confirm the target `PackageIdentifier`, target version, and installer URL(s). Ask clarifying questions if anything is missing or ambiguous.
2. Create or update the package manifests for the specified `PackageIdentifier`.
3. For each installer URL, download the file (or otherwise obtain its bytes) and compute the SHA256 hash.
4. Record the SHA256 hash values in the appropriate YAML fields for each installer entry.
5. Ensure the YAML follows the schema at:
  `https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/configuration/configuration.schema.0.2.json`
6. If any requirement is unclear or conflicts with repository guidance, stop and ask the user for clarification.

## Examples

```
Create or update manifests for PackageIdentifier "Contoso.App" version "1.2.3" using two installer URLs.
```
