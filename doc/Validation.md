# Manifest Validation

When you submit a pull request to this repository, a **GitHub App** automatically runs a series of validation checks on your manifest and installers. The app reports its progress directly on the PR as [GitHub Check Runs](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/about-status-checks), providing real-time feedback without requiring you to navigate to an external build system.

## Overview

The GitHub App runs **10 sequential validation steps**, each building on the results of the previous one. If a step fails, subsequent steps that depend on it may be skipped. Results are surfaced directly on the PR's **Checks** tab and, when relevant, as comments on the PR itself.

If you need to re-trigger validation — for example, after fixing a hash mismatch or a transient network error — a moderator can comment `@wingetbot run` on your PR.

> [!NOTE]
> The validation GitHub App replaced the previous Azure DevOps (ADO) pipeline integration. The new app surfaces results directly on the PR and enables each validation step to run and report independently, reducing the need for a full re-validation after every change.

---

## The 10 Validation Steps

### 01. Pull Request Validation

**What it checks:** The structural integrity of the PR itself — not the manifest content, but the way the PR is organized.

This step verifies:

- The PR contains **exactly one package version** (one multi-file manifest set for a single `PackageIdentifier` and `PackageVersion`).
- The PR contains **only manifest files**. Changes to documentation, tooling, spelling files, or any other non-manifest content must be submitted in a separate PR.
- The PR does not introduce conflicts with the base branch.

**Common failure causes:**

- Including more than one package or version in a single PR.
- Mixing manifest changes with non-manifest file changes (e.g., `README.md`, `doc/` files, spell-check dictionaries).
- Merge conflicts with the base branch.

**How to fix:** See the [first-time contributor checklist](FirstContribution.md) for guidance on PR structure. Resolve merge conflicts and separate non-manifest changes into their own PR.

