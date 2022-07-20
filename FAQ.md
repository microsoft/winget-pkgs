# Frequently Asked Questions
## Table of Contents
  1. [**What is an ARP Entry?**](#what-is-an-arp-entry)
  2. [**What is the difference between a Marketing Version and Package Version?**](#what-is-the-difference-between-a-marketing-version-and-package-version)
  3. [**How do I submit a package?**](#how-do-i-submit-a-package)
  4. [**What should I do if a package is being published by a new publisher?**](#what-should-i-do-if-a-package-is-being-published-by-a-new-publisher)
  5. [**How long do packages take to be published?**](#how-long-do-packages-take-to-be-published)
-----
## **What is an ARP Entry?**
ARP stands for `A`dd and `R`emove `P`rograms. In Windows, installer files put information about the package they have installed into the Windows Registry. This information is used to tell Windows exactly what a program is and how to uninstall or modify it. Users can view these entries through the Add and Remove Programs option in Control Panel, or by running `appwiz.cpl`. Alternatively, the `Apps & features` menu in Windows Settings can be used to view the entries. Each entry in the table is an ARP Entry, and the Windows Package Manager uses these entries to help determine which applications are currently installed on your system.
## **What is the difference between a Marketing Version and Package Version?**
Sometimes publishers use two different versions to refer to software. The version most commonly seen on the website or download page for a package is the Marketing Version. This is generally is used for the `PackageVersion` field of manifests, but there are exceptions. The Package Version, sometimes referred to as `Build Version`,`Actual Version`, or `DisplayVersion` is the version which is written to the ARP entry. This value is what the Windows Package Manager uses to determine which version of an application is currently installed on your system, and should be mapped to the `AppsAndFeaturesEntries >> DisplayVersion` in a manifest.
## **How do I submit a package?**
Getting started is the hard part. There are several tools which we recommend for both creating and submitting packages. 

First is the [Windows Package Manager Manifest Creator (a.k.a Winget-Create)](https://github.com/microsoft/winget-create). Winget-Create is a command line tool that will prompt you for relevant metadata related to your package. Once you are done, Winget-Create will validate your manifest to verify that it is correct and allow you to submit your newly-created manifest directly to the winget-pkgs repository by linking your GitHub account.

Second is the [YamlCreate PowerShell Script](Tools/YamlCreate.ps1). This tool is great for those who are technically inclined and understand the basics of forking, cloning, and commits. YamlCreate iterates much faster than Winget-Create but has largely the same functionality. More information on YamlCreate can be found in the [Script Documentation](doc/tools/YamlCreate.md).

Need more information? Take a look at the document on [Authoring Manifests](AUTHORING_MANIFESTS.md).
## **What should I do if a package is being published by a new publisher?**
The best practice for this is to create a situation where the package automatically switches to the new publisher using the ARP Entries for the package. To do this, two copies of the package must be added to the repository - one under the original package identifier and one under a new package identifier for the new publisher. This will cause anyone on a package published by the old publisher to be updated to the new version, at which point the ARP Entries will cause the Windows Package Manager to match the package to the new publisher and all future updates will be taken from the new package identifier.

For the package version added under the old publisher, the metadata should be updated to be accurate to the new publisher, with the exception of the `Publisher` field, which should remain as the old publisher. Additionally, the `AppsAndFeaturesEntries` should be added for each installer node, being sure to keep the `Publisher` entry as the old publisher. The `ProductCode` entries should not be specified under this version.

For the package version added under the new package identifier, the metadata should be complete and accurate. Additionally, the `AppsAndFeaturesEntries` should be added for each installer node. The `ProductCode` entries should be specified under this version.

*Additional Notes*:
While this is currently the best practice, this may change in the future with the implementation of [microsoft/winget-cl#1899](https://github.com/microsoft/winget-cli/issues/1899) and [microsoft/winget-cl#1900](https://github.com/microsoft/winget-cli/issues/1900). The origination of this best practice can be foud [here](https://github.com/microsoft/winget-pkgs/issues/66937#issuecomment-1190154419)
## **How long do packages take to be published?**
The answer to this question depends on multiple factors. First, the pull request approval. When submitting a package to the repository, your pull request will go through a series of automated checks in the validation pipeline. You will see labels applied to your pull request based on the results of the validation. Secondly, all pull requests must be reviewed and approved by one of our [community moderators](). Finally, the pull request must be merged and pass through the publishing pipeline. Once the publishing pipeline has succeeded for your pull request, you will see a comment and a label indicating this status.

After your PR is approved and merged, the changes are *generally* published within one hour. If you are not seeing the changes published after your pull request has been merged, check the [WinGetSvc-Publish Pipeline](https://dev.azure.com/ms/winget-pkgs/_build?definitionId=338) for errors. If the pipeline is erroring, please check to see if any [issues](https://github.com/microsoft/winget-pkgs/issues) have been opened regarding the failures and create a [new issue](https://github.com/microsoft/winget-pkgs/issues/new) if there isn't one already.