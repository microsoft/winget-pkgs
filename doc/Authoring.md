[Manifest Specification]:   manifest/schema/1.10.0
[versionSchema]:            manifest/schema/1.10.0/version.md
[defaultLocaleSchema]:      manifest/schema/1.10.0/defaultLocale.md
[installerSchema]:          manifest/schema/1.10.0/installer.md

# Authoring Manifests

First, we want to say thank you. Your contribution is highly valued, and we appreciate the time you have taken to get here and read this document. Let's start with a few definitions to help you understand our vocabulary.

## Definitions

### What is a manifest?

Manifests are YAML files in this repository containing metadata used by the Windows Package Manager to install and upgrade software on Windows. These files are organized under the [manifests](../manifests/) directory. The directory structure is partitioned to make navigation easier on GitHub.

### What is a package?

A package refers to an application or program. Each package is uniquely identified by a "PackageIdentifier," typically in the format `Publisher.Package`. Additional segments may appear, separated by periods, for specific cases.

### What is a version?

Package versions correspond to specific releases. These may follow [semantic versioning](https://semver.org) or other formats, such as date-based versions. The YAML key for a package version is "PackageVersion."

## Understanding the directory structure

The directory structure for a manifest is determined by the "PackageIdentifier" and "PackageVersion." For example, the directory for Microsoft Windows Terminal version 1.6.10571.0 would be:

`manifests / m / Microsoft / WindowsTerminal / 1.6.10571.0`

- The first directory is the lowercase first letter of the "PackageIdentifier."
- Subsequent directories match each segment of the "PackageIdentifier" (case-sensitive).
- The final directory matches the "PackageVersion"

## First steps

Before creating and submitting a manifest, check if the package already exists:
1. Run `winget search <package>` in your terminal.
2. Search for the package in this repository using GitHub's search box.
3. Check for existing [pull requests](https://github.com/microsoft/winget-pkgs/pulls) related to the package.

## What next?

Review the [Manifest Specification]. If the process seems complex, you can create a new issue and select [Package Request/Submission 👀](https://github.com/microsoft/winget-pkgs/issues/new/choose).

Manifests submitted to this repository should be multi-file manifests. The minimum required files are:
- A [version][versionSchema] file
- A [defaultLocale][defaultLocaleSchema] file
- An [installer][installerSchema] file

## Creating your first manifest

If the package doesn't already exist, start [creating your package manifest](https://docs.microsoft.com/en-us/windows/package-manager/package/manifest?tabs=minschema%2Cversion-example). We recommend using the [Windows Package Manager Manifest Creator (Winget-Create)](https://github.com/microsoft/winget-create), a command-line tool that guides you through the process and validates your manifest.

Alternatively, you can use the [YamlCreate.ps1 Script](../Tools/YamlCreate.ps1). See the [script documentation](tools/YamlCreate.md) for details.

## Installer Architectures

When specifying installer types, ensure the architecture reflects the installed binaries, not just the installer itself. For example, an x86 installer that installs x64 binaries should have its architecture set to x64.

### How do I install Winget-Create?

Download the latest release from the [Winget-Create GitHub repository](https://github.com/microsoft/winget-create/releases) or install it using Winget:

```powershell
winget install wingetcreate
```

### Creating your manifest with Winget-Create

After installing Winget-Create, generate your first manifest by running:

```powershell
wingetcreate new <Installer URL(s)>
```

Explore other commands for [updating existing manifests](https://github.com/microsoft/winget-create/blob/main/doc/update.md) or [submitting new manifests](https://github.com/microsoft/winget-create/blob/main/doc/submit.md).

## Validation

If you manually edit the YAML, validate your manifest using the following command:

```powershell
winget validate --manifest <Path to manifest>
```

## Testing

Test your manifest before submission to ensure it meets quality standards:
- Verify the application installs unattended.
- Ensure the application version matches the "PackageVersion" or includes `AppsAndFeaturesEntries` if necessary.
- Confirm the application publisher matches the defaultLocale "Publisher" or includes `AppsAndFeaturesEntries` if necessary.
- Check that the application name matches the defaultLocale "PackageName" or includes `AppsAndFeaturesEntries` if necessary.

Enable local manifest testing with:

```powershell
winget settings --enable LocalManifestFiles
winget install --manifest <path>
```

For a more isolated test, use the [SandboxTest.ps1 Script](https://github.com/microsoft/winget-pkgs/blob/master/doc/tools/SandboxTest.md) to test in Windows Sandbox.

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
