# Documentation Overview

## Authoring a Manifest

A few different tools are available to help you author a manifest.

- [Windows Package Manager Manifest Creator](https://github.com/microsoft/winget-create)
- [YamlCreate.ps1](tools/YamlCreate.md)
- Other WinGet Manifest Creators developed by the community:
  - [Komac - Community Manifest Creator](https://github.com/russellbanks/Komac) (maintained by [**@russellbanks**](https://github.com/russellbanks))

> [!Note]
> Only one manifest may be submitted per PR.

## Testing a Manifest

Now that you have authored your manifest, you should make sure it works as expected.

> [!Note]
> You will need to run `winget settings --enable LocalManifestFiles` in an administrative shell before working with local manifests.

### Locally

1. Verify the syntax by executing the following command:

```
winget validate --manifest <path-to-manifest>
```

2. Test the install by executing the following command:

```
winget install --manifest <path-to-manifest>
```

For more details, see ["Submit packages to Windows Package Manager"](https://docs.microsoft.com/windows/package-manager/package) at Microsoft Docs.

### In Windows Sandbox


You can use the [Sandbox Test](../Tools/SandboxTest.ps1) PowerShell script for testing a manifest installation in [Windows Sandbox](https://docs.microsoft.com/windows/security/threat-protection/windows-sandbox/windows-sandbox-overview). The manifest will be also validated.

Just provide the path to manifest as parameter:

```
.\Tools\SandboxTest.ps1 <path-to-manifest>
```

## Submitting a Manifest

To submit a package to this repository, you should follow these steps:

1. Follow the [Contributing](../CONTRIBUTING.md) guidelines.
2. [Author](Authoring.md) a Manifest.
3. [Test](#testing-a-manifest) your manifest.
4. [Submit](#submit-your-pr) your pull request (PR).
5. Respond to any feedback in your PR.

> [!Note]
> Please check the package's manifest you intend to submit does not already exist in the repository, and there are no open PRs for it in order to avoid duplicates.

## Submit your PR

Once you have verified your manifest, it's time to submit a PR. Place your manifest in a folder path that matches the following structure:

```
manifests\<first lower case letter of publisher>\<publisher>\<package>\<version>\
```
### Validation Process

Your PR will go through a validation process. The core team or the Microsoft bot (BOT) will use  [labels](https://docs.microsoft.com/windows/package-manager/package/winget-validation#pull-request-labels)  to assist during the process. In case of a failure, the BOT will suggest the problem with the submission and assign the PR back to you.

#### Community Repository Policies

The WinGet community repository has a set of policies restricting the use of certain manifest fields in PRs. These policies primarily affect optional metadata fields restricted to verified developers. Some fields are automatically populated during our validation process like the fields for icons.
>[!Note]
>The verified developer workflow is still in progress.

### Respond to PR feedback

If your PR has been assigned to you, a timer will be triggered. You will have 7 days to resolve the issue, or the BOT will automatically close the PR.

Submissions to the repository are reviewed by Windows Package Manager administrators and/or community moderators. To help identify these individuals, we have provided a  [Public Service Announcement](https://github.com/microsoft/winget-pkgs/issues/15674).
