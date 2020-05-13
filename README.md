# Welcome to the Windows Package Manager Community repo
This repository contains the manifest files for the **Windows Package Manager**.  You are highly encouraged to submit manifests for your favorite tool.

The **Windows Package Manager** is and open source client.  You will find the source code [here](https://github.com/microsoft/winget-cli).

# Submitting a Package
To submit a package to the repository, you should follow these steps:
1) Follow the **Contribuing** guidelines below
2) Author a Manifest
3) Submit your PR
4) Respond to any feedback

## Authoring a Manifest

The minimal manifest syntax is below.

Current limitations are:
* One manifest per PR
* One installer per PR

Be sure the manifest filename matches the `Version` and the manifest is located in the folder path matching `manifests\<publisher>\<package>\<version>.yaml`

```yaml
Id: string # publisher.package format
Publisher: string # the name of the publisher
Name: string # the name of the application
Version: string # version numbering format
License: string # the open source license or copyright
InstallerType: string # enumeration of supported installer types (exe, msi, msix)
Installers:
  - Arch: string # enumeration of supported architectures
    URL: string # path to download installation file
    Sha256: string # SHA256 calculated from installer
# ManifestVersion: 0.1.0
```

## Author a Manifest
## Submit your PR
## Respond to PR feedback

# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

For the avoidance of doubt, you may not make any Submissions linking to third party materials if such 
Submission is prohibited by the applicable third party and/or otherwise violates such third party's rights.

