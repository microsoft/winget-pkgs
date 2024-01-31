[Manifest Specification]:   doc/manifest/schema/1.5.0
[versionSchema]:            doc/manifest/schema/1.5.0/version.md
[defaultLocaleSchema]:      doc/manifest/schema/1.5.0/defaultLocale.md
[installerSchema]:          doc/manifest/schema/1.5.0/installer.md

# Authoring Manifests

First, we want to say thank you. Your contribution is highly valued. And we appreciate the time you have taken to get here and read this document. Let's start out with a few definitions to help you understand our vocabulary.

## Definitions

### What is a manifest?

Manifests are the YAML files in this repository containing the metadata used by the Windows Package Manager to install and upgrade software on Windows 10. There are thousands of these files partitioned under the [manifests](/manifests) directory. We've had to partition the directory structure so you don't have to scroll as much in the GitHub.com site when you are looking for a manifest.

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
