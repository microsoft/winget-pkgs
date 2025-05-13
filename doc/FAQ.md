# Frequently Asked Questions
## Table of Contents
  1. [**What is an ARP Entry?**](#what-is-an-arp-entry)
  2. [**What is the difference between a Marketing Version and Package Version?**](#what-is-the-difference-between-a-marketing-version-and-package-version)
  3. [**How do I submit a package?**](#how-do-i-submit-a-package)
  4. [**How do I get the AppsAndFeaturesEntries for an installer?**](#how-do-i-get-the-appsandfeaturesentries-for-an-installer)
  5. [**What should I do if a package is being published by a new publisher?**](#what-should-i-do-if-a-package-is-being-published-by-a-new-publisher)
  6. [**How long do packages take to be published?**](#how-long-do-packages-take-to-be-published)
  7. [**What does this label on my PR mean?**](#what-does-this-label-on-my-pr-mean)
  8. [**Why does a package have the version "Unknown"?**](#why-does-a-package-have-the-version-unknown)
  9. [**My applications keep upgrading even when up to date!**](#my-applications-keep-upgrading-even-when-up-to-date)
  10. [**How can I use PowerShell to parse the output from winget?**](#how-can-i-use-powershell-to-parse-the-output-from-winget)
  11. [**Why do WinGet and AppInstaller have different versions?**](#why-do-winget-and-appinstaller-have-different-versions)
  12. [**How do I know the packages in the Community Repository are safe?**](#how-do-i-know-the-packages-in-the-community-repository-are-safe)
  13. [**How do portable applications get “Installed”?**](#how-do-portable-applications-get-installed)
-----
## **What is an ARP Entry?**
ARP stands for `A`dd and `R`emove `P`rograms. In Windows, installer files put information about the package they have installed into the Windows Registry. This information is used to tell Windows exactly what a program is and how to uninstall or modify it. Users can view these entries through the Add and Remove Programs option in Control Panel, or by running `appwiz.cpl`. Alternatively, the `Apps & features` menu in Windows Settings can be used to view the entries. Each entry in the table is an ARP Entry, and the Windows Package Manager uses these entries to help determine which applications are currently installed on your system.
## **What is the difference between a Marketing Version and Package Version?**
Sometimes publishers use two different versions to refer to software. The version most commonly seen on the website or download page for a package is the Marketing Version. This is generally is used for the `PackageVersion` field of manifests, but there are exceptions. The Package Version, sometimes referred to as `Build Version`,`Actual Version`, or `DisplayVersion` is the version which is written to the ARP entry. This value is what the Windows Package Manager uses to determine which version of an application is currently installed on your system, and should be mapped to the `AppsAndFeaturesEntries >> DisplayVersion` in a manifest.
## **How do I submit a package?**
Getting started is the hard part. There are several tools which we recommend for both creating and submitting packages.

First is the [Windows Package Manager Manifest Creator (a.k.a Winget-Create)](https://github.com/microsoft/winget-create). Winget-Create is a command line tool that will prompt you for relevant metadata related to your package. Once you are done, Winget-Create will validate your manifest to verify that it is correct and allow you to submit your newly-created manifest directly to the winget-pkgs repository by linking your GitHub account.

Second is the [YamlCreate PowerShell Script](../Tools/YamlCreate.ps1). This tool is great for those who are technically inclined and understand the basics of forking, cloning, and commits. YamlCreate iterates much faster than Winget-Create but has largely the same functionality. More information on YamlCreate can be found in the [Script Documentation](tools/YamlCreate.md).

Need more information? Take a look at the document on [Authoring Manifests](Authoring.md) and the [Microsoft Documentation Site](https://docs.microsoft.com/windows/package-manager/package/manifest).
## **How do I get the AppsAndFeaturesEntries for an installer?**
The best way to get the AppsAndFeaturesEntries, or the ARP Entries, for an installer is to run the installer inside of the [Windows Sandbox](https://docs.microsoft.com/windows/security/threat-protection/windows-sandbox/windows-sandbox-overview). Instructions on how to enable the sandbox can be found at the link above, or in the [SandboxTest PowerShell Script Documentation](tools/SandboxTest.md). The [SandboxTest PowerShell Script](../Tools/SandboxTest.ps1) is a great way to get the AppsAndFeaturesEntries for a manifest you have already created. The SandboxTest Script will validate and test the manifest by downloading and installing the package in the Sandbox and comparing the ARP Entries before and after the installation. For the technically savvy, @jedieaston has created an [Add-ARPEntries Script](https://github.com/jedieaston/Add-ARPEntries) which uses Docker to populate the AppsAndFeaturesEntries for an existing manifest. Please note, however, that only the ARP Entry for the *Primary Component* should be added when a package installs multiple components.
## **What should I do if a package is being published by a new publisher?**
The best practice for this is to create a situation where the package automatically switches to the new publisher using the ARP Entries for the package. To do this, two copies of the package must be added to the repository - one under the original package identifier and one under a new package identifier for the new publisher. This will cause anyone on a package published by the old publisher to be updated to the new version, at which point the ARP Entries will cause the Windows Package Manager to match the package to the new publisher and all future updates will be taken from the new package identifier.

For the package version added under the old publisher, the metadata should be updated to be accurate to the new publisher, with the exception of the `Publisher` field, which should remain as the old publisher. Additionally, the `AppsAndFeaturesEntries` should be added for each installer node, being sure to keep the `Publisher` entry as the old publisher. The `ProductCode` entries should not be specified under this version.

For the package version added under the new package identifier, the metadata should be complete and accurate. Additionally, the `AppsAndFeaturesEntries` should be added for each installer node. The `ProductCode` entries should be specified under this version.

*Additional Notes*:
While this is currently the best practice, this may change in the future with the implementation of [microsoft/winget-cli#1899](https://github.com/microsoft/winget-cli/issues/1899) and [microsoft/winget-cli#1900](https://github.com/microsoft/winget-cli/issues/1900). The origination of this best practice can be found [here](https://github.com/microsoft/winget-pkgs/issues/66937#issuecomment-1190154419)
## **How long do packages take to be published?**
The time it takes for a package to be published depends on several factors:

1. **Pull Request Approval**: When you submit a package to the repository, your pull request undergoes automated validation checks. Labels will be applied to indicate the results of these checks.

2. **Community Moderator Review**: All pull requests must be reviewed and approved by one of our [community moderators](Moderation.md).

3. **Publishing Pipeline**: After approval and merging, the pull request passes through the publishing pipeline. Once successful, you will see a comment and label indicating the status.

Typically, changes are published within one hour after the pull request is merged. If you don't see the changes published, check the [WinGetSvc-Publish Pipeline](https://dev.azure.com/shine-oss/winget-pkgs/_build?definitionId=12) for errors. If there are issues, verify if any [existing issues](https://github.com/microsoft/winget-pkgs/issues) have been reported. If not, create a [new issue](https://github.com/microsoft/winget-pkgs/issues/new).
## **What does this label on my PR mean?**
During the automated validation process, labels are added to pull requests to help the bots that manage the repository and the status of open requests. All of these labels are described in more detail on the [Microsoft Documentation Site](https://docs.microsoft.com/windows/package-manager/package/winget-validation#pull-request-labels)
## **Why does a package have the version "Unknown"?**
A package version is marked as "Unknown" when the Windows Package Manager detects the package as installed but the publisher has not provided the version information in the `DisplayVersion` registry key.

### Behavior in Different Versions:
- **Windows Package Manager v1.2**: Packages with an unknown version are always re-installed when running `winget upgrade`.
- **Windows Package Manager v1.3 and later**: These packages are excluded from upgrades by default but can be included using the `--include-unknown` switch.

### Recommendation:
Contact the application's publisher and request them to set the `DisplayVersion` registry key in their installer if you frequently use a package with an unknown version.

## **My applications keep upgrading even when up to date!**
Applications may continually upgrade due to the following reasons:

1. **Unknown Version**: Packages with an unknown version may trigger upgrades. This issue was resolved in Windows Package Manager v1.3.
2. **Side-by-Side Installations**: Multiple versions of the same application (e.g., Visual C++ Redistributables, .NET Desktop Runtimes) can coexist. The Windows Package Manager may attempt to upgrade older versions, causing a loop if the upgrades also install side-by-side.

### Future Work:
Efforts to resolve these issues are being tracked in:
- [microsoft/winget-cli#2345](https://github.com/microsoft/winget-cli/issues/2345)
- [microsoft/winget-cli#1413](https://github.com/microsoft/winget-cli/issues/1413)
## **How can I use PowerShell to parse the output from winget?**
The Windows Package Manager is still in development and does not yet support emitting rich data objects as output. There are a few issues tracking this feature request. Please add your thumbs up to these issues as the reactions are used to help prioritize which features are implemented next.
* [Add Native PowerShell Support - microsoft/winget-cli#221](https://github.com/microsoft/winget-cli/issues/221)
* [Add list option to format output as JSON - microsoft/winget-cli#2032](https://github.com/microsoft/winget-cli/issues/2032)

Also, take a look at the [discussions](https://github.com/microsoft/winget-cli/discussions/categories/powershell) based around PowerShell support!
## Why do WinGet and AppInstaller have different versions?

WinGet and AppInstaller are two distinct pieces of software, even though WinGet is included as part of the AppInstaller package. Their versioning differs because:

1. **Separate Software**: Changes to WinGet, such as a major version increment, may not necessarily impact AppInstaller or require a version change for it.
2. **Independent Updates**: Each application can evolve independently, with updates and features specific to their respective functionalities.

This separation ensures that updates to one do not unintentionally disrupt the other.
## How do I know the packages in the Community Repository are safe?
While not all the details can be made public, the general approach is a defense in depth.

All new manifests are first scanned to be sure the manifest has the correct syntax. Assuming the author created the manifest correctly, each installer is then checked. Installers are downloaded to a secured environment and scanned with multiple utilities to check for any form of malware; after this the installer is executed and the installation is validated. This validation includes checking that no system files were changed, no suspicious services were added, and a multitude of other checks are performed to ensure the program is exactly what it appears to be. The application is also run after installation to be sure that no suspicious processes are kicked off.

The last automated check is a content validation to ensure that the package description and other metadata fields don’t violate one of the policies in place such as those against excessively profane language or adult content. There are additional manual checks in place, as each submission requires moderator approval before it can be merged. This gives an extra opportunity for moderators to check for the installation of any potentially unwanted applications, applications which change settings unexpectedly, and to ensure the installation truly works as expected.
## How do portable applications get “Installed”?

WinGet performs several steps to "install" portable applications, mimicking the behavior of traditional installers:

1. **Download and Move Files**: The application files are downloaded and moved into an installation directory.
2. **Registry Entries**: Registry entries are created to make the application appear as an installed program.
3. **PATH Environment Variable**: The application is added to the PATH environment variable, enabling CLI applications to work seamlessly.

### PATH Behavior:
- **Developer Mode Enabled or Administrative Context**: A links directory is created and added to the PATH.
- **Otherwise**: The full path to the installation folder is added to the PATH.

These steps ensure that portable applications integrate smoothly into the system.
