[JSON schema]:                              https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.1.0/manifest.singleton.1.1.0.json
[semantic version]:                         https://semver.org
[install]:                                  https://docs.microsoft.com/windows/package-manager/winget/install
[list]:                                     https://docs.microsoft.com/windows/package-manager/winget/list
[upgrade]:                                  https://docs.microsoft.com/windows/package-manager/winget/upgrade
[MSIX]:                                     https://docs.microsoft.com/windows/msix/overview
[MSI]:                                      https://docs.microsoft.com/windows/win32/msi/windows-installer-portal
[Inno]:                                     https://jrsoftware.org/isinfo.php
[Nullsoft]:                                 https://sourceforge.net/projects/nsis
[WiX]:                                      https://wixtoolset.org
[Burn]:                                     https://wixtoolset.org/documentation/manual/v3/bundle
[Windows Package Manager Manifest Creator]: https://github.com/microsoft/winget-create
[App capability declarations]:              https://docs.microsoft.com/windows/uwp/packaging/app-capability-declarations

## Minimal singleton YAML file example
As specified in the singleton [JSON schema], only a number of fields are required. The singleton format is only valid for packages containing a single installer and a single locale. If more than one installer or locale is provided, the multiple YAML file format and schema must be used.

>Note: The singleton manifest format has been deprecated in the Windows Package Manager Community Repository. The Windows Package Manager 1.2 client still supports singleton manifests.

### Singleton Manifest

```YAML
PackageIdentifier:              # The package unique identifier
PackageVersion:                 # The package version
Channel:                        # *Not implemented* distribution channel
PackageLocale:                  # The package meta-data locale
Publisher:                      # The publisher name
PackageName:                    # The package name
License:                        # The package license
ShortDescription:               # The short package description
Description:                    # Optional full package description
Moniker:                        # Optional most common package term
Tags:                           # Optional list of package terms
Agreements:                     # Optional package agreements
  - AgreementLabel:             # Optional agreement label
    Agreement:                  # Optional agreement text
    AgreementUrl:               # Optional agreement URL
ReleaseDate:                    # Optional release date
ReleaseNotes:                   # Optional release notes
ReleaseNotesUrl:                # Optional release notes URL
Installers:                     # The package installer
  - Architecture:               # The architecture of the installer
    InstallerLocale:            # Optional locale of the installer
    Platform:                   # Optional installer supported operating system
    MinimumOSVersion:           # Optional installer minimum operating system version
    InstallerType:              # The installer type
    InstallerUrl:               # The installer URL
    InstallerSha256:            # The SHA256 hash of the installer
    SignatureSha256:            # Optional SHA256 hash of the MSIX signature
    Scope:                      # Optional installer scope
    InstallModes:               # Optional installer modes
    InstallerSwitches:          # Optional installer switches
      Silent:                   # Optional installer switches for silent
      SilentWithProgress:       # Optional installer switches for silent with progress
      Interactive:              # Optional installer switches for interactive
      InstallLocation:          # Optional install location path
      Log:                      # Optional installer log file path
      Upgrade:                  # Optional installer switches for upgrade
      Custom:                   # Optional installer switches for custom behavior
    UpgradeBehavior:            # Optional upgrade method
    Commands:                   # Optional commands or aliases to run the package
    Protocols:                  # Optional list of protocols supported by the package
    FileExtensions:             # Optional list of file extensions supported by the package
    Dependencies:               # *Experimental* list of dependencies required by the package
      - ExternalDependencies:   # *Not implemented* list of external dependencies
        PackageDependencies:    # *Experimental* list of package dependencies
        WindowsFeatures:        # *Not implemented* list of Windows feature dependencies
        WindowsLibraries:       # *Not implemented* list of Windows library dependencies
    PackageFamilyName:          # Optional MSIX package family name
    Capabilities:               # Optional list of MSIX package capabilities
    RestrictedCapabilities:     # Optional list of MSIX package restricted capabilities
    InstallerAbortsTerminal:    # *Not implemented* Optional indicator for packages that abort terminal
    InstallLocationRequired:    # *Not implemented* Optional indicator for packages that require install location
    RequireExplicitUpgrade:     # Optional indicator for packages that upgrade themselves
    ElevationRequirement:       # *Not implemented* scope required to install package
    UnsupportedOSArchitectures: # Optional architectures the package is not supported on
    Markets:                    # Optional markets the package is allowed to be installed
    ExcludedMarkets:            # Optional markets the package is not allowed to be installed
    InstallerSuccessCodes:      # Optional non-zero installer success codes
    ExpectedReturnCodes:        # Optional non-zero installer return codes
      - ExpectedReturnCode:     # Optional non-zero installer return code
        ReturnResponse:         # Optional response for an expected return code
    ProductCode:                # Optional product code of the installer
    AppsAndFeaturesEntries:     # *Not implemented* Optional entries from the Add and Remove Programs (ARP) table
      - DisplayName:            # *Not implemented* Optional program name shown in the ARP entry
        DisplayVersion:         # *Not implemented* Optional version displayed in the ARP entry
        Publisher:              # *Not implemented* Optional publisher displayed in the ARP entry
        ProductCode:            # *Not implemented* Optional product code of the installer
        UpgradeCode:            # *Not implemented* Optional upgrade code of the installer
        InstallerType:          # *Not implemented* Optional installer type
ManifestType: singleton         # The manifest type
ManifestVersion: 1.1.0          # The manifest syntax version
```

