[JSON schema]:                                      https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.0.0/manifest.defaultLocale.1.0.0.json
[YAML]:                                             https://yaml.org/spec/
[Manifest Specification]:                           https://github.com/microsoft/winget-pkgs/blob/master/doc/manifest/README.md
[semantic version]:                                 https://semver.org
[Available languages for Windows]:                  https://docs.microsoft.com/windows-hardware/manufacture/desktop/available-language-packs-for-windows
[Default Input Profiles Input Locales in Windows]:  https://docs.microsoft.com/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs
[install]:                                          https://docs.microsoft.com/windows/package-manager/winget/install
[list]:                                             https://docs.microsoft.com/windows/package-manager/winget/list
[upgrade]:                                          https://docs.microsoft.com/windows/package-manager/winget/upgrade

# Windows Package Manager
## Manifest Schema v1.0.0 Default Locale File

All Windows Package Manager manifests in the Microsoft community repository are submitted using [YAML] syntax. A JSON schema is provided to aid authoring these files in editors, and in the other tooling related to the Windows Package Manager. This document provides detailed information regarding the usage of the YAML keys in the [default locale][JSON schema] file for multi-file manifests. Please review the [Manifest Specification] if you are not familiar with this file.

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

#### PackageLocale
<details>
  <summary>The package meta-data locale</summary>

  #### Required Field
  This key represents the locale for package meta-data. The format is BCP-47. This value identifies the language for meta-data to be displayed to a user when no locale file matching their preferences is available. The Microsoft community package repository validation pipelines also use this value to determine appropriate validation rules for this file.

  References:
  * [Available languages for Windows]
  * [Default Input Profiles (Input Locales) in Windows]

  >Note: This field is the key to determining which fields are required for the Microsoft community repository. The default locale specified in the version file must match with this value.
 </details>

#### Publisher
<details>
  <summary>The publisher name</summary>

  #### Required Field
  This key represents the name of the publisher for a given package. This field is intended to allow the full publisher's or ISV's name to be displayed as they wish.

  >Note: With the 1.0 release of the Windows Package Manager, this name affects how packages from a source are mapped to Apps installed in Windows 10 via Add / Remove Programs (ARP). The best practice is to ensure this matches the ARP entry for the package when it has been installed. The impact is associated with `winget upgrade` and `winget list`.
 </details>

#### PublisherUrl
<details>
  <summary>The publisher home page</summary>

  #### Optional Field
  This key represents the web site for the publisher or ISV.
 </details>

#### PublisherSupportUrl
<details>
  <summary>The publisher support page</summary>

  #### Optional Field
  This key represents the customer support web site or specific web page provided by the publisher or ISV.
 </details>

#### PrivacyUrl
<details>
  <summary>The publisher privacy page or the package privacy page</summary>

  #### Optional Field
  This key represents the privacy web site or specific web page provided the publisher or ISV. If there is a privacy web site or specific web page for the package it is preferred over a generic privacy page for the publisher.
 </details>

#### Author
<details>
  <summary>The package author</summary>

  #### Optional Field
  This key represents the author of a package. In some cases, the author is an individual who develops and or maintains the package.
 </details>

#### PackageName
<details>
  <summary>The package name</summary>

  #### Required Field
  This key represents the name of the package. This field is intended to allow the full package name to be displayed as the publisher or ISV wishes.

  >Note: With the 1.0 release of the Windows Package Manager, this name affects how packages from a source are mapped to Apps installed in Windows 10 via Add / Remove Programs (ARP). The best practice is to ensure this matches the ARP entry for the package name when it has been installed. The impact is associated with `winget upgrade` and `winget list`.
 </details>

#### PackageUrl
<details>
  <summary>The package home page</summary>

  #### Optional Field
  This key represents the web site for the package.
 </details>

 #### License
<details>
  <summary>The package license</summary>

  #### Required Field
  This key represents the license governing the use and or distribution for the product. This could be an open source license, or a commercial license.
 </details>

 #### LicenseUrl
<details>
  <summary>The license page</summary>

  #### Optional Field
  This key represents the license web site or specific web page provided the publisher or ISV. If there is a license web site or specific web page for the package it is preferred over a generic license page for the publisher.

  If this is a link to the license file for an open source project, it should be specific to the version for the package. Some open source projects change their license over time.
 </details>

 #### Copyright
<details>
  <summary>The package copyright</summary>

  #### Optional Field
  This key represents the copyright for the package.
 </details>

 #### CopyrightUrl
<details>
  <summary>The package copyright page</summary>

  #### Optional Field
  This key represents the copyright web site or specific web page provided the publisher or ISV. If there is a copyright web site or specific web page for the package it is preferred over a generic copyright page for the publisher.

  If this is a link to the copyright file for an open source project, it should be specific to the version for the package. Some open source projects change their copyright over time.
 </details>

 #### ShortDescription
<details>
  <summary>The short package description</summary>

  #### Required Field
  This key represents the description for a package. It is intended for use in `winget show` to help a user understand what the package is.

  >Note: This should be something descriptive about what the package does, and it should not simply state something like "&lt;package name&gt; installer" or "&lt;package name&gt; setup".
 </details>

 #### Description
<details>
  <summary>The full package description</summary>

  #### Optional Field
  This key represents the full or long description for a package. It is *not* currently used in the Windows Package Manager.

  >Note: This was included for future integration with the Microsoft Store source to provide the ability to display the full package description.
 </details>

 #### Moniker
<details>
  <summary>The most common package term</summary>

  #### Optional Field
  This key represents the most common term users would search for when installing or upgrading a package. If only one package uses this moniker, then the [install], [list] and [upgrade] command may match with this package.

  >Note:Moniker is the third property evaluated when searching for a matching package.
 </details>

 #### Tags
<details>
  <summary>List of additional package search terms</summary>

  #### Optional Field
  This key represents other common term users would search for when looking for packages.

  >Note: The best practice is to present these terms in all lower case with hyphens rather than spaces.
 </details>


### ManifestType
<details>
 <summary>The manifest type</summary>

 #### Required Field
 This key must have the value "defaultLocale". The Microsoft community package repository validation pipelines also use this value to determine appropriate validation rules when evaluating this file.
</details>

### ManifestVersion
<details>
 <summary>The manifest syntax version</summary>

 #### Required Field
 This key must have the value "1.0.0". The Microsoft community package repository validation pipelines also use this value to determine appropriate validation rules when evaluating this file.
</details>
