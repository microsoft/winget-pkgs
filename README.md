# Windows Package Manager Community Repository

[![Gitter](https://img.shields.io/gitter/room/Microsoft/winget-pkgs)](https://gitter.im/Microsoft/winget-pkgs)
[![Validation Pipeline Badge](https://img.shields.io/endpoint?url=https://winget-pme.azurefd.net/api/GetServiceComponentStatusBadge?component=ValidationPipeline 'Validation Pipeline Badge')](https://dev.azure.com/ms/winget-pkgs/_build?definitionId=337)
[![Publish Pipeline Badge](https://img.shields.io/endpoint?url=https://winget-pme.azurefd.net/api/GetServiceComponentStatusBadge?component=PublishPipeline 'Publish Pipeline Badge')](https://dev.azure.com/ms/winget-pkgs/_build?definitionId=338)
[![GitHub Status](https://img.shields.io/endpoint?url=https://api.bittu.eu.org/github-status-badge-endpoint)](https://www.githubstatus.com)

This repository contains the manifest files for the **Windows Package Manager** default source. You are highly encouraged to submit manifests for your favorite application.

> [!IMPORTANT]
> At this time installers must be MSIX, MSI, APPX, or .exe application installers. Script-based installers and fonts are not currently supported.

The **Windows Package Manager** is an [open source client](https://github.com/microsoft/winget-cli) designed for command-line usage. If you are interested in exploring third-party repositories offering private winget package hosting, see [third-party repositories](THIRD_PARTY.md).

# Submitting a Package

To submit a package to this repository, you should follow these steps:

1. Follow the [Contributing](#contributing) guidelines below.
2. [Author](AUTHORING_MANIFESTS.md) a Manifest.
3. [Test](#test-your-manifest) your manifest.
4. [Submit](#submit-your-pr) your pull request (PR).
5. Respond to any feedback in your PR.

> Note: Please check the package's manifest you intend to submit does not already exist in the repository, and there are no open PRs for it in order to avoid duplicates.

## Authoring a Manifest

A few different tools are available to help you author a manifest.

- [Windows Package Manager Manifest Creator](https://github.com/microsoft/winget-create)
- [YamlCreate.ps1](doc/tools/YamlCreate.md)
- Other WinGet Manifest Creators developed by the community:
  - [Komac - Kotlin Manifest Creator for WinGet](https://github.com/russellbanks/Komac) (maintained by [**@russellbanks**](https://github.com/russellbanks))

> Note: Only one manifest may be submitted per PR.

## Test your manifest

Now that you have authored your manifest, you should make sure it works as expected.

> Note: You will need to run `winget settings --enable LocalManifestFiles` in an administrative shell before working with local manifests.

### Locally

1. Verify the syntax by executing the following command:

```
winget validate <path-to-manifest>
```

2. Test the install by executing the following command:

```
winget install -m <path-to-manifest>
```

For more details, see ["Submit packages to Windows Package Manager"](https://docs.microsoft.com/windows/package-manager/package) at Microsoft Docs.

### In Windows Sandbox

You can use the [Sandbox Test](Tools/SandboxTest.ps1) PowerShell script for testing a manifest installation in [Windows Sandbox](https://docs.microsoft.com/windows/security/threat-protection/windows-sandbox/windows-sandbox-overview). The manifest will be also validated.

Just provide the path to manifest as parameter:

```
.\Tools\SandboxTest.ps1 <path-to-manifest>
```

## Submit your PR

Once you have verified your manifest, it's time to submit a PR. Place your manifest in a folder path that matches the following structure:

```
manifests\<first lower case letter of publisher>\<publisher>\<package>\<version>\
```

### Validation Process

Your PR will go through a validation process. The core team or the Microsoft bot (BOT) will use  [labels](https://docs.microsoft.com/windows/package-manager/package/winget-validation#pull-request-labels)  to assist during the process. In case of a failure, the BOT will suggest the problem with the submission and assign the PR back to you.

### Respond to PR feedback

If your PR has been assigned to you, a timer will be triggered. You will have 7 days to resolve the issue, or the BOT will automatically close the PR.

Submissions to the repository are reviewed by Windows Package Manager administrators and/or community moderators. To help identify these individuals, we have provided a  [Public Service Announcement](https://github.com/microsoft/winget-pkgs/issues/15674).

# Contributing

This project welcomes contributions and suggestions. Most contributions require you to agree to a Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide a CLA and decorate the PR appropriately (e.g., status check, comment). Follow the instructions provided by the bot. You will only need to do this once across all Microsoft repositories using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
See the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments. More information is available in our [Contributing document](CONTRIBUTING.md).

To avoid doubt, you may not make any Submissions linking to third party materials if such Submission is prohibited by the applicable third party and/or otherwise violates such third party's rights.