### [Singleton Minimal Example](#tab/minimal/)

```YAML
PackageIdentifier: Microsoft.WindowsTerminal
PackageVersion: 1.6.10571.0
PackageLocale: en-US
Publisher: Microsoft
PackageName: Windows Terminal
License: MIT
ShortDescription: The new Windows Terminal, a tabbed command line experience for Windows.
Installers:
 - Architecture: x64
   InstallerType: msix
   InstallerUrl: https://github.com/microsoft/terminal/releases/download/v1.6.10571.0/Microsoft.WindowsTerminal_1.6.10571.0_8wekyb3d8bbwe.msixbundle
   InstallerSha256: 092aa89b1881e058d31b1a8d88f31bb298b5810afbba25c5cb341cfa4904d843
   SignatureSha256: e53f48473621390c8243ada6345826af7c713cf1f4bbbf0d030599d1e4c175ee
ManifestType: singleton
ManifestVersion: 1.1.0
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

 The Windows Package Manager client uses this version to determine if an upgrade for a package is available. In some cases, packages may be released with a marketing driven version, and that causes trouble with the [`winget upgrade`][upgrade] command.

 >Note: The current best practice is to use the value reported in Add / Remove Programs when this version of the package is installed. In some cases, packages do not report a version resulting in an upgrade loop or other unwanted behavior. This practice may seem contrary to using semantic versioning, but it provides the best end to end experience for customers. It will take time for publishers and ISVs to migrate to semantic versioning, and some may intentionally choose to preserve other versioning schemes. In these cases, it is best practice to include the "AppsAndFeaturesEntries" section for each installer.
</details>

<details>
 <summary><b>Channel</b> - The distribution channel</summary>

 **Optional Field**

 This key represents the distribution channel for a package. Examples may include "stable" or "beta".

 >Note: This key is included for future use. The Windows Package Manager currently does not have any behavior associated with this key. The intent behind this key is to help disambiguate the different channels for packages lacking support for side by side installation. Some packages support having more than one package channel available on a system simultaneously; in this case it is better to use unique packages rather than channels. This key is intended to ensure the proper channel for a package is used during install and upgrade scenarios.
 </details>

<details>
  <summary><b>Description</b> - The full package description</summary>

  **Optional Field**

  This key represents the full or long description for a package. It is *not* currently used in the Windows Package Manager.

  >Note: This was included for future integration with the Microsoft Store source to provide the ability to display the full package description.
 </details>

<details>
  <summary><b>Moniker</b> - The most common package term</summary>

  **Optional Field**

  This key represents the most common term users would search for when installing or upgrading a package. If only one package uses this moniker, then the [install], [list] and [upgrade] command may match with this package.

  >Note:Moniker is the third property evaluated when searching for a matching package.
</details>

<details>
  <summary><b>Tags</b> - List of additional package search terms</summary>

  **Optional Field**

  This key represents other common term users would search for when looking for packages.

  >Note: The best practice is to present these terms in all lower case with hyphens rather than spaces.
 </details>

 <details>
   <summary><b>Agreements</b> - List of package agreements</summary>

   **Optional Field**

   This key holds any agreements a user must accept prior to download and subsequent install or upgrade.

   >Note: In the Windows Package Manager Community Repository, these are only allowed to be submitted by verified developers.
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
  <summary><b>ReleaseDate</b> - The Release Date for a package.</summary>

  **Optional Field**

  This key represents the release date for a package.
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
 <summary><b>Installers</b> - Package installer</summary>

 **Required Field**

 The key represents an installer for a package.

 >Note: Many of the keys related to installers may either be at the root level of the manifest, or included in an installer. Any values provided at the root level and not specified in an installer will be inherited.
</details>

<details>
 <summary><b>Architecture</b> - The installer target architecture</summary>

 **Required Field**

 This key represents the hardware architecture targeted by the installer. The Windows Package Manager will attempt to determine the best architecture to use. If emulation is available and the native hardware architecture does not have a supported installer, the emulated architecture may be used.
 </details>

<details>
 <summary><b>InstallerLocale</b> - Locale for package installer</summary>

 **Optional Field**

 This key represents the locale for an installer *not* the package meta-data. Some installers are compiled with locale or language specific properties. If this key is present, it is used to represent the package locale for an installer.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.

</details>

<details>
 <summary><b>Platform</b> - The installer supported operating system</summary>

 **Optional Field**

 This key represents the Windows platform targeted by the installer. The Windows Package Manager currently supports "Windows.Desktop" and "Windows.Universal". The Windows Package Manager client currently has no behavior associated with this property. It was added for future looking scenarios.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>MinimumOSVersion</b> - The installer minimum operating system version</summary>

 **Optional Field**

 This key represents the minimum version of the Windows operating system supported by the package.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>InstallerType</b> - Enumeration of supported installer types.</summary>

 **Required Field**

 This key represents the installer type for the package. The Windows Package Manager supports [MSIX], [MSI], and executable installers. Some well known formats ([Inno], [Nullsoft], [WiX], and [Burn]) provide standard sets of installer switches to provide different installer experiences.

 >Note: The Windows Package Manager defaults to the install mode providing install progress. A best practice is to determine if one of the supported installer technologies was used to build an installer with the .exe file extension. The [Windows Package Manager Manifest Creator] tool can be used to determine if one of the known tools was used to build an installer with the .exe file extension.

 >Note: The Windows Package Manager does not support loose executables with the .exe or .com file extension directly. Compressed files containing installers,  loose executables, and Progressive Web Applications (PWAs) are also not supported.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>InstallerUrl</b> - The installer Url</summary>

 **Required Field**

 This key represents the URL to download the installer.
</details>

<details>
 <summary><b>InstallerSha256</b> - Sha256 is required. Sha256 of the installer</summary>

 **Required Field**

 This key represents the SHA 256 hash for the installer. It is used to confirm the installer has not been modified. The Windows Package Manager will compare the hash in the manifest with the calculated hash of the installer after it has been downloaded.

 >Note:  The [Windows Package Manager Manifest Creator] can be used to determine the SHA 256 of the installer. The `winget hash &lt;pathToInstaller&gt;` command can also be used to determine the SHA 256 of the installer.
</details>

<details>
 <summary><b>SignatureSha256</b> - SignatureSha256 is recommended for appx or msix. It is the sha256 of the signature file inside the appx or msix. Could be used during streaming install if applicable.</summary>

 **Optional Field**

 This key represents the signature file (AppxSignature.p7x) inside an MSIX installer. It is used to provide streaming install for MSIX packages.

 >Note: MSIX installers must be signed to be included in the Microsoft community package repository. If the installer is an MSIX this signature should be included in the manifest. The [Windows Package Manager Manifest Creator] can be used to determine the signature SHA 256. The `winget hash <pathToInstaller> --msix` command can also be used to determine the signature SHA 256.
</details>

<details>
 <summary><b>Scope</b> - Scope indicates if the installer is per user or per machine</summary>

 **Optional Field**

 This key represents the scope the package is installed under. The two configurations are "user" and "machine". Some installers support only one of these scopes while others support both via arguments passed to the installer using "InstallerSwitches".

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>InstallModes</b> - List of supported installer modes</summary>

 **Optional Field**

 This key represents the install modes supported by the installer. The Microsoft community package repository requires a package support "silent" and "silent with progress". The Windows Package Manager also supports "interactive" installers. The Windows Package Manager client does not have any behavior associated with this key.

 >Note: Some installers will attempt to install missing dependencies. If these dependencies require user interaction, the package will not be allowed into the Microsoft community package repository.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>InstallerSwitches</b> - Switches passed to installers</summary>

 **Optional Field**

 This key represents the set of switches passed to installers.

 >Note: The Microsoft community repository currently requires support for silent and silent with progress installation. Many custom .exe installers will require the proper switches to meet this requirement. The [Windows Package Manager Manifest Creator] tool can be used to determine if one of the known tools was used to build an installer with the .exe file extension. In the event the tool is unable to determine the tool used to build the installer, the publisher may have documentation for the proper switches.
</details>

<details>
 <summary><b>Silent</b> - Silent is the value that should be passed to the installer when user chooses a silent or quiet install</summary>

 **Optional Field**

 This key represents switches passed to the installer to provide a silent install experience. These would be used when the command `winget install <package> --silent` is executed.

 >Note: When the Windows Package Manager installs a package using the "silent" install mode, any custom switches will also be passed to the installer. If a user applies override switches via command line via the Windows Package Manager, none of the switches from the manifest will be passed to the installer.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>SilentWithProgress</b> - SilentWithProgress is the value that should be passed to the installer when user chooses a non-interactive install</summary>

 **Optional Field**

 This key represents switches passed to the installer to provide a silent with progress install experience. This is intended to allow a progress indication to the user, and the indication may come from an installer UI dialogue, but it must not require user interaction to complete. The Windows Package Manager currently defaults to this install experience.

 >Note: When the Windows Package Manager installs a package using the "silent with progress" install mode, any custom switches will also be passed to the installer. If a user applies override switches via command line via the Windows Package Manager, none of the switches from the manifest will be passed to the installer.
</details>

<details>
 <summary><b>Interactive</b> - Interactive is the value that should be passed to the installer when user chooses an interactive install</summary>

 **Optional Field**

 This key represents switches passed to the installer to provide an interactive install experience. This is intended to allow a user to interact with the installer. These would be used when the command `winget install <package> --interactive` is executed.

 >Note: When the Windows Package Manager installs a package using the "interactive" install mode, any custom switches will also be passed to the installer. If a user applies override switches via command line via the Windows Package Manager, none of the switches from the manifest will be passed to the installer.
</details>

<details>
 <summary><b>InstallLocation</b> - InstallLocation is the value passed to the installer for custom install location. </summary>

 **Optional Field**

 This key represents the path to install the package if the installer supports installing the package in a user configurable location. The **&lt;INSTALLPATH&gt;** token can be included in the switch value so the Windows Package Manager will replace the token with the user provided path.
</details>

<details>
 <summary><b>Log</b> - Log is the value passed to the installer for custom log file path.</summary>

 **Optional Field**

  This key represents the path logs will be directed to if the installer supports specifying the log path in a user configurable location. The **&lt;LOGPATH&gt;** token can be included in the switch value so the Windows Package Manager will replace the token with the user provided path.
</details>

<details>
 <summary><b>Upgrade</b> - Upgrade is the value that should be passed to the installer when user chooses an upgrade.</summary>

 **Optional Field**

 This key represents the switches to be passed to the installer during an upgrade. This will happen only if the upgrade behavior is "install".

 >Note: If a user applies override switches via command line via the Windows Package Manager, none of the switches from the manifest will be passed to the installer.
</details>

<details>
 <summary><b>Custom</b> - Custom switches will be passed directly to the installer by the Windows Package Manager.</summary>

 **Optional Field**

 This key represents any switches the Windows Package Manager will pass to the installer in addition to "Silent", "SilentWithProgress", and "Interactive".

 >Note: If a user applies override switches via command line via the Windows Package Manager, none of the switches from the manifest will be passed to the installer.
</details>

<details>
 <summary><b>UpgradeBehavior</b> - The upgrade method</summary>

 **Optional Field**

 This key represents what the Windows Package Manager should do regarding the currently installed package during a package upgrade. If the package should be uninstalled first, the "uninstallPrevious" value should be specified.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>Commands</b> - List of commands or aliases to run the package</summary>

 **Optional Field**

 This key represents any commands or aliases used to execute the package after it has been installed.

 >Note: The Windows Package Manager does not update the path during the install workflow. In those cases, the user may need to restart their shell or terminal before the command will execute the newly installed package. The Windows Package Manager does not support any behavior related to commands or aliases.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>Protocols</b> - List of protocols the package provides a handler for</summary>

 **Optional Field**

 This key represents any protocols supported by the package. The Windows Package Manager does not support any behavior related to protocols handled by a package.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>FileExtensions</b> - List of file extensions the package could support</summary>

 **Optional Field**

 This key represents any file extensions supported by the package. The Windows Package Manager does not support any behavior related to the file extensions supported by the package.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>Dependencies</b> - List of dependencies needed to install or execute the package</summary>

 **Optional Field**

 This key represents any dependencies required to install or run the package.

 >Note: The Windows Package Manager does not support any behavior related to dependencies.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>ExternalDependencies</b> - List of external package dependencies</summary>

 **Optional Field**

 This key represents any external dependencies required to install or run the package.

 >Note: The Windows Package Manager does not support any behavior related to dependencies.
</details>

<details>
 <summary><b>PackageDependencies</b> - List of package dependencies from current source</summary>

 **Optional Field**

 This key represents any packages from the same source required to install or run the package.

 >Note: The Windows Package Manager does not support any behavior related to dependencies.
</details>

<details>
 <summary><b>WindowsFeatures</b> - List of Windows feature dependencies</summary>

 **Optional Field**

 This key represents any Windows features required to install or run the package.

 >Note: The Windows Package Manager does not support any behavior related to dependencies.
</details>

<details>
 <summary><b>WindowsLibraries</b> - List of Windows library dependencies</summary>

 **Optional Field**

 This key represents any Windows libraries required to install or run the package.

 >Note: The Windows Package Manager does not support any behavior related to dependencies.
</details>

<details>
 <summary><b>PackageFamilyName</b> - PackageFamilyName for appx or msix installer. Could be used for correlation of packages across sources</summary>

 **Optional Field**

 This key represents the package family name specified in an MSIX installer. This value is used to assist with matching packages from a source to the program installed in Windows via Add / Remove Programs for list, and upgrade behavior.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>Capabilities</b> - List of appx or msix installer capabilities</summary>

 **Optional Field**

 This key represents the capabilities provided by an MSIX package. More information is available for [App capability declarations]

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>RestrictedCapabilities</b> - List of appx or msix installer restricted capabilities</summary>

 **Optional Field**

 This key represents the restricted capabilities provided by an MSIX package.More information is available for [App capability declarations]

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>InstallerAbortsTerminal</b> - Indicator for installers that abort the terminal.</summary>

 **Optional Field**

 This key represents the behavior associated with installers that abort the terminal. This most often occurs when a user is performing an upgrade of the running terminal.

 >Note: Windows Terminal no longer causes this to occur as the MSIX install behavior from the Windows Package Manager is deferred registration.
</details>

<details>
 <summary><b>InstallLocationRequired</b> - Indicator for packages requiring an install location to be specified.</summary>

 **Optional Field**

 This key represents the requirement to have an install location specified. These installers are known to deploy files to the location the installer is executed in.

 >Note: The behavior associated with this key is not implemented in the Windows Package Manager 1.2 client.
</details>

<details>
  <summary><b>RequireExplicitUpgrade</b> - Indicator for packages that upgrade themselves.</summary>

  **Optional Field**

  This key identifies packages that upgrade themselves. By default, they are excluded from `winget upgrade --all`.
</details>

<details>
  <summary><b>ElevationRequirement</b> - Indicator for elevation requirements when installing or upgrading packages.</summary>

  **Optional Field**

  This key represents which scope a package is required to be executed under. Some packages require user level execution while others require administrative level execution.

 >Note: The behavior associated with this key is not implemented in the Windows Package Manager 1.2 client.
</details>

<details>
  <summary><b>UnsupportedOSArchitectures</b> - List of unsupported architectures for a package.</summary>

  **Optional Field**

  This key represents any architectures a package is known not to be compatible with. Generally, this is associated with emulation modes.
</details>

<details>
  <summary><b>Markets</b> - List of supported markets for a package.</summary>

  **Optional Field**

  This key represents any markets a package may be installed in.

  >Note: If a market is listed in both this key and the ExcludedMarkets key, the market will be excluded. Both keys are present to reduce the need to list the larger set of markets.
</details>

<details>
  <summary><b>ExcludedMarkets</b> - List of unsupported markets for a package.</summary>

  **Optional Field**

  This key represents any markets a package may not be installed in.

  >Note: If a market is listed in both this key and the Markets key, the market will be excluded. Both keys are present to reduce the need to list the larger set of markets.
</details>

<details>
 <summary><b>InstallerSuccessCodes</b> - List of additional non-zero installer success exit codes other than known default values by the Windows Package Manager.</summary>

 **Optional Field**

 This key represents any status codes returned by the installer representing a success condition other than zero.

 >Note: Some return codes indicate a reboot is suggested or required. The Windows Package Manager does not support the reboot behavior currently. Some installers will force a reboot, and the Windows Package Manager does not currently suppress reboot behavior.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>ExpectedReturnCodes</b> - List of additional non-zero installer exit codes other than known default values by the Windows Package Manager.</summary>

 **Optional Field**

 This key represents any status codes returned by the installer representing a condition other than zero.

 >Note: Some return codes indicate a reboot is suggested or required. The Windows Package Manager does not support the reboot behavior currently. Some installers will force a reboot, and the Windows Package Manager does not currently suppress reboot behavior.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>ExpectedReturnCode</b> - The non-zero installer exit code other than known default values by the Windows Package Manager.</summary>

 **Optional Field**

 This key represents any status code returned by the installer representing a condition other than zero. MSIX and MSI packages have well known return codes. This is primarily intended for executable installers that have custom or unique return coes that can be mapped to a return response.
</details>

<details>
 <summary><b>ReturnResponse</b> - The return response to be displayed in the event an expected return code is encountered.</summary>

 **Optional Field**

 This key represents a return response to display when an installer returns an expected return code. MSIX and MSI packages have well known return codes. This is primarily intended for executable installers that have custom or unique return coes that can be mapped to a return response.

 >Note: An enumerated list of values in the JSON schema must be specified for consistency of user experience.
</details>

<details>
 <summary><b>ProductCode</b> - ProductCode is used for correlation of packages with manifests in configured sources.</summary>

 **Optional Field**

 This key represents the product code specified in an MSI installer. This value is used to assist with matching packages from a source to the program installed in Windows via Add / Remove Programs for list, and upgrade behavior.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>AppsAndFeaturesEntries</b> - AppsAndFeaturesEntries are used to match installed packages with manifests in configured sources.</summary>

 **Optional Field**

  This key represents the values reported by Windows Apps & Features. When a package is installed, entries are made into the Windows Registry.

  >Note: The AppsAndFeatures behavior is not implemented in the Windows Package Manager 1.2 client.
</details>

<details>
 <summary><b>DisplayName</b> - DisplayName is what is displayed in the Control Panel for installed packages.</summary>

 **Optional Field**

 This key represents the package name as displayed in Windows Apps & Features. It is used to help correlate installed packages with manifests in configured sources.

 >Note: The AppsAndFeatures behavior is not implemented in the Windows Package Manager 1.2 client.
</details>

<details>
 <summary><b>DisplayVersion</b> - DisplayVersion is the version displayed in the Control Panel for installed packages.</summary>

 **Optional Field**

 This key represents the package version as displayed in Windows Apps & Features. It is used to help correlate installed packages with manifests in configured sources.

 >Note: The AppsAndFeatures behavior is not implemented in the Windows Package Manager 1.2 client.
</details>

<details>
 <summary><b>Publisher</b> - Publisher is the value of the package publisher reported in the Windows registry.</summary>

 **Optional Field**

 This key represents the Publisher reported in the Windows registry. It is used to help correlate installed packages with manifests in configured sources.

 >Note: The AppsAndFeatures behavior is not implemented in the Windows Package Manager 1.2 client.
</details>

<details>
 <summary><b>ProductCode</b> - ProductCode is used for correlation of packages with manifests in configured sources.</summary>

 **Optional Field**

 This key represents the product code for a package. It is used to help correlate installed packages with manifests in configured sources.

 >Note: This key is displayed twice for completeness. As the AppsAndFeatures behavior is not implemented in the Windows Package Manager 1.2 client, the description and usage above is implemented.
</details>

<details>
 <summary><b>UpgradeCode</b> - UpgradeCode is used for correlation of packages with manifests in configured sources.</summary>

 **Optional Field**

 This key represents the upgrade code for a package. It is used to help correlate installed packages with manifests in configured sources.

 >Note: The AppsAndFeatures behavior is not implemented in the Windows Package Manager 1.2 client.
</details>

<details>
 <summary><b>InstallerType</b> - Enumeration of supported installer types.</summary>

 **Optional Field**

 This key represents the installer type for the package. It is used to help correlate installed packages with manifests in configured sources. In some cases, an installer is an .exe based installer, but contains an MSI installer. This key will help the Windows Package Manager understand if upgrading an MSI should be performed when it is contained in an .exe installer.

 >Note: This key is displayed twice for completeness. As the AppsAndFeatures behavior is not implemented in the Windows Package Manager 1.2 client, the description and usage above is implemented.
</details>

<details>
 <summary><b>ManifestType</b> - The manifest type</summary>

 **Required Field**

 This key must have the value "installer". The Microsoft community package repository validation pipelines also use this value to determine appropriate validation rules when evaluating this file.
</details>

<details>
 <summary><b>ManifestVersion</b> - The manifest syntax version</summary>

 **Required Field**

 This key must have the value "1.1.0". The Microsoft community package repository validation pipelines also use this value to determine appropriate validation rules when evaluating this file.
</details>
