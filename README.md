# Windows Package Manager Community Repository

[![Gitter](https://img.shields.io/gitter/room/Microsoft/winget-pkgs)](https://gitter.im/Microsoft/winget-pkgs)
[![Validation Pipeline Badge](https://img.shields.io/endpoint?url=https://winget-pme.azurefd.net/api/GetServiceComponentStatusBadge?component=ValidationPipeline 'Validation Pipeline Badge')](https://dev.azure.com/shine-oss/winget-pkgs/_build?definitionId=14)
[![Publish Pipeline Badge](https://img.shields.io/endpoint?url=https://winget-pme.azurefd.net/api/GetServiceComponentStatusBadge?component=PublishPipeline 'Publish Pipeline Badge')](https://dev.azure.com/shine-oss/winget-pkgs/_build?definitionId=12)
[![GitHub Status](https://img.shields.io/endpoint?url=https://api.bittu.eu.org/github-status-badge-endpoint)](https://www.githubstatus.com)

This repository contains the manifest files for the **Windows Package Manager** default source. You are highly encouraged to submit manifests for your favorite application.

> [!IMPORTANT]
> At this time installers must be MSIX, MSI, APPX, or .exe application installers. Script-based installers and fonts are not currently supported.

The **Windows Package Manager** is an [open source client](https://github.com/microsoft/winget-cli) designed for command-line usage. If you are interested in exploring private repositories offering private WinGet package hosting, see [private repositories](doc/private/README.md).

# Documentation

Please check the [overview](doc/README.md) for detailed topics. Common topics for the WinGet Community repository are available below:
* [Authoring a manifest](doc/README.md#authoring-a-manifest)
* [Testing a manifest](doc/README.md#testing-a-manifest)
* [Submitting a manifest](doc/README.md#submitting-a-manifest)
* [Requesting a new package](doc/Issues.md#Request-a-New-Package)
* [Requesting a new package version](doc/Issues.md#Request-a-New-Package-Version)

# Contributing

This project welcomes contributions and suggestions. Most contributions require you to agree to a Contributor License Agreement (CLA) declaring that you have the right to, and do, grant us the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide a CLA and decorate the PR appropriately (e.g., status check, comment). Follow the instructions provided by the bot. You will only need to do this once across all Microsoft repositories using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
See the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments. More information is available in our [Contributing document](CONTRIBUTING.md).

To avoid doubt, you may not make any Submissions linking to third-party materials if such Submission is prohibited by the applicable third party and/or otherwise violates such third party's rights.
