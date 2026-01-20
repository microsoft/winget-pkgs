# Community Repository Policies

Policy documentation at [Microsoft Learn](https://learn.microsoft.com/windows/package-manager/package/windows-package-manager-policies) covers most policies at a high level. Additional nuanced policies are detailed below.

## Moderation
Manifests submitted to the community repository are subject to [moderation](Moderation.md).

## Installer Types
WinGet supports the following installer types:
- **MSIX**
- **MSI**
- **Exe-based installers**

These installer types may also be nested within the `.zip` (compressed) installer type.
**Scripts are expressly disallowed as installers.** Examples include:
- Batch files (`.bat`)
- PowerShell scripts (`.ps1`)

## Installer Behaviors
Packages submitted to the community repository must install without requiring user interaction. The default installation mechanism in WinGet is **"silent with progress"**, which means:
- Installers may display a UI.
- Users must not need to interact with the UI for a successful installation.

## Manifest Agreements
WinGet manifests support adding agreements to manifests. These agreements are between the publisher and the user (or organization) installing the software. These applications are licensed to you by their owner. Microsoft is not responsible for, nor does it grant any licenses to, third-party packages.

When installer switches represent an explicit agreement, the manifest must include:
- Agreement title
- Agreement URL

The agreement body is not allowed. Only verified developers may provide agreement text.

**Manifests with agreements require a review by Microsoft.**

## Manifest Types
WinGet supports a singleton manifest type, but it is prohibited in the community repository because:
- It does not support localization well.
- Existing tooling simplifies the process of generating manifests for WinGet packages.

## Manifest URLs
The URLs in manifests should come from official sources/publishers for packages. In particular any URLs for installers need to be discoverable on the publishers website. In many cases the URLs for installers come from a CDN, and HTTP redirects are used to find the "final" url for installers. Some software is delivered via a "vanity" URL and publishers replace the binaries which will cause a hash mismatch until a new version of the manifest is published. The preference for WinGet manifests is to use unique URLs per version of a package to avoid the hash-mismatch errors.