> [!NOTE]
> The [Contributor License Agreement (CLA)](https://cla.opensource.microsoft.com/microsoft/winget-pkgs) is checked by a separate automated process, not by this validation step. If the CLA has not been signed, a `Needs-CLA` label is applied and the PR cannot be merged until it is resolved.

**Labels applied on failure:** `PullRequest-Error`, `Validation-Merge-Conflict`

---

### 02. Manifest Validation

**What it checks:** Whether all manifest files conform to the [manifest schema specification](manifest/).

This step validates:

- YAML syntax is well-formed (correct indentation, no tab characters, valid data types).
- All required fields are present (`PackageIdentifier`, `PackageVersion`, `PackageName`, `Publisher`, `License`, `InstallerType`, `InstallerUrl`, `InstallerSha256`, and others depending on manifest type).
- Field values match their expected types and formats (e.g., URLs are valid URIs, `ManifestVersion` uses a supported version).
- The manifest uses a **multi-file format** — singleton manifests (`ManifestType: singleton`) are not permitted in the community repository.
- The `ManifestVersion` is a supported schema version.
- Each manifest file includes the correct `# yaml-language-server: $schema=...` header.
- The directory path and file names exactly match the `PackageIdentifier` and `PackageVersion` declared in the manifest (case-sensitive).

**Common failure causes:**

- Invalid YAML syntax (e.g., bad indentation, use of tabs, unquoted special characters).
- Missing required fields.
- Using a deprecated or unsupported `ManifestVersion`.
- Using a singleton manifest type.
- File or directory name casing mismatch with `PackageIdentifier`.

**How to fix:**

```powershell
winget validate --manifest <path-to-manifest>
```

Address all reported errors. Refer to the [manifest schema documentation](manifest/) for field definitions and requirements.

**Labels applied on failure:** `Manifest-Validation-Error`, `Manifest-Version-Deprecated`, `Manifest-Path-Error`

---

### 03. URLs Validation

**What it checks:** Whether the URLs declared in the manifest are valid, reachable, and use HTTPS.

This step verifies:

- All installer URLs (`InstallerUrl`) and metadata URLs (`PackageUrl`, `PublisherUrl`, `LicenseUrl`, etc.) are syntactically valid.
- Installer URLs respond with a successful HTTP status code (not 4xx or 5xx).
- Installer URLs use **HTTPS** (not plain HTTP).
- URLs do not point to sites flagged by Microsoft Defender SmartScreen as malicious or having low reputation.

> [!NOTE]
> This step checks URL reachability from the validation infrastructure's network. Some servers may block requests from Azure IP ranges.

**Common failure causes:**

- The installer URL returns a 404 (file not found) or 403 (forbidden) response.
- The URL uses `http://` instead of `https://`.
- The server blocks automated requests from the validation infrastructure's IP range.
- The URL has a poor SmartScreen reputation.

**How to fix:** Verify the URL is correct, publicly accessible, and uses HTTPS. If the URL reputation is the issue, [submit the URL for review](https://www.microsoft.com/wdsi/filesubmission/).

**Labels applied on failure:** `URL-Validation-Error`, `Validation-HTTP-Error`, `Error-Installer-Availability`

---

### 04. URL Domain Validation

**What it checks:** Whether the domain of the `InstallerUrl` is an approved, official source for the publisher.

The Windows Package Manager [policy for manifest URLs](Policies.md#manifest-urls) requires installers to come from official publisher sources — the domain must be discoverable by navigating from the publisher's official website. This step checks the installer URL's domain against the expected domain for the publisher and flags indirect sources, unofficial mirrors, download aggregators, and URL shorteners.

This step verifies:

- The `InstallerUrl` domain matches the expected domain for the publisher.
- The URL does not use a URL shortener or redirect service.
- The URL is not a third-party mirror or download aggregator.
- If a redirect is used, the final destination URL is from an approved domain.

> [!TIP]
> Including `PackageUrl` in your manifest and ensuring the `InstallerUrl` can be reached by navigating from that URL helps moderators and the validation system confirm the URL is from an official source.

**Common failure causes:**

- Using a CDN, mirror, or download aggregator URL instead of the publisher's direct download link.
- Using a URL shortener (e.g., `bit.ly`, `tinyurl.com`).
- Using a redirect URL rather than the final resolved URL.

**How to fix:** Use the direct URL from the publisher's official release location. If the URL redirects, follow the redirect chain to find the final URL. A PowerShell snippet to resolve redirect chains is available in the [ValidationFailureGuide](ValidationFailureGuide.md#validation-indirect-url).

**Labels applied on failure:** `Validation-Domain`, `Validation-Unapproved-URL`, `Validation-Indirect-URL`

---

### 05. Manifest Policy Validation

**What it checks:** Whether the manifest metadata complies with the [Windows Package Manager community repository policies](Policies.md).

This step scans manifest fields — including `PackageName`, `Publisher`, `Description`, `Tags`, `ReleaseNotes`, and others — against a set of content policies defined by Microsoft. The checks align with the [Windows Package Manager Policies](https://learn.microsoft.com/windows/package-manager/package/windows-package-manager-policies) published on Microsoft Learn.

Policy checks include:

| Policy | Description |
|---|---|
| **2.1 General Content Requirements** | Content must be safe for a general audience. |
| **2.2 Names, Logos, and Third-Party Content** | Must not misuse trademarks or impersonate other software. |
| **2.3 Risk of Harm** | Must not describe or facilitate harmful activities. |
| **2.4 Defamatory Content** | Must not be defamatory, libelous, or threatening. |
| **2.5 Offensive Content** | Must not contain unnecessarily offensive language or imagery references. |
| **2.6 Alcohol, Tobacco, Weapons, and Drugs** | Must comply with applicable laws and age-restriction requirements. |
| **2.7 Adult Content** | Adult content is not permitted. |
| **2.8 Illegal Activity** | Must not facilitate illegal activities. |
| **2.9 Excessive Profanity** | Must not contain excessive profanity. |
| **2.10 Country/Region-Specific Requirements** | Must comply with regional legal requirements. |
| **2.11 Age Ratings** | Must accurately reflect the target audience age group. |
| **2.12 User Generated Content** | User-generated content must be moderated appropriately. |

A policy violation does not automatically block the PR — it triggers additional **manual review** by the WinGet team. The PR will have a `Policy-Test-2.x` label applied indicating which policy requires review.

**Labels applied on review:** `Policy-Test-2.1` through `Policy-Test-2.12`

---

### 06. Catalog Content Verification

**What it checks:** Whether merging the PR would result in a valid, buildable catalog.

Rather than checking the manifest in isolation, this step simulates the effect of merging the PR and verifies that the full Windows Package Manager catalog would still build successfully. It focuses on cross-package relationships and version range integrity.

This step checks for:

- **DisplayVersion range overlaps** — the most common failure. If the `DisplayVersion` written to the registry by this installer overlaps with the version range covered by an existing manifest version, the catalog cannot correctly map installed versions to available updates. This typically occurs when `AppsAndFeaturesEntries` → `DisplayVersion` is incorrect. See [When is AppsAndFeaturesEntries needed?](Authoring.md#when-is-appsandfeaturesentries-needed) for guidance.
- **Dependency existence** — if the manifest declares `Dependencies`, this step verifies that every referenced package and version actually exists in the catalog.
- **Removal safety** — if the PR is removing a package or version, this step verifies that no other packages in the catalog declare a dependency on it. Removing a package that other packages depend on would break those dependents.

**Common failure causes:**

- Missing or incorrect `DisplayVersion` in `AppsAndFeaturesEntries`, causing the version range for this manifest to overlap with an adjacent version.
- Declaring a dependency on a package or version that does not exist in the catalog.
- Removing a package that is listed as a dependency by one or more other packages.

**How to fix:** If the failure is a `DisplayVersion` overlap, review the AppsAndFeaturesEntries guidance in [Authoring.md](Authoring.md) and ensure `DisplayVersion` accurately reflects what the installer writes to the registry.

**Labels applied on review:** `Manifest-AppsAndFeaturesVersion-Error`

---

### 07. Installers Scan

**What it checks:** The installer binaries themselves, using static analysis and multiple antivirus engines.

This step downloads each installer declared in the manifest and performs:

- **SHA256 hash verification** — the hash of the downloaded file is compared against the `InstallerSha256` value in the manifest. A mismatch causes this step to fail immediately.
- **Static antivirus scanning** — the installer binary is scanned with multiple antivirus engines for known malware signatures and heuristic detection.
- **Potentially Unwanted Application (PUA) detection** — the installer is checked against Microsoft's [PUA criteria](https://docs.microsoft.com/windows/security/threat-protection/intelligence/criteria). Per the [repository security policy](Policies.md#security-scans-and-potentially-unwanted-applications-pua), a package that is flagged as PUA **cannot be accepted**, regardless of the application's legitimacy.

> [!IMPORTANT]
> If your installer is flagged by a security scan, you can [submit the file to Microsoft Defender for Business analysis](https://www.microsoft.com/wdsi/filesubmission) as a potential false positive. Include the PR URL in your submission. After the false positive is resolved, a moderator can re-trigger validation with `@wingetbot run`.

**Common failure causes:**

- The `InstallerSha256` does not match the downloaded file. This often happens with "vanity URLs" that always point to the latest version — the file may have been updated after you generated the hash.
- The installer is detected as malware or PUA by one or more antivirus engines.
- The installer URL has become unreachable since the manifest was authored.

**How to fix:**

```powershell
# Recalculate the hash after downloading the installer
winget hash <path-to-installer>
```

Update the `InstallerSha256` value in the manifest if the hash has changed. Use a version-specific URL where possible to avoid future hash mismatches.

**Labels applied on failure:** `Binary-Validation-Error`, `Error-Hash-Mismatch`, `Error-Installer-Availability`

---

### 08. Installation Validation

**What it checks:** Whether the installer works correctly in a clean, automated test environment.

This step downloads the installer and runs it in an isolated environment as a **standard (non-elevated) user**. The test verifies:

- **Silent installation** — the installer completes without requiring user interaction. Dialogs, license prompts, option screens, or UAC prompts that block progress will cause this step to fail.
- **Correct installer type** — WinGet applies silent switches automatically for known installer types (`nullsoft`, `inno`, `burn`, `wix`, `msi`, `msix`). If the wrong `InstallerType` is declared, the wrong switches may be used, causing the installation to fail or launch interactively.
- **Elevation requirements** — if the installer requires administrator privileges to write to protected locations (e.g., `Program Files`, HKLM registry keys) or install a Windows service, the manifest must declare `ElevationRequirement: elevationRequired`. Without this, the installer will fail in the standard-user test environment.
- **Successful completion** — the installer exits with a success code.
- **Executable discovery** — after installation, the main application executable can be located.
- **Post-install security scan** — Microsoft Defender scans the installed files for malware. A detection at this stage results in a `Validation-Defender-Error`.

> [!TIP]
> Test your manifest locally before submitting:
> ```powershell
> winget settings --enable LocalManifestFiles
> winget install --manifest <path-to-manifest>
> ```
> For a fully isolated test, use the [SandboxTest.ps1 script](tools/SandboxTest.md) in Windows Sandbox.

**Common failure causes:**

- Wrong `InstallerType` — use `nullsoft`, `inno`, `burn`, or `wix` instead of generic `exe` when applicable, so WinGet can pass the correct silent switches.
- Missing or incorrect `InstallerSwitches` for `Silent` or `SilentWithProgress`.
- Installer requires elevation but `ElevationRequirement` is not set.
- A required dependency (runtime, framework, VC++ runtime package) is not present in the test environment.
- The installer is a portable executable that should use `InstallerType: portable` instead of `exe`.
- The installer triggers a UAC prompt that cannot be accepted in the automated environment.

**How to fix:** Verify the `InstallerType` is specific and correct. Add `ElevationRequirement: elevationRequired` if the installer needs elevation. Test locally in a non-elevated terminal to reproduce the environment. Review the accompanying PR comment for specific failure details.

**Labels applied on failure:** `Validation-Unattended-Failed`, `Validation-Installation-Error`, `Validation-Shell-Execute`, `Validation-Executable-Error`, `Validation-Uninstall-Error`, `Validation-Defender-Error`, `Validation-Hash-Verification-Failed`, `Validation-MSIX-Dependency`, `Validation-VCRuntime-Dependency`

---

### 09. Installer Metadata Validation

**What it checks:** Consistency between the manifest metadata and the actual installer binary, plus icon and installation metadata validation required for publishing.

This step examines the installer binary directly and compares its intrinsic metadata with what is declared in the manifest:

- **MSIX-specific validation** — for MSIX and APPX packages, verifies that `PackageFamilyName`, `SignatureSha256`, and `MinimumOSVersion` are correct and consistent with the package manifest embedded in the MSIX.
- **Icon validation** — extracts and validates the application icon from the installer for use in the Windows Package Manager catalog. Icons are displayed in tools such as the WinGet UI and must meet size and format requirements.
- **InstallationMetadata validation** — validates any `InstallationMetadata` fields declared in the manifest against what the installer actually produces, ensuring the published metadata accurately describes the installed application.

> [!NOTE]
> This step may be **skipped** if a previous step (particularly **08. Installation Validation**) failed, because this step relies on successfully running the installer to inspect the resulting installed state.

---

### 10. Validation Completed

**What it checks:** This is not a validation step in itself — it is a **summary check** that reports the overall result of the entire validation pipeline.

When all preceding steps have completed (whether passing, failing, or being skipped due to upstream failures), this check aggregates the results:

- If all applicable steps **passed**, this check reports **success** and the `Validation-Completed` label is applied to the PR. The PR is then eligible for moderator review and potential automatic merge upon approval.
- If one or more steps **failed**, this check reports **failure** and summarizes which steps did not pass. The appropriate error labels are applied.

This check exists to provide a single, clear status signal at the top of the PR's Checks list.

**Labels applied on success:** `Validation-Completed`

---

## After Validation: What Happens Next?

Once **10. Validation Completed** reports success:

1. The `Validation-Completed` label is applied to the PR.
2. A [community moderator](Moderation.md) reviews the PR. Moderators check manifest quality, verify the package installs as expected, and confirm the metadata is accurate.
3. When a moderator approves the PR, the `Moderator-Approved` label is automatically applied.
4. If validation passed and the PR is approved, it is **automatically merged**.
5. After merge, the package passes through the **publishing pipeline**. Once successfully published, you will see a comment and label on the PR. Changes typically appear in the WinGet source within one hour.

---

## Understanding Failure Labels

Each validation step applies specific labels when it fails. For a complete reference of all error labels, their causes, and how to fix them, see the [Validation Failure Guide](ValidationFailureGuide.md).

---

## Related Documentation

- [Authoring Manifests](Authoring.md) — how to create and structure manifest files
- [Validation Failure Guide](ValidationFailureGuide.md) — detailed explanation of every error label
- [First Contribution Checklist](FirstContribution.md) — pre-submit checklist for new contributors
- [Repository Policies](Policies.md) — content, installer, and URL policies
- [Moderation Overview](Moderation.md) — who reviews PRs and how the process works
- [Windows Package Manager Policies](https://learn.microsoft.com/windows/package-manager/package/windows-package-manager-policies) — Microsoft Learn policy reference
