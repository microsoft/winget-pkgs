# Authoring Manifests

First, we want to say thank you. Your contribution is highly valued. And we appreciate the time you have taken to get here and read this document. Let's start out with a few definitions to help you understand our vocabulary.

## Definitions

### What is a manifest?

Manifests are the YAML files in this repository containing the metadata used by the Windows Package Manager to install and upgrade software on Windows 10. There are hundreds of these files partitioned under the [manifests](/manifests) directory. We've had to partition the directory structure so you don't have to scroll as much in the GitHub.com site when you are looking for a manifest.

### What is a package?

Think of a package as an application or a program. We use a "PackageIdentifier" to represent a unique package. These are generally in the form of `Publisher.Package`. Sometimes you might see additional values separated by a second period. We will explain why a little bit later.

### What is a version?

Package versions are associated with a specific release. In some cases you will see a perfectly formed [semantic](https://semver.org) version number, and in other cases you might see something different. These may be date driven, or they might have other characters with some package specific meaning. The YAML key for a package version is "PackageVersion".

## Understanding the directory structure

Once you have determined the "PackageIdentifier" and the "PackageVersion" it is possible to know the proper location for the manifest. We will use Microsoft Windows Terminal version 1.6.10571.0 for our example.

`manifests / m / Microsoft / WindowsTerminal / 1.6.10571.0`

The partition directory is determined by taking the first letter from the "PackageIdentifier" in lower case. The next directory must match the first segment of the "PackageIdentifier" (case sensitive) up to the first period. This pattern continues until a directory has been created for each section of the "PackageIdentifier" (case sensitive) separated by a period. The last directory must match the "PackageVersion".

## First steps

Before you invest the time to generate and submit a manifest, you should check to see if the package already exists. Start out with `winget search package`. If that doesn't yield anything, try a quick search using the search box in the top left corner of GitHub for the package "In this repository". If you still don't find anything, finally check to see if there is already a [PR](https://github.com/microsoft/winget-pkgs/pulls) for the package by putting the package in the filters box, and be sure to remove the "is:pr is:open" filters.

## What next?

You should take a look at our [v1.0 manifest specification](https://github.com/microsoft/winget-cli/blob/master/doc/ManifestSpecv1.0.md). Don't worry. If this is starting to look too complicated you can create a new Issue and select [Package Request/Submission 👀](https://github.com/microsoft/winget-pkgs/issues/new/choose).

The multi-file manifest is the preferred method for building manifests. The mimimum required files are a [version](doc/manifest/schema/1.0.0/version.md) file, a [defaultLocale](doc/manifest/schema/1.0.0/defaultLocale.md) file and an [installer](doc/manifest/schema/1.0.0/installer.md) file.
