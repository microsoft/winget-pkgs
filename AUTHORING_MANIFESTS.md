[Manifest Specification]:   doc/manifest/schema/1.6.0
[versionSchema]:            doc/manifest/schema/1.6.0/version.md
[defaultLocaleSchema]:      doc/manifest/schema/1.6.0/defaultLocale.md
[installerSchema]:          doc/manifest/schema/1.6.0/installer.md

# Authoring Manifests

First, we want to say thank you. Your contribution is highly valued. And we appreciate the time you have taken to get here and read this document. Let's start out with a few definitions to help you understand our vocabulary.

## Definitions

### What is a manifest?

Manifests are the YAML files in this repository containing the metadata used by the Windows Package Manager to install and upgrade software on Windows 10. There are thousands of these files partitioned under the [manifests](/manifests) directory. We've had to partition the directory structure so you don't have to scroll as much in the GitHub.com site when you are looking for a manifest.

### What is a package?

Think of a package as an application or a program. We use a "PackageIdentifier" to represent a unique package. These are generally in the form of `Publisher.Package`. Sometimes you might see additional values separated by a second period. We will explain why a little bit later.

### What is a version?

Package versions are associated with a specific release. In some cases you will see a perfectly formed [semantic](https://semver.org) version number, and in other cases you might see something different. These may be date driven, or they might have other characters with some package specific meaning. The YAML key for a package version is "PackageVersion".

### Apps And Features entries

Most installers write accurate version data to the Windows Registry, but not all. To help with version matching and correllation between the installed application and the manifest in repo, additional `AppsAndFeaturesEntries` metadata can be used. These include the `PackageFamilyName`, `ProductCode`, and `UpgradeCode`. Additional information on version matching and correllation, and its impact on sort order, can be found below.

## Understanding the directory structure

Once you have determined the "PackageIdentifier" and the "PackageVersion" it is possible to know the proper location for the manifest. We will use Microsoft Windows Terminal version 1.6.10571.0 for our example.

`manifests / m / Microsoft / WindowsTerminal / 1.6.10571.0`

The partition directory is determined by taking the first letter from the "PackageIdentifier" in lower case. The next directory must match the first segment of the "PackageIdentifier" (case sensitive) up to the first period. This pattern continues until a directory has been created for each section of the "PackageIdentifier" (case sensitive) separated by a period. The last directory must match the "PackageVersion".

## First steps

Before you invest the time to generate and submit a manifest, you should check to see if the package already exists. Start out with `winget search <package>`. If that doesn't yield anything, try a quick search using the search box in the top left corner of GitHub for the package "In this repository". If you still don't find anything, finally check to see if there is already a [PR](https://github.com/microsoft/winget-pkgs/pulls) for the package by putting the package in the filters box, and be sure to remove the "is:pr is:open" filters.

## What next?

You should take a look at our [Manifest Specification]. Don't worry. If this is starting to look too complicated you can create a new Issue and select [Package Request/Submission 👀](https://github.com/microsoft/winget-pkgs/issues/new/choose).

Manifests submitted to the Windows Package Manager Community Repository should be submitted as a multi-file manifest. The minimum required files are a [version][versionSchema] file, a [defaultLocale][defaultLocaleSchema] file and an [installer][installerSchema] file.

## Creating your first manifest

Once you have a package in mind that doesn't already exist in the repository, you can now start [creating your package manifest](https://docs.microsoft.com/en-us/windows/package-manager/package/manifest?tabs=minschema%2Cversion-example). We recommend using the [Windows Package Manager Manifest Creator (a.k.a Winget-Create)](https://github.com/microsoft/winget-create) to help you generate your manifest. Winget-Create is a command line tool that will prompt you for relevant metadata related to your package. Once you are done, Winget-Create will validate your manifest to verify that it is correct and allow you to submit your newly-created manifest directly to the winget-pkgs repository by linking your GitHub account. Alternatively, you can use the [YamlCreate.ps1 Script](Tools/YamlCreate.ps1). More information on using YamlCreate is found in the [script documentation](doc/tools/YamlCreate.md).


### How do I install Winget-Create?

You can either [download the latest release of Winget-Create](https://github.com/microsoft/winget-create/releases) from its GitHub repository or use **Winget** to install it for you by running the following command:

```powershell
winget install wingetcreate
```

### Creating your manifest with Winget-Create

Now that you have Winget-Create installed onto your machine, you are ready to generate your first manifest by running the [New command](https://github.com/microsoft/winget-create/blob/main/doc/new.md). To do so, simply run the following command in your terminal:

```powershell
wingetcreate new <Installer URL(s)>
```

There are many other commands available in Winget-Create to help you [update existing manifests](https://github.com/microsoft/winget-create/blob/main/doc/update.md) or [submit new manifests](https://github.com/microsoft/winget-create/blob/main/doc/submit.md). Feel free to try it out!


## Validation

If you decide to create or edit your manifest by manually editing the YAML, it is important to make sure that you are validating your manifest. You can do this by running the [validate command](https://aka.ms/winget-command-validate) from **Winget** which will tell you if your manifest is valid, or which parts need to be fixed:

```powershell
winget validate --manifest <Path to manifest>
```

## Testing

It is important to test your manifest before submission to ensure it meets the repository's quality standards. While it isn't possible to describe everything that we check for when reviewing contributions, testing your manifest helps keep the quality of contributions high and increases the chance of your contribution being accepted.

* Manifests should be tested to ensure applications can install unattended
* Manifests should be tested to ensure application version matches the Package Version, or that AppsAndFeaturesEntries are included if necessary
* Manifests should be tested to ensure application publisher matches the defaultLocale Publisher, or that AppsAndFeaturesEntries are included if necessary
* Manifests should be tested to ensure application name matches the defaultLocale PackageName, or that AppsAndFeaturesEntries are included if necessary

After enabling the setting for local manifests (`winget settings --enable LocalManifestFiles`), manifests can be tested locally with `winget install --manifest <path>`.
If your system supports Windows Sandbox, you can also use the [SandboxTest.ps1 Script](https://github.com/microsoft/winget-pkgs/blob/master/doc/tools/SandboxTest.md) to test the manifest in the Windows Sandbox. This is the preferred method, as it ensures the package doesn't require any dependencies to install.

## Version Matching & Correllation

The goal is to accurately determine the currently installed version, and all available versions of this application, so upgrades can be correctly suggested when available, and not suggested when not available. Most installers write accurate version data to the Windows Registry, but some do not. Winget writes these entries for portable installer type, so they are guaranteed to match. The data available to meet this goal consists of the files on disk, data in Windows Registry, and manifests in the winget-pkgs repo.

### Metadata 

- AppsAndFeaturesEntries
  - DisplayName
  - DisplayVersion
    - Displayed in the Control Panel's Add & Remove Programs page (ARP) and/or Apps and features Settings page (ANF). 
    - Should not be used if it's equal to PackageVersion, in every manifest for a given PackageIdentifier.
    - Must be unique per PackageIdentifier. If multiple versions are sharing the same DisplayVersion, we may only keep the 'latest' one in the repo.
  - ProductCode (MSI & EXE) & UpgradeCode (MSI)
    - MSI installers provide these directly.
    - EXE installers often provide a ProductCode - defined by the Registry key written by the installer.
- Outside of AppsAndFeaturesEntries.
  - Package Familyname (MSIX)
  - ProductCode (MSI & EXE) (See above)
    - The ProductCode can be at any level.

### 4 main use cases: 

- Package does not write DisplayVersion to registry.
  - DisplayName contains version. DisplayName is required in every manifest, to match installed packages to available versions.
  - ProductCode contains version. ProductCode is required in every manifest, to match installed packages to available versions.
- PackageVersion differed from DisplayVersion at any point in the manifest history. PackageVersion is required in every manifest, to prevent version range mapping errors.
- ProductCode of the installed product differs from the ProductCode of the installer. ProductCode is required in at least one manifest to match installed packages to available packages.

## Sorting and sort order

Inherently all the versions are strings - a sematic version is just a string with a certain format. YAML will interpret any alpha-numerics as strings automatically, and if there are multiple, it is smart enough to interpret that value as a string also. The quotes are only needed when the value is also a valid decimal number as 1.23 can be interpreted as string or a number whereas "1.23" can only be interpreted as a string

- Winget breaks at each dot and compares each part individually. Where a part contains an numeral-alpha, the numeral is considered before the alpha.

Versions are parsed by:
1. Parse approximate comparator sign if applicable.
2. Split the string based on the given variable data.
3. Parse a leading, positive integer from each split part.
4. Save any remaining non-digits as a supplemental value.

Versions are compared by:
- For each part in each version:
  -  If both sides have no more parts, return equal.
  -  Else if one side has no more parts, it is less.
  -  Else if integers are not equal, return comparison of integers.
  -  Else if only one side has a non-empty string part, it is less.
  -  Else if string parts not equal, return comparison of strings.
- If all parts are same, use approximate comparator if applicable (not approximate to another approximate version, and not unknown).

## Pre-release, early release, release candidate, and alpha & beta versions. 

Many packages have "pre-release" PackageIdentifiers, to both spread the pre-release client and also keep mainline users on the stable release. When pre-release packages are submitted under a mainline PackageIdentifier, it can be disruptive to users who value stability over new features. And sometimes the pre-release version number includes a letter, disrupting the sort order. There is definite demand for most pre-release software, and creating a pre-release PackageIdentifier is a great way to help satisfy this demand while still meeting the need to deliver a stable product.  

Developers are free to version their products as they please. This section is meant to guide manifest submitters in creating manifests to meet both needs. While we try to ensure packages install and upgrade correctly, we don't necessarily know all software and their release mechanisms/cadences. Having an open-source repository allows individuals with much better knowledge of specific software packages to maintain those packages, including splitting pre-release channels from mainline channels when appropriate. 

### How to tell if it's a release candidate?

- Most developers are very clear about pre-release and mainline versions. Ideally, this would be communicated to users through manifests and PackageIdentifiers. 
- Some developers might add a common term such as `.alpha`, `.beta`, `.pre`,  `.rc`, - or an alphabet letter such as `b`, or other indicator to their version numbers.
- Other developers might add a different development line with a separate repo, different application names and icons, and separate version schema.
- Not all letters indicate pre-release channels. For example, some developers append "-E" to the version number, to differentiate mainline Electron releases from their other mainline releases. If in doubt, ask the developer. 

### How to make pre-release versions available

If the pre-release versions have different metadata, then just appending the appropriate term to the mainline PackageIdentifier might be enough. The appropriate term would depend on how the developers refer to their early releases. And this new PackageIdentifier would replace the mainline PackageIdentifier in pre-release manifests, manifest names, and manifest paths. 

Some examples: 

Microsoft.OpenSSH: 

- Mainline PackageIdentifier: `Microsoft.OpenSSH`
- Mainline Repository path: ./manifests/m/Microsoft/OpenSSH

- Beta PackageIdentifier: `Microsoft.OpenSSH.Beta`
- Beta Repository path: ./manifests/m/Microsoft/OpenSSH/Beta

Microsoft Edge: 

- Mainline PackageIdentifier: `Microsoft.Edge`
- Mainline Repository path: ./manifests/m/Microsoft/Edge
- AppsAndFeaturesEntries:
  - DisplayName: Microsoft Edge
  - UpgradeCode: '{883C2625-37F7-357F-A0F4-DFAF391B2B9C}'

- Beta PackageIdentifier: `Microsoft.Edge.Beta`
- Beta Repository path: ./manifests/m/Microsoft/Edge/Beta
- AppsAndFeaturesEntries:
  - DisplayName: Microsoft Edge Beta
  - UpgradeCode: '{55B884A6-908D-3E59-BDCE-5E4BFA64FA7B}'

Use the version number that the pre-release software adds to Apps and features Settings page, or other locations including the Registry, so that the WinGet package manager can provide updates to the pre-release version. 

Note: Pre-release PackageIdentifiers are subordinate to mainline PackageIdentifiers. If the pre-release PackageIdentifier is causing an issue in the mainline, such as causing an upgrade loop by having an identical UpgradeCode, then the mainline should have priority and the pre-release version should be modified or removed.

### Support for release channels (released, beta, alpha)

Notes, ideas, and discussion on how to implement and support release channels [is ongoing](https://github.com/microsoft/winget-cli/issues/147).

## Troubleshooting

###  Display Version Overlap: 

- Can be caused by the PackageVersion differring from the DisplayVersion at any point in the manifest history, and the fix is to add the DisplayVersion to every manifest. 
  - Another option is to remove the manifests where these values differ.
- Cause: 
  - Each manifest creates its own a range of DisplayVersion numbers, between the lowest and highest DisplayVersion in the same manifest. 
  - Multiple manifests can create multiple ranges within a PackageIdentifier, but these DisplayVersion ranges cannot overlap.
  - Actual log example: `2024-01-31T22:16:48.6603831Z ##[error] Manifest Error: DisplayVersion declared in the manifest has overlap with existing DisplayVersion range in the index. Existing DisplayVersion range in index: [ [5.17.5 (31030), 5.17.5 (31030)]]`
    - "Manifest" indicates the current PR's manifest.
    - "Index" indicates all manifests currently in the repo and under the same PackageIdentifier.
- This might lead to unexpected matching situations. For example, if the version ranges are 5.17.2 to 5.17.29988, and a PR's version is 5.17.5, then it falls inside that range.

### Scope swapping, accidental side-by-side installs, and one of the packages refuses to upgrade: 

- This issue appears to be common to WIX installers. 
- When installing to `%LOCALAPPDATA%` for `user` scope, the software package's registry entries are added to `HKEY_LOCAL_MACHINE` instead of `HKEY_CURRENT_USER`.
- This makes the `user` scope software package appear to be of `machine` scope instead.
  - Related to [Winget incorrectly detects per-user MSI scope (`No applicable update found`)](https://github.com/microsoft/winget-cli/issues/3011)
- So a user can only get a "user" scope when installing for the first time, unless one of the below Workarounds is in place. 
- This means, for subsequent upgrades through `winget upgrade`, the user will end up getting the "machine" scope installation. 
  - A dual (or side-by-side) installation of the package (both user and machine scope) will result. 
  - And both of these may show up in `winget list` and other places which list installed packages, causing confusion. Especially when one of the packages refuses to upgrade. 
- Workarounds: 
  - Package maintainers can remove `user` scope from packages, 
  - Technical users can still retain the user scope install if they want by passing the args to the installer on update. For example:

` winget upgrade Package.Identifier --custom "MSIINSTALLPERUSER=1"`

### Upgrade always available for one package.

This issue is slightly different from scope swapping above, in that there's only one version of the package installed. It can be caused by a few different situations:

- Two manifests have the same data. If both the variants use the same DisplayName, ProductCode, Publisher and other package matching related information, then an existing install of a stable package may be mapped to a higher available version of a pre-release version by WinGet, even if the PackageIdentifiers are different. The fix is to remove the pre-release manifest, as the mainline has priority.
- Version schema changes significantly - or changes between string and semantic. If a letter is added to one version number, then it can cause this issue with every version of the package. The fix is to remove manifests with the previous version schema, and only offer those with the latest schema.
- Installer not writing accurate version data to the Windows Registry - either every installer writes the same version number, do not write a version number, do not write a consistent or accurate version number or have a similar issue with the version data in the registry. The fix here is to add the Apps and features metadata described above.
- Manifest has an incorrect PackageVersion specified. 

### For a package that always writes the same version to registry: 

As described earlier, the DisplayVersion must be unique for every version of a package. 

- Our package manager only updates the Windows Registry for `Portable` applications. 
- If all versions of a package write the same DisplayVersion to Control Panel, then the best option is to only offer the latest version of the package. 
- This situation is similar to the situation for vanity URLs, which always host the latest version of the package.
