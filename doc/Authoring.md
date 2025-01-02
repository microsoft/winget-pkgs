[Manifest Specification]:   manifest/schema/1.9.0
[versionSchema]:            manifest/schema/1.9.0/version.md
[defaultLocaleSchema]:      manifest/schema/1.9.0/defaultLocale.md
[installerSchema]:          manifest/schema/1.9.0/installer.md

# Authoring Manifests

First, we want to say thank you. Your contribution is highly valued. And we appreciate the time you have taken to get here and read this document. Let's start out with a few definitions to help you understand our vocabulary.

## Definitions

### What is a manifest?

Manifests are the YAML files in this repository containing the metadata used by the Windows Package Manager to install and upgrade software on Windows 10. There are thousands of these files partitioned under the [manifests](../manifests/) directory. We've had to partition the directory structure so you don't have to scroll as much in the GitHub.com site when you are looking for a manifest.

### What is a package?

Think of a package as an application or a program. We use a "PackageIdentifier" to represent a unique package. These are generally in the form of `Publisher.Package`. Sometimes you might see additional values separated by a second period. We will explain why a little bit later.

### What is a version?

Package versions are associated with a specific release. In some cases you will see a perfectly formed [semantic](https://semver.org) version number, and in other cases you might see something different. These may be date driven, or they might have other characters with some package specific meaning. The YAML key for a package version is "PackageVersion".

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

Once you have a package in mind that doesn't already exist in the repository, you can now start [creating your package manifest](https://docs.microsoft.com/en-us/windows/package-manager/package/manifest?tabs=minschema%2Cversion-example). We recommend using the [Windows Package Manager Manifest Creator (a.k.a Winget-Create)](https://github.com/microsoft/winget-create) to help you generate your manifest. Winget-Create is a command line tool that will prompt you for relevant metadata related to your package. Once you are done, Winget-Create will validate your manifest to verify that it is correct and allow you to submit your newly-created manifest directly to the winget-pkgs repository by linking your GitHub account. Alternatively, you can use the [YamlCreate.ps1 Script](../Tools/YamlCreate.ps1). More information on using YamlCreate is found in the [script documentation](tools/YamlCreate.md).

## Installer Architectures

If you are authoring a manifest yourself one of the important things to note related to installer types is architecture. In many cases the installer itself may be an x86 installer, but it will actually install the package for the architecture of the system. In these cases, the installer type in the manifest should indicate the architecture of the installed binaries. So in some cases the actual installer itself targets x86, but in fact it will install an x64 version of the package.


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

## Advanced Authoring

### AppsAndFeaturesEntries

Most installers write accurate version data to the Windows Registry, but not all. To help with version matching and correllation between the installed application and the manifest in repo, additional `AppsAndFeaturesEntries` metadata can be used. These include the `PackageFamilyName`, `ProductCode`, `UpgradeCode`, and `InstallerType`. Additional information on how `AppsAndFeaturesEntries` affect version matching, package correllation, and sort order can be found below.

#### What is Version Matching & Package Correllation?

Version Matching and Package Correlation is the process by which WinGet attempts to correlate the metadata for an application installed on your machine and match it to a specific package (Package Correlation) and a specific version of that package (Version Matching) which is available in any source. The goal is to accurately determine the currently installed application and its version so that upgrades can be correctly suggested when available (and not suggested when not available). To do this, WinGet relies on data in Windows Registry and the information available from your configured sources.

#### When is AppsAndFeaturesEntries needed?

There are a few typical use cases when `AppsAndFeaturesEntries` should be specified in a manifest.

1. The installer does not write a `DisplayVersion` to registry and either of the following are true:
   1.  The `DisplayName` contains the version.
   2.  The `ProductCode` contains version.

	In either of these cases, the respective field is required in every manifest to accurately match the installed package version to an available version from the source.

2. The `PackageVersion` differed from the installer's `DisplayVersion` at any point in the manifest history.

    In this case, `DisplayVersion` is required in every manifest to prevent version range mapping errors. If the field is left out, users will be caught in an upgrade loop where the `Available` version shown when running `winget upgrade` is lower than the `PackageVersion` of the latest manifest.

3. The `DisplayVersion` the installer writes to the registry is inherently un-ordered or cannot be sorted properly by WinGet

    There are many ways that publishers choose to version their software. This leads to some cases where the way WinGet sorts versions will not work properly. Some examples include packages that only use commit hashes for their releases, packages which prefix the version number with a string, or packages using date versioning of DD-MM-YYYY.

	When this happens, `PackageVersion` should be set to something which is sortable by WinGet and `DisplayVersion` should be set to the value the installer writes to the registry. For more information, see the section on [Version Sorting in WinGet](../doc/Authoring.md#version-sorting-in-winget)

4. The `InstallerType` of the installer which writes the registry keys does not match the `InstallerType` of the manifest

    In some cases an EXE installer may call an embedded MSI which writes data to the registry in a different format. While the `InstallerType` may be correctly identified in the manifest, the WinGet CLI will detect the registry entries as being from an MSI and return an error that the installation technology does not match when running `winget upgrade`. This requires the `InstallerType` to be specified in `AppsAndFeaturesEntries`

For more information on how to specify `AppsAndFeaturesEntries` and what the available metadata fields are, please see the [Manifest Specification](../doc/manifest/).

## Version Sorting in WinGet

Inherently, all versions are strings. Whether a publisher uses a date code, a commit hash, or some other crazy format they are all saved as string values in the Windows Registry. In fact, a sematic version is just a string with a certain format. To convert these strings into versions and sort them, WinGet goes through the following process.

> [!IMPORTANT]
> Step 1 of the below process only occurs in WinGet version 1.9.1763-preview or newer
> If you are using an older version of WinGet, version preambles may not be handled correctly

1. If there is a digit before the first `.` or there is no `.`, trim off all leading non-digit characters.
   Examples:
    * `v1.0.1` becomes `1.0.1`
    * `version 12` becomes `12`
2. Split the string at each `.`, discarding the `.`
3. Create a new `Part` from each of the split sections
    * A `Part` consists of two components - an `integer`, and a `string`
	* To create a `Part`, whitespace characters are first trimmed from the start and end of the section
	* Then, numeric characters are parsed from the start of the section and used to create the `integer`.
	* Once a non-numeric character is encountered, the remainder of the section is considered the `string`
	* Example: If the section is `2024Mar15`, then `2024 → integer` and `Mar15 → string`
4. Compare the two parts created from the first section of the `Version`.
	* If the two parts are not equal, whichever `Part` is larger corresponds to the larger version
	* See below for an explanation on how parts are compared
5. If the two parts are equal, repeat step 3 with each consecutive pair of parts
	* If both versions have no more parts, they are equal
	* If one version has more parts and the other does not, pad the shorter version with an additional `0` as needed

When comparing one `Part` to another, WinGet goes through the following process.

1. Compare the two `integer` values
	* If the two `integer` are not equal, whichever `Part` has the larger `integer` is larger
2. If the two `integer` are equal, check if there is a value in `string`
	* If both values of `string` are empty, the parts are equal
	* If one `Part` has a value in `string` and the other does not, the `Part` which ***does not*** have a value in `string` is considered to be greater
	* Example: When comparing `34` and `34-beta`, the `integer` is equal for both (`34`). However, the `string` for the former is empty and the `string` for the latter is `-beta`, so `34` is the larger `Part`. This leads to `1.2.34` being considered a higher `Version` than `1.2.34-beta`
4. If both parts have a value in `string`, perform a case-insensitive comparison of the two
	* If the values of `string` are not equal, the lexicographic comparison determines which `Part` is larger

#### Examples of Version Comparisons

| Version A | Version B | Comparison Result | Explanation |
| --- | --- | --- | ---|
| 1.2.0 | 1.2 | Equal | `Version B` will be padded with zeros to match the same number of `Parts` as `Version A` |
| 1.2 | 1.2-rc | `Version A` | The `-rc` causes `Version B` to have a `string` in the second `Part` where `Version A` does not |
| 1.2.3 | 1.2.4-rc | `Version B` | The `integer` on the third `Part` is larger for `Version B` |
| v1.2 | 1.1 | `Version A` | The leading `v` will be trimmed off of `Version A`, and `1.2` is a higher version than `1.1` due to integer comparison in the second `Part` |
| 1.2.3a | 1.2.3b | `Version B` | `b` is lexicographically greater than `a` |
