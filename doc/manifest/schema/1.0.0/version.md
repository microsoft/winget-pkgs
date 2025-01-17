[JSON schema]:              https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.0.0/manifest.version.1.0.0.json
[YAML]:                     https://yaml.org/spec
[semantic version]:         https://semver.org
[Manifest Specification]:   https://github.com/microsoft/winget-pkgs/blob/master/doc/manifest/README.md

# Windows Package Manager
## Manifest Schema v1.0.0 Version File

All Windows Package Manager manifests in the Microsoft community repository are submitted using [YAML] syntax. A JSON schema is provided to aid authoring these files in editors, and in the other tooling related to the Windows Package Manager. This document provides detailed information regarding the usage of the YAML keys in the [version][JSON schema] file for multi-file manifests. Please review the [Manifest Specification] if you are not familiar with this file.

## Fields
### PackageIdentifier
<details>
 <summary>The package unique identifier</summary>

 #### Required Field
 This key is the unique identifier for a given package. This value is generally in the form of `Publisher.Package`. It is case sensitive, and this value must match the folder structure under the partition directory in GitHub.
</details>

### PackageVersion
<details>
 <summary>The package version</summary>

 #### Required Field
 This key represents the version of the package. It is related to the specific release this manifests targets. In some cases you will see a perfectly formed [semantic version] number, and in other cases you might see something different. These may be date driven, or they might have other characters with some package specific meaning for example.

 The Windows Package Manager client uses this version to determine whether or not an upgrade for a package is available. In some cases, packages may be released with a marketing driven version, and that causes trouble with the `winget upgrade` command.

 The current best practice is to use the value reported in Add / Remove Programs when this version of the package is installed. In some cases, packages do not report a version resulting in an upgrade loop or other unwanted behavior.
</details>

### DefaultLocale
<details>
 <summary>The default package meta-data locale</summary>

 #### Required Field
 This key represents the default locale for package meta-data. The format is BCP-47. This value identifies the language for meta-data to be displayed to a user when no locale file matching their preferences is available. The Microsoft community package repository validation pipelines also use this value to determine appropriate validation rules for that corresponding locale file.
</details>

### ManifestType
<details>
 <summary>The manifest type</summary>

 #### Required Field
 This key must have the value "version". The Microsoft community package repository validation pipelines also use this value to determine appropriate validation rules when evaluating this file.
</details>

### ManifestVersion
<details>
 <summary>The manifest syntax version</summary>

 #### Required Field
 This key must have the value "1.0.0". The Microsoft community package repository validation pipelines also use this value to determine appropriate validation rules when evaluating this file.
</details>
