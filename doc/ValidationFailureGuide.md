# WinGet Package Validation: Common Failure Labels and How to Fix Them

When you submit a pull request to [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs), automated validation pipelines run a series of checks on your manifest and installers. If something fails, labels are applied to your PR to indicate what went wrong. This document explains each label, what causes it, and how to resolve it.

> [!TIP]
> Many issues can be caught before submitting by running:
> ```powershell
> winget validate <path-to-manifest>
> winget install --manifest <path-to-manifest>
> ```
> For isolated testing, use the [SandboxTest.ps1](https://github.com/microsoft/winget-pkgs/blob/master/doc/tools/SandboxTest.md) script or Windows Sandbox.

---

## Table of Contents

- [Status Labels](#status-labels)
- [Error Labels](#error-labels)
  - [Manifest & Path Errors](#manifest--path-errors)
  - [Installer & Binary Errors](#installer--binary-errors)
  - [URL & Domain Errors](#url--domain-errors)
  - [Installation Testing Errors](#installation-testing-errors)
  - [Dependency Errors](#dependency-errors)
  - [Other Validation Errors](#other-validation-errors)
- [Content Policy Labels](#content-policy-labels)
- [Internal Error Labels](#internal-error-labels)
- [Moderator-Applied Labels](#moderator-applied-labels)
- [Quick Reference Table](#quick-reference-table)

---

## Status Labels

These labels track the progress of your PR through the validation pipeline.

| Label | Meaning |
|---|---|
| **Azure-Pipeline-Passed** | Your manifest passed automated testing and is awaiting moderator approval. |
| **Validation-Completed** | All checks passed. Your PR may be merged automatically after moderator review. |
| **Needs-Author-Feedback** | Something needs your attention. If not addressed within 10 days, the PR will be auto-closed. |
| **Needs-Attention** | The PR has been escalated to the WinGet engineering team for investigation. |
| **Blocking-Issue** | The PR cannot be approved until the blocking issue (indicated by an accompanying error label) is resolved. |
| **Needs-CLA** | You have not signed the [Contributor License Agreement](https://cla.opensource.microsoft.com/microsoft/winget-pkgs). The PR cannot be merged until the CLA is signed. |

---

## Error Labels

### Manifest & Path Errors

#### `Manifest-Validation-Error`

**What it means:** Your manifest has a syntax error or does not conform to the [manifest schema specification](https://github.com/microsoft/winget-pkgs/tree/master/doc/manifest).

**Common causes:**
- Invalid YAML syntax (bad indentation, missing colons, incorrect types)
- Missing required fields (`PackageIdentifier`, `PackageVersion`, `PackageName`, `Publisher`, etc.)
- Using a singleton manifest (deprecated in the community repo — use multi-file manifests)

**How to fix:**
```powershell
winget validate <path-to-manifest>
```
Address all reported errors and resubmit.

---

#### `Manifest-Path-Error`

**What it means:** Your manifest files are not in the correct directory structure.

**Required structure:**
```
manifests/<first-letter>/<Publisher>/<PackageName>/<PackageVersion>/
├── <PackageIdentifier>.installer.yaml
├── <PackageIdentifier>.locale.<language>.yaml
└── <PackageIdentifier>.yaml
```

**Common causes:**
- Incorrect casing — `PackageIdentifier` and directory names are **case-sensitive**
- Filenames don't match the `PackageIdentifier`
- Manifest placed outside the `manifests/` directory

**How to fix:** Ensure the directory path and filenames exactly match your `PackageIdentifier` and `PackageVersion`.

---

#### `PullRequest-Error`

**What it means:** The PR itself has structural problems.

**Common causes:**
- PR contains files outside the `manifests/` folder
- PR contains manifests for **more than one package** or **more than one version**
- Modified files that are not part of the manifest submission

**How to fix:** Each PR must contain exactly one package version. Split your submission into separate PRs if needed.

---

#### `Manifest-Installer-Validation-Error`

**What it means:** There are inconsistencies or missing values in the manifest discovered during MSIX package evaluation or installer metadata validation.

**Common causes:**
- `InstallerType` mismatch between what is declared and what is detected
- Missing or incorrect `PackageFamilyName` for MSIX packages
- Inconsistencies in `AppsAndFeaturesEntries`

**How to fix:** Verify that installer metadata matches the actual installer. For MSIX, ensure `PackageFamilyName` and `SignatureSha256` are correct.

---

### Installer & Binary Errors

#### `Binary-Validation-Error`

**What it means:** The installer failed static analysis during the **Installers Scan** pipeline step. This test runs the installer through multiple antivirus engines.

**Common causes:**
- Installer flagged as malware or [Potentially Unwanted Application (PUA)](https://docs.microsoft.com/windows/security/threat-protection/intelligence/criteria)
- SHA256 hash mismatch between the manifest and the downloaded installer
- Installer URL is inaccessible

**How to fix:**
1. Verify the `InstallerSha256` hash:
   ```powershell
   winget hash <path-to-installer>
   ```
2. If flagged as malware/PUA, [submit the installer to Microsoft Defender for analysis](https://www.microsoft.com/wdsi/filesubmission) as a potential false positive.
3. Ensure the installer URL is publicly accessible.

---

#### `Error-Hash-Mismatch`

**What it means:** The `InstallerSha256` in your manifest does not match the hash of the file downloaded from `InstallerUrl`.

**Common causes:**
- The installer was updated at the URL without updating the hash in the manifest
- "Vanity URL" that always points to the latest version — the file changed after you generated the hash
- Copy/paste error in the hash value

**How to fix:**
```powershell
winget hash <path-to-installer>
```
Update the `InstallerSha256` value in your manifest and resubmit.

> **Best practice:** Use version-specific URLs rather than vanity URLs to avoid hash mismatches.

---

#### `Validation-Hash-Verification-Failed`

**What it means:** Similar to `Error-Hash-Mismatch`, but detected during installation testing. The installer at the URL changed between initial validation and installation testing.

**How to fix:** Same as `Error-Hash-Mismatch` — update the hash and use a stable, version-specific URL.

---

#### `Error-Installer-Availability`

**What it means:** The validation service could not download the installer.

**Common causes:**
- The `InstallerUrl` is incorrect or broken
- The hosting server blocks Azure IP ranges
- The server requires authentication or specific headers

**How to fix:** Verify the URL is correct and publicly accessible. If the URL works from your machine but not in validation, add a comment to your PR — a WinGet engineer will investigate.

---

### URL & Domain Errors

#### `URL-Validation-Error`

**What it means:** A URL in the manifest failed validation. This can be triggered by Microsoft Defender SmartScreen reputation checks or HTTP error responses (403, 404).

**Common causes:**
- Installer URL returns 404 (file not found) or 403 (forbidden)
- URL has a poor SmartScreen reputation
- URL points to a site flagged for malicious content

**How to fix:**
1. Check that all URLs in the manifest are valid and accessible.
2. If the issue is reputation-based, [submit the URL for review](https://www.microsoft.com/wdsi/filesubmission/).
3. Look at the PR check details to identify which specific URL failed.

---

#### `Validation-HTTP-Error`

**What it means:** The `InstallerUrl` does not use HTTPS.

**How to fix:** Update the `InstallerUrl` to use `https://` instead of `http://`.

---

#### `Validation-Domain`

**What it means:** The domain of the `InstallerUrl` does not match the expected domain for this publisher. WinGet policy requires that installers come directly from the publisher's release location.

**Common causes:**
- Using a third-party CDN, mirror, or download aggregator instead of the official publisher URL
- Using a URL shortener or redirector

**How to fix:** Use the official download URL from the publisher's website. If the URL is legitimate, add a comment to your PR for investigation.

---

#### `Validation-Unapproved-URL`

**What it means:** Similar to `Validation-Domain` — the `InstallerUrl` domain is not an approved source for this publisher.

**How to fix:** Use the direct URL from the publisher's official release location.

---

#### `Validation-Indirect-URL`

**What it means:** The installer URL uses a redirect rather than pointing directly to the publisher's server.

**How to fix:** Replace the redirected URL with the direct/final URL from the publisher's server.

---

### Installation Testing Errors

#### `Validation-Unattended-Failed`

**What it means:** The installer did not complete silently — it either timed out or required user interaction.

**Common causes:**
- Missing or incorrect silent install switches (`/S`, `/silent`, `/quiet`, etc.)
- The installer displays a dialog that blocks progress (license agreement, options screen)
- A dependency is missing on the test machine
- The `exe` installer type was specified instead of `portable` for an application that runs without an installer

**How to fix:**
1. Verify your `InstallerSwitches` include the correct `Silent` and `SilentWithProgress` values.
2. Test locally:
   ```powershell
   winget install --manifest <path-to-manifest>
   ```
3. Use Windows Sandbox to confirm the install completes without interaction.

---

#### `Validation-Executable-Error`

**What it means:** After installation, the test could not locate the primary application executable.

**Common causes:**
- The application installs to a non-standard location
- The application is a service or background process without a visible executable
- Installation did not complete successfully

**How to fix:** Ensure the application installs correctly and its main executable is discoverable. If the app is not a traditional desktop application, add a comment to the PR for engineer investigation.

---

#### `Validation-Uninstall-Error`

**What it means:** The application did not clean up completely during uninstall testing.

**How to fix:** Verify that your application uninstalls cleanly. Check the PR comments for specific details about what was left behind.

---

#### `Validation-Installation-Error`

**What it means:** A general error occurred during manual validation of the package.

**How to fix:** Check the accompanying PR comment for specific next steps.

---

#### `Validation-Defender-Error`

**What it means:** During dynamic testing (post-install), Microsoft Defender flagged a problem with the installed application.

**How to fix:**
1. Install the application and run a full Microsoft Defender scan.
2. If you can reproduce the detection, fix the binary or [submit it for false positive analysis](https://docs.microsoft.com/microsoft-365/security/defender-endpoint/defender-endpoint-false-positives-negatives#part-4-submit-a-file-for-analysis).
3. If you cannot reproduce it, add a comment to the PR for investigation.

---

### Dependency Errors

#### `Validation-MSIX-Dependency`

**What it means:** The MSIX package has a dependency that could not be resolved during testing.

**How to fix:** Update the package to include the missing framework components or declare the dependency in the manifest's `Dependencies` section.

---

#### `Validation-VCRuntime-Dependency`

**What it means:** The package depends on a Visual C++ Runtime that was not available during testing.

**How to fix:** Either bundle the VC++ runtime with the installer or add the appropriate dependency to the manifest.

---

### Other Validation Errors

#### `Validation-Merge-Conflict`

**What it means:** Your PR has a merge conflict with the base branch and cannot be validated.

**How to fix:** Resolve the merge conflict in your branch and push the updated commits.

---

#### `Validation-Error`

**What it means:** A general validation failure occurred during manual approval. This is a catch-all label.

**How to fix:** Read the accompanying PR comment for details on what failed and the next steps.

---

#### `Error-Analysis-Timeout`

**What it means:** The binary validation test timed out before completing.

**How to fix:** This is typically investigated by WinGet engineers. No action is usually required from you — the PR will be assigned for investigation.

---

## Content Policy Labels

These labels indicate that something in your manifest metadata triggered a content policy review. Your PR will undergo additional manual review.

| Label | Policy |
|---|---|
| **Policy-Test-2.1** | [General Content Requirements](https://learn.microsoft.com/windows/package-manager/package/windows-package-manager-policies#21-general-content-requirements) |
| **Policy-Test-2.2** | [Content Including Names, Logos, Original and Third Party](https://learn.microsoft.com/windows/package-manager/package/windows-package-manager-policies#22-content-including-names-logos-original-and-third-party) |
| **Policy-Test-2.3** | [Risk of Harm](https://learn.microsoft.com/windows/package-manager/package/windows-package-manager-policies#23-risk-of-harm) |
| **Policy-Test-2.4** | [Defamatory, Libelous, Slanderous and Threatening](https://learn.microsoft.com/windows/package-manager/package/windows-package-manager-policies#24-defamatory-libelous-slanderous-and-threatening) |
| **Policy-Test-2.5** | [Offensive Content](https://learn.microsoft.com/windows/package-manager/package/windows-package-manager-policies#25-offensive-content) |
| **Policy-Test-2.6** | [Alcohol, Tobacco, Weapons and Drugs](https://learn.microsoft.com/windows/package-manager/package/windows-package-manager-policies#26-alcohol-tobacco-weapons-and-drugs) |
| **Policy-Test-2.7** | [Adult Content](https://learn.microsoft.com/windows/package-manager/package/windows-package-manager-policies#27-adult-content) |
| **Policy-Test-2.8** | [Illegal Activity](https://learn.microsoft.com/windows/package-manager/package/windows-package-manager-policies#28-illegal-activity) |
| **Policy-Test-2.9** | [Excessive Profanity and Inappropriate Content](https://learn.microsoft.com/windows/package-manager/package/windows-package-manager-policies#29-excessive-profanity-and-inappropriate-content) |
| **Policy-Test-2.10** | [Country/Region Specific Requirements](https://learn.microsoft.com/windows/package-manager/package/windows-package-manager-policies#210-countryregion-specific-requirements) |
| **Policy-Test-2.11** | [Age Ratings](https://learn.microsoft.com/windows/package-manager/package/windows-package-manager-policies#211-age-ratings) |
| **Policy-Test-2.12** | [User Generated Content](https://learn.microsoft.com/windows/package-manager/package/windows-package-manager-policies#212-user-generated-content) |

---

## Internal Error Labels

These labels indicate a service-side issue. Your PR will be assigned to WinGet engineers automatically. No action is typically required from you.

| Label | Description |
|---|---|
| **Internal-Error** | Generic or unknown failure during testing. |
| **Internal-Error-Domain** | Error during URL domain validation. |
| **Internal-Error-Dynamic-Scan** | Error during post-install binary validation. |
| **Internal-Error-Keyword-Policy** | Error during manifest content policy validation. |
| **Internal-Error-Manifest** | Error during manifest processing. |
| **Internal-Error-NoArchitectures** | Could not determine the installer architecture. |
| **Internal-Error-NoSupportedArchitectures** | The current test architecture is not supported. |
| **Internal-Error-PR** | Error during PR processing. |
| **Internal-Error-Static-Scan** | Error during static analysis of installers. |
| **Internal-Error-URL** | Error during URL reputation validation. |

---

## Moderator-Applied Labels

These labels are applied by [moderators](https://github.com/microsoft/winget-pkgs/blob/master/doc/Moderation.md) during manual review and indicate issues that need author attention.

| Label | Meaning |
|---|---|
| **Error-Hash-Mismatch** | Installer hash doesn't match — same as the automated label. |
| **Error-Installer-Availability** | Installer URL cannot be reached. |
| **Interactive-Only-Installer** | The installer requires user interaction and cannot run silently. This is a **blocking issue**. |
| **License-Blocks-Install** | A license agreement blocks silent installation. This is a **blocking issue**. |
| **Manifest-Content-Incomplete** | Manifest metadata is missing or insufficient. |
| **Manifest-Singleton-Deprecated** | Singleton manifests are no longer accepted — convert to multi-file format. |
| **Version-Parameter-Mismatch** | The version in the manifest doesn't match what the installer writes to the registry. |
| **Portable-Archive** | The installer is a portable archive that may need special handling. This is a **blocking issue**. |
| **Scripted-Application** | The package uses scripts (`.bat`, `.ps1`) as installers, which are **not allowed**. |
| **Hardware** | The package requires specific hardware. This is a **blocking issue**. |

---

## Quick Reference Table

| Label | Category | Author Action Required? | Summary |
|---|---|---|---|
| `Manifest-Validation-Error` | Manifest | ✅ Yes | Fix YAML syntax / schema errors |
| `Manifest-Path-Error` | Manifest | ✅ Yes | Fix directory structure / file naming |
| `PullRequest-Error` | PR | ✅ Yes | One package, one version per PR |
| `Manifest-Installer-Validation-Error` | Manifest | ✅ Yes | Fix installer metadata inconsistencies |
| `Binary-Validation-Error` | Installer | ✅ Yes | Fix AV detection or hash/URL issues |
| `Error-Hash-Mismatch` | Installer | ✅ Yes | Update `InstallerSha256` |
| `Error-Installer-Availability` | Installer | ✅ Yes | Fix installer URL |
| `URL-Validation-Error` | URL | ✅ Yes | Fix broken or untrusted URLs |
| `Validation-HTTP-Error` | URL | ✅ Yes | Switch to HTTPS |
| `Validation-Domain` | URL | ⚠️ Maybe | Use publisher's official URL |
| `Validation-Unapproved-URL` | URL | ⚠️ Maybe | Use approved publisher URL |
| `Validation-Indirect-URL` | URL | ✅ Yes | Remove URL redirection |
| `Validation-Unattended-Failed` | Install | ✅ Yes | Fix silent install switches |
| `Validation-Executable-Error` | Install | ⚠️ Maybe | Verify executable is discoverable |
| `Validation-Defender-Error` | Install | ⚠️ Maybe | Fix or submit for false positive review |
| `Validation-Merge-Conflict` | PR | ✅ Yes | Resolve merge conflict |
| `Validation-MSIX-Dependency` | Dependency | ✅ Yes | Add missing framework dependency |
| `Validation-VCRuntime-Dependency` | Dependency | ✅ Yes | Add VC++ runtime dependency |
| `Needs-CLA` | PR | ✅ Yes | Sign the Contributor License Agreement |
| `Internal-Error-*` | Internal | ❌ No | WinGet team will investigate |
| `Policy-Test-*` | Content | ⚠️ Maybe | Additional manual review required |

---

## Getting Help

- **Re-run validation:** A moderator can comment `@wingetbot run` on your PR to re-trigger the validation pipeline.
- **Ask a moderator:** Check [recently closed PRs](https://github.com/microsoft/winget-pkgs/pulls?q=is%3Apr+is%3Aclosed+label%3AModerator-Approved) to find an active moderator and `@mention` them.
- **File an issue:** If you believe the failure is incorrect, [open an issue](https://github.com/microsoft/winget-pkgs/issues/new).
- **Matrix chat:** Join the [WinGet-pkgs Matrix room](https://gitter.im/Microsoft/winget-pkgs) for quick questions.

---

*For more information, see the [official validation documentation](https://docs.microsoft.com/windows/package-manager/package/winget-validation) and the [Troubleshooting guide](https://github.com/microsoft/winget-pkgs/blob/master/doc/Troubleshoot.md).*
