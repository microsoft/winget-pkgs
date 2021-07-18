# Windows Package Manager Community Repository
This repository contains the manifest files for the **Windows Package Manager** default source.  You are highly encouraged to submit manifests for your favorite application.
>Note: At this time installers must either be MSIX, MSI or .exe application installers. Standalone or portable executables, compressed .zip files, and fonts are not currently supported.

The **Windows Package Manager** is an [open source client](https://github.com/microsoft/winget-cli) designed for command-line usage.

# Submitting a Package
To submit a package to this repository, you should follow these steps:
1) Follow the [Contributing](#Contributing) guidelines below.
2) [Author](AUTHORING_MANIFESTS.md) a Manifest.
3) [Test](#test-your-manifest) your manifest.
4) [Submit](#submit-your-pr) your pull request (PR).
5) Respond to any feedback in your PR.

>Note: Please check the package's manifest you intend to submit does not already exist in the repository, and there are no open PRs for it in order to avoid duplicates.

## Authoring a Manifest

You may either use the [Windows Package Manager Manifest Creator](https://github.com/microsoft/winget-create), the [YAMLCreate](#using-the-yamlcreateps1) PowerShell script, or you can craft a manifest manually following our [authoring guidelines](AUTHORING_MANIFESTS.md).

>Note: Only one manifest may be submitted per PR.

### Using the YAMLCreate.ps1
To help author manifest files, we have provided a YAMLCreate.ps1 [powershell script](Tools/YamlCreate.ps1) located in the Tools folder. The script will prompt you for the URL to the installer, then will prompt you to fill in metadata.

>Note: We recommend running the script in the location where you want to produce the manifest file.  For example: `manifests\<p>\<publisher>\<package>\`.  After successful completion, it will produce the YAML files.

## Test your manifest
Now that you have authored your manifest, you should make sure it works as expected.

### Locally
1) Verify the syntax by executing the following command:
```
winget validate <path-to-manifest>
```

2) Test the install by executing the following command:
```
winget install -m <path-to-manifest>
```

For more details, see ["Submit packages to Windows Package Manager"](https://docs.microsoft.com/windows/package-manager/package) at Microsoft Docs.

### In Windows Sandbox
You can use the [Sandbox Test](Tools/SandboxTest.ps1) PowerShell script for testing a manifest installation in [Windows Sandbox](https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-sandbox/windows-sandbox-overview). The manifest will be also validated.

Just provide the path to manifest as parameter:
```
.\Tools\SandboxTest.ps1 <path-to-manifest>
```

## Submit your PR
With the manifest verified, you will need to submit a PR.  Your manifest should be located in the folder path matching `manifests\<first lower case letter of publisher>\<publisher>\<package>\<version>.yaml`

### Validation Process
The PR request will go through a validation process. During the process, the core team or the Microsoft bot (BOT) will use [labels](https://docs.microsoft.com/windows/package-manager/package/winget-validation#pull-request-labels) to help. In the event of a failure, the BOT will suggest where the problem is with the submission and assign the PR back to you.  

### Respond to PR feedback
If the PR has been assigned to you, a timer is triggered.  You will have 7 days to resolve the issue, or the PR will be closed automatically by the BOT.  

Submissions to the repository are reviewed by Windows Package Manager administrators and/or community moderators. We've provided a [Public Service Announcement](https://github.com/microsoft/winget-pkgs/issues/15674) to help identify these individuals. 

# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all Microsoft repositories using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments. More information is available in our [Contributing document](CONTRIBUTING.md).

For the avoidance of doubt, you may not make any Submissions linking to third party materials if such Submission is prohibited by the applicable third party and/or otherwise violates such third party's rights.
