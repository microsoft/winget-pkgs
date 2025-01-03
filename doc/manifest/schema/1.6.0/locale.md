[JSON schema]:                                      https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.6.0/manifest.locale.1.6.0.json
[YAML]:                                             https://yaml.org/spec
[semantic version]:                                 https://semver.org
[Available languages for Windows]:                  https://docs.microsoft.com/windows-hardware/manufacture/desktop/available-language-packs-for-windows
[locales]:                                          https://docs.microsoft.com/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs
[install]:                                          https://docs.microsoft.com/windows/package-manager/winget/install
[list]:                                             https://docs.microsoft.com/windows/package-manager/winget/list
[upgrade]:                                          https://docs.microsoft.com/windows/package-manager/winget/upgrade
[uninstall-registry]:                               https://learn.microsoft.com/en-us/windows/win32/msi/uninstall-registry-key

# Windows Package Manager
## Manifest Schema v1.6.0 Locale File

All Windows Package Manager manifests in the Microsoft community repository are submitted using [YAML] syntax. A [JSON schema] is provided to aid authoring these files in editors, and in the other tooling related to the Windows Package Manager. This document provides detailed information regarding the usage of the YAML keys in the locale file for multi-file manifests.

### Locale Manifest

```YAML
PackageIdentifier:            # The package unique identifier
PackageVersion:               # The package version
PackageLocale:                # The package meta-data locale
Publisher:                    # Optional publisher name
PublisherUrl:                 # Optional publisher home page
PublisherSupportUrl:          # Optional publisher support page
PrivacyUrl:                   # Optional publisher privacy page
Author:                       # Optional author
PackageName:                  # Optional package name
PackageUrl:                   # Optional package home page
License:                      # Optional package license
LicenseUrl:                   # Optional package license page
Copyright:                    # Optional package copyright
CopyrightUrl:                 # Optional package copyright page
ShortDescription:             # Optional short package description
Description:                  # Optional full package description
Tags:                         # Optional list of package terms
Agreements:                   # Optional package agreements
  - AgreementLabel:           # Optional agreement label
    Agreement:                # Optional agreement text
    AgreementUrl:             # Optional agreement URL
Documentations:               # Optional documentation
  - DocumentLabel:            # Optional documentation label
    DocumentUrl:              # Optional documentation URL
ReleaseNotes:                 # Optional release notes
ReleaseNotesUrl:              # Optional release notes URL
PurchaseUrl:                  # Optional purchase URL
InstallationNotes:            # Optional notes displayed upon installation
ManifestType: locale          # The manifest type
ManifestVersion: 1.6.0        # The manifest syntax version
```

## Fields

<details>
 <summary><b>PackageIdentifier</b> - The package unique identifier</summary>

 **Required Field**

 This key is the unique identifier for a given package. This value is generally in the form of `Publisher.Package`. It is case sensitive, and this value must match the folder structure under the partition directory in GitHub.
</details>

<details>
 <summary><b>PackageVersion</b> - The package version</summary>

 **Required Field**

 This key represents the version of the package. It is related to the specific release this manifests targets. In some cases you will see a perfectly formed [semantic version] number, and in other cases you might see something different. These may be date driven, or they might have other characters with some package specific meaning for example.

 The Windows Package Manager client uses this version to determine whether or not an upgrade for a package is available. In some cases, packages may be released with a marketing driven version, and that causes trouble with the `winget upgrade` command.

 The current best practice is to use the value reported in Add / Remove Programs when this version of the package is installed. In some cases, packages do not report a version resulting in an upgrade loop or other unwanted behavior.
</details>

<details>
  <summary><b>PackageLocale</b> - The package meta-data locale</summary>

  **Required Field**

  This key represents the locale for package meta-data. The format is BCP-47. This value identifies the language for meta-data to be displayed to a user when no locale file matching their preferences is available. The Microsoft community package repository validation pipelines also use this value to determine appropriate validation rules for this file.

  **References**

* [Available languages for Windows]
* [Default Input Profiles (Input Locales) in Windows][locales]

  NOTE:	This field is the key to determining which fields are required for the Microsoft community repository. The default locale specified in the version file must match with this value.
 </details>

<details>
  <summary><b>Publisher</b> - The publisher name</summary>

  **Optional Field**

  This key represents the name of the publisher for a given package. This field is intended to allow the full publisher's or ISV's name to be displayed as they wish.

  NOTE:	With the 1.6 release of the Windows Package Manager, this name affects how packages from a source are mapped to Apps installed in Windows 10 and Windows 11 via Add / Remove Programs (ARP). The best practice is to ensure this matches the ARP entry for the package when it has been installed. This should be the value of the `Publisher` subkey for the package in the [Windows registry][uninstall-registry]. The impact is associated with `winget upgrade` and `winget list`.
 </details>

<details>
  <summary><b>PublisherUrl</b> - The publisher home page</summary>

  **Optional Field**

  This key represents the web site for the publisher or ISV.
 </details>

<details>
  <summary><b>PublisherSupportUrl</b> - The publisher support page</summary>

  **Optional Field**

  This key represents the customer support web site or specific web page provided by the publisher or ISV.
 </details>

<details>
  <summary><b>PrivacyUrl</b> - The publisher privacy page or the package privacy page</summary>

  **Optional Field**

  This key represents the privacy web site or specific web page provided the publisher or ISV. If there is a privacy web site or specific web page for the package, it is preferred over a generic privacy page for the publisher.
 </details>

