[JSON schema]:      https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.5.0/manifest.version.1.5.0.json
[YAML]:             https://yaml.org/spec
[semantic version]: https://semver.org

# Windows Package Manager
## Manifest Schema v1.5.0 Version File

All Windows Package Manager manifests in the Microsoft community repository are submitted using [YAML] syntax. A [JSON schema] is provided to aid authoring these files in editors, and in the other tooling related to the Windows Package Manager. This document provides detailed information regarding the usage of the YAML keys in the version file for multi-file manifests.

### Version Manifest

```YAML
PackageIdentifier:      # The package unique identifier
PackageVersion:         # The package version
DefaultLocale:          # The default package meta-data locale
ManifestType: version   # The manifest type
ManifestVersion: 1.5.0  # The manifest syntax version
```

## Fields

<details>
 <summary><b>PackageIdentifier</b> - The package unique identifier</summary>

 **Required Field**

 This key is the unique identifier for a given package.

 **Windows Package Manager Community Repository**

 This value is generally in the form of `Publisher.Package`. It is case sensitive, and this value must match the folder structure under the partition directory.
</details>

<details>
 <summary><b>PackageVersion</b> - The package version</summary>

 **Required Field**

 This key represents the version of the package. It is related to the specific release this manifests targets. In some cases you will see a perfectly formed [semantic version] number, and in other cases you might see something different. These may be date driven, or they might have other characters with some package specific meaning for example.

 The Windows Package Manager client uses this version to determine whether or not an upgrade for a package is available. In some cases, packages may be released with a marketing driven version, and that causes trouble with the `winget upgrade` command.

 The current best practice is to use the value reported in Add / Remove Programs when this version of the package is installed. In some cases, packages do not report a version resulting in an upgrade loop or other unwanted behavior.
</details>

<details>
 <summary><b>DefaultLocale</b> - The default package meta-data locale</summary>

 **Required Field**

 This key represents the default locale for package meta-data. The format is BCP-47. This value identifies the language for meta-data to be displayed to a user when no locale file matching their preferences is available.

 **Windows Package Manager Community Repository**

 The validation pipelines use this value to ensure the corresponding locale file is present and conforms with the defaultLocale YAML specification.
</details>

<details>
 <summary><b>ManifestType</b> - The manifest type</summary>

 **Required Field**

 This key must have the value "version". The Microsoft community package repository validation pipelines also use this value to determine appropriate validation rules when evaluating this file.
</details>

<details>
 <summary><b>ManifestVersion</b> - The manifest syntax version</summary>

 **Required Field**
 This key must have the value "1.5.0". The Microsoft community package repository validation pipelines also use this value to determine appropriate validation rules when evaluating this file.
</details>