<details>
  <summary><b>Author</b> - The package author</summary>

  **Optional Field**

  This key represents the author of a package. In some cases, the author is an individual who develops and or maintains the package.
 </details>

<details>
  <summary><b>PackageName</b> - The package name</summary>

  **Optional Field**

  This key represents the name of the package. This field is intended to allow the full package name to be displayed as the publisher or ISV wishes.

  NOTE:	With the 1.6 release of the Windows Package Manager, this name affects how packages from a source are mapped to Apps installed in Windows 10 via Add / Remove Programs (ARP). The best practice is to ensure this matches the ARP entry for the package name when it has been installed. This should be the value of the `DisplayName` subkey for the package in the [Windows registry][uninstall-registry]. The impact is associated with `winget upgrade` and `winget list`.
 </details>

<details>
  <summary><b>PackageUrl</b> - The package home page</summary>

  **Optional Field**

  This key represents the web site for the package.
 </details>

<details>
  <summary><b>License</b> - The package license</summary>

  **Optional Field**

  This key represents the license governing the use and or distribution for the product. This could be an open source license, or a commercial license. Please note that a copyright is not considered a license. If there is no available information on a product's license, "Proprietary" should be the value in this field.
 </details>

<details>
  <summary><b>LicenseUrl</b> - The license page</summary>

  **Optional Field**

  This key represents the license web site or specific web page provided the publisher or ISV. If there is a license web site or specific web page for the package, it is preferred over a generic license page for the publisher.

  If this is a link to the license file for an open source project, it should be specific to the version for the package. Some open source projects change their license over time.
 </details>

<details>
  <summary><b>Copyright</b> - The package copyright</summary>

  **Optional Field**

  This key represents the copyright for the package.
 </details>

<details>
  <summary><b>CopyrightUrl</b> - The package copyright page</summary>

  **Optional Field**

  This key represents the copyright web site or specific web page provided the publisher or ISV. If there is a copyright web site or specific web page for the package, it is preferred over a generic copyright page for the publisher.

  If this is a link to the copyright file for an open source project, it should be specific to the version for the package. Some open source projects change their copyright over time.
 </details>

<details>
  <summary><b>ShortDescription</b> - The short package description</summary>

  **Optional Field**

  This key represents the description for a package. It is intended for use in `winget show` to help a user understand what the package is.

  NOTE:	This should be something descriptive about what the package does, and it should not simply state something like "&lt;package name&gt; installer" or "&lt;package name&gt; setup".
 </details>

<details>
  <summary><b>Description</b> - The full package description</summary>

  **Optional Field**

  This key represents the full or long description for a package. It is *not* currently used in the Windows Package Manager.

  NOTE:	This was included for future integration with the Microsoft Store source to provide the ability to display the full package description.
 </details>

<details>
  <summary><b>Tags</b> - List of additional package search terms</summary>

  **Optional Field**

  This key represents other common term users would search for when looking for packages.

  NOTE: The best practice is to present these terms in all lower case with hyphens rather than spaces.
 </details>

 <details>
   <summary><b>Agreements/b> - List of package agreements</summary>

   **Optional Field**

   This key holds any agreements a user must accept prior to download and subsequent install or upgrade.

   IMPORTANT: In the Windows Package Manager Community Repository, these are only allowed to be submitted by verified developers.
  </details>

<details>
  <summary><b>AgreementLabel</b> - The label for a package agreement</summary>

  **Optional Field**

  This key represents the label for a package agreement.
</details>

<details>
  <summary><b>Agreement</b> - The text for a package agreement</summary>

  **Optional Field**

  This key represents the text or body of a package agreement.
</details>

<details>
  <summary><b>AgreementUrl</b> - The URL for a package agreement</summary>

  **Optional Field**

  This key represents the URL for a package agreement.
</details>

<details>
  <summary><b>Documentations</b> - List of documentation</summary>

  **Optional Field**

  This key holds any documentation for providing software guides such as manuals and troubleshooting URLs.
</details>

<details>
  <summary><b>DocumentLabel</b> - The documentation label</summary>

  **Optional Field**

  This key represents the label for a documentation.
</details>

<details>
  <summary><b>DocumentUrl</b> - List of documentation</summary>

  **Optional Field**

  This key represents the URL for a documentation.
</details>

<details>
  <summary><b>ReleaseNotes</b> - The Release Notes for a package.</summary>

  **Optional Field**

  This key represents release notes for a package.
</details>

<details>
  <summary><b>ReleaseNotesUrl</b> - The Release Notes web page for a package.</summary>

  **Optional Field**

  This key represents release notes web page for a package.
</details>

<details>
  <summary><b>PurchaseUrl</b> - The Purchase URL for a package.</summary>

  **Optional Field**

  This key represents the purchase url for acquiring entitlement for a package.
</details>

<details>
  <summary><b>InstallationNotes</b> - The Installation Notes for a package.</summary>

  **Optional Field**

  This key represents the notes displayed to the user upon completion of a package installation.
</details>

<details>
 <summary><b>ManifestType</b> - The manifest type</summary>

 **Required Field**

 This key must have the value "locale". The Microsoft community package repository validation pipelines also use this value to determine appropriate validation rules when evaluating this file.
</details>

<details>
 <summary><b>ManifestVersion</b> - The manifest syntax version</summary>

 **Required Field**

 This key must have the value "1.6.0". The Microsoft community package repository validation pipelines also use this value to determine appropriate validation rules when evaluating this file.
</details>
