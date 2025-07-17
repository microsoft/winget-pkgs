[JSON Schema]:                              https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.6.0/manifest.installer.1.6.0.json
[Windows Package Manager Manifest Creator]: https://github.com/microsoft/winget-create
[YAML]:                                     https://yaml.org/spec
[semantic version]:                         https://semver.org
[`winget upgrade`]:                         https://docs.microsoft.com/windows/package-manager/winget/upgrade
[App capability declarations]:              https://docs.microsoft.com/windows/uwp/packaging/app-capability-declarations
[package family name]:                      https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/package-identity-overview#package-family-name
[product code]:                             https://learn.microsoft.com/en-us/windows/win32/msi/product-codes
[upgrade code]:                             https://learn.microsoft.com/en-us/windows/win32/msi/using-an-upgradecode
[uninstall-registry]:                       https://learn.microsoft.com/en-us/windows/win32/msi/uninstall-registry-key
[MSIX]:                                     https://docs.microsoft.com/windows/msix/overview
[MSI]:                                      https://docs.microsoft.com/windows/win32/msi/windows-installer-portal
[Inno]:                                     https://jrsoftware.org/isinfo.php
[Nullsoft]:                                 https://sourceforge.net/projects/nsis
[WiX]:                                      https://wixtoolset.org
[Burn]:                                     https://wixtoolset.org/docs/v3/bundle/

# Windows Package Manager
## Manifest Schema v1.6.0 Installer File
All Windows Package Manager manifests in the Microsoft community repository are submitted using [YAML] syntax. A [JSON schema] is provided to aid authoring these files in editors, and in the other tooling related to the Windows Package Manager. This document provides detailed information regarding the usage of the YAML keys in the installer file for multi-file manifests.

> [!IMPORTANT]
 The 1.6 manifest schema was released with the Windows Package Manager 1.6. Any fields marked *Not implemented* are not supported in the 1.6 client, but may be supported in a 1.7-preview client.

### Installer Manifest

```YAML
PackageIdentifier:                 # The package unique identifier
PackageVersion:                    # The package version
Channel:                           # *Not implemented* distribution channel
Installers:                        # The list of package installers
  - Architecture:                  # The architecture of the installer
    InstallerLocale:               # Optional locale of the installer
    Platform:                      # Optional installer supported operating system
    MinimumOSVersion:              # Optional installer minimum operating system version
    InstallerType:                 # The installer type
    InstallerUrl:                  # The installer URL
    InstallerSha256:               # The SHA256 hash of the installer
    SignatureSha256:               # Optional SHA256 hash of the MSIX signature
    NestedInstallerType:           # The installer type when InstallerType is an archive type
    NestedInstallerFiles:          # Details about the installers when InstallerType is an archive type
      - RelativeFilePath:          # The relative path to the nested installer file
        PortableCommandAlias:      # Optional command alias to be used for calling the package. Only applies when NestedInstallerType is 'portable'
    Scope:                         # Optional installer scope
    InstallModes:                  # Optional installer modes
    InstallerSwitches:             # Optional installer switches
      Silent:                      # Optional installer switches for silent
      SilentWithProgress:          # Optional installer switches for silent with progress
      Interactive:                 # Optional installer switches for interactive
      InstallLocation:             # Optional install location path
      Log:                         # Optional installer log file path
      Upgrade:                     # Optional installer switches for upgrade
      Custom:                      # Optional installer switches for custom behavior
    UpgradeBehavior:               # Optional upgrade method
    Commands:                      # Optional commands or aliases to run the package
    Protocols:                     # Optional list of protocols supported by the package
    FileExtensions:                # Optional list of file extensions supported by the package
    Dependencies:                  # Optional list of dependencies required by the package
      - ExternalDependencies:      # *Not implemented* list of external dependencies
        PackageDependencies:       # Optional list of package dependencies
        WindowsFeatures:           # Optional list of Windows feature dependencies
        WindowsLibraries:          # *Not implemented* list of Windows library dependencies
    PackageFamilyName:             # Optional MSIX package family name
    Capabilities:                  # Optional list of MSIX package capabilities
    RestrictedCapabilities:        # Optional list of MSIX package restricted capabilities
    InstallerAbortsTerminal:       # Optional indicator for packages that abort terminal
    InstallLocationRequired:       # Optional indicator for packages that require install location
    RequireExplicitUpgrade:        # Optional indicator for packages that upgrade themselves
    ElevationRequirement:          # Optional scope required to install package
    UnsupportedOSArchitectures:    # Optional architectures the package is not supported on
    Markets:                       # Optional markets the package is allowed to be installed
    ExcludedMarkets:               # Optional markets the package is not allowed to be installed
    InstallerSuccessCodes:         # Optional non-zero installer success codes
    ExpectedReturnCodes:           # Optional non-zero installer return codes
      - InstallerReturnCode:       # Optional non-zero installer return code
        ReturnResponse:            # Optional response for an expected return code
        ReturnResponseUrl:         # Optional response URL for an expected return code
    ProductCode:                   # Optional product code of the installer
    AppsAndFeaturesEntries:        # Optional entries from the Add and Remove Programs (ARP) table
      - DisplayName:               # Optional program name shown in the ARP entry
        DisplayVersion:            # Optional version displayed in the ARP entry
        Publisher:                 # Optional publisher displayed in the ARP entry
        ProductCode:               # Optional product code of the installer
        UpgradeCode:               # Optional upgrade code of the installer
        InstallerType:             # Optional installer type
    UnsupportedArguments:          # Optional list of Windows Package Manager Client arguments the installer does not support
      - UnsupportedArgument:       # Optional unsupported Windows Package Manager Client argument
    DisplayInstallWarnings:        # *Not implemented* Optional indicator for packages that are known to interfere with running application during install
    ReleaseDate:                   # Optional release date
    InstallationMetadata:          # Optional metadata for deeper installation detection
      - DefaultInstallLocation:    # Optional default install location for the package
        Files:                     # Optional list of files installed by the package
          - RelativeFilePath:      # Optional relative path to the installed file
            FileSha256:            # Optional Sha256 of the installed file
            FileType:              # Optional installed file type. Treated as 'other' if not specified
            InvocationParameter:   # Optional parameter for invocable files
            DisplayName:           # Optional display name for invocable files
    DownloadCommandProhibited:     # Optional indicator for packages which cannot be downloaded for offline installation
ManifestType: installer            # The manifest type
ManifestVersion: 1.6.0             # The manifest syntax version
```

### Installer Minimal Example

Path: manifests/m/Microsoft/WindowsTerminal/1.9.1942/Microsoft.WindowsTerminal.installer.yaml

```YAML
PackageIdentifier: Microsoft.WindowsTerminal
PackageVersion: 1.9.1942.0
Installers:
  - Architecture: x64
    InstallerType: msix
    InstallerUrl: https://github.com/microsoft/terminal/releases/download/v1.9.1942.0/Microsoft.WindowsTerminal_1.9.1942.0_8wekyb3d8bbwe.msixbundle
    InstallerSha256: 578D987D58B3CE5F6BF3316C6A5AECE8EB6B94DBCD1963413D81CB313D6C28D5
ManifestType: installer
ManifestVersion: 1.6.0
```

### Installer Complex Example

Path: manifests/m/Microsoft/WindowsTerminal/1.9.1942/Microsoft.WindowsTerminal.installer.yaml

```YAML
PackageIdentifier: Microsoft.WindowsTerminal
PackageVersion: 1.9.1942.0
Platform:
- Windows.Desktop
MinimumOSVersion: 10.0.18362.0
InstallerType: msix
InstallModes:
- silent
PackageFamilyName: Microsoft.WindowsTerminal_8wekyb3d8bbwe
Installers:
- Architecture: x64
  InstallerUrl: https://github.com/microsoft/terminal/releases/download/v1.9.1942.0/Microsoft.WindowsTerminal_1.9.1942.0_8wekyb3d8bbwe.msixbundle
  InstallerSha256: 578D987D58B3CE5F6BF3316C6A5AECE8EB6B94DBCD1963413D81CB313D6C28D5
  SignatureSha256: 889A0BA756E74386F95A37F6A813C6D383DC21349A2D18E2B192D4E0E7F80659
- Architecture: arm64
  InstallerUrl: https://github.com/microsoft/terminal/releases/download/v1.9.1942.0/Microsoft.WindowsTerminal_1.9.1942.0_8wekyb3d8bbwe.msixbundle
  InstallerSha256: 578D987D58B3CE5F6BF3316C6A5AECE8EB6B94DBCD1963413D81CB313D6C28D5
  SignatureSha256: 889A0BA756E74386F95A37F6A813C6D383DC21349A2D18E2B192D4E0E7F80659
- Architecture: x86
  InstallerUrl: https://github.com/microsoft/terminal/releases/download/v1.9.1942.0/Microsoft.WindowsTerminal_1.9.1942.0_8wekyb3d8bbwe.msixbundle
  InstallerSha256: 578D987D58B3CE5F6BF3316C6A5AECE8EB6B94DBCD1963413D81CB313D6C28D5
  SignatureSha256: 889A0BA756E74386F95A37F6A813C6D383DC21349A2D18E2B192D4E0E7F80659
ManifestType: installer
ManifestVersion: 1.6.0
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

 The Windows Package Manager client uses this version to determine if an upgrade for a package is available. In some cases, packages may be released with a marketing driven version, and that causes trouble with the [`winget upgrade`] command.

 NOTE: The current best practice is to use the value reported in Add / Remove Programs when this version of the package is installed. In some cases, packages do not report a version resulting in an upgrade loop or other unwanted behavior. This practice may seem contrary to using semantic versioning, but it provides the best end to end experience for customers. It will take time for publishers and ISVs to migrate to semantic versioning, and some may intentionally choose to preserve other versioning schemes. In these cases, it is best practice to include the "AppsAndFeaturesEntries" section for each installer.
</details>

<details>
 <summary><b>Channel</b> - The distribution channel</summary>

 **Optional Field**

 This key represents the distribution channel for a package. Examples may include "stable" or "beta".

 NOTE: This key is included for future use. The Windows Package Manager currently does not have any behavior associated with this key. The intent behind this key is to help disambiguate the different channels for packages lacking support for side by side installation. Some packages support having more than one package channel available on a system simultaneously; in this case it is better to use unique packages rather than channels. This key is intended to ensure the proper channel for a package is used during install and upgrade scenarios.
</details>

<details>
 <summary><b>Installers</b> - Package installer</summary>

 **Required Field**

 The key represents an installer for a package.

 IMPORTANT: Many of the keys related to installers may either be at the root level of the manifest, or included in an installer. Any values provided at the root level and not specified in an installer will be inherited.
</details>

<details>
 <summary><b>Architecture</b> - The installer target architecture</summary>

 **Required Field**

 This key represents the hardware architecture targeted by the installer. The Windows Package Manager will attempt to determine the best architecture to use. If emulation is available and the native hardware architecture does not have a supported installer, the emulated architecture may be used.

 Available architectures:
 * x86
 * x64
 * arm
 * arm64
 * neutral

</details>

<details>
 <summary><b>InstallerLocale</b> - Locale for package installer</summary>

 **Optional Field**

 This key represents the locale for an installer *not* the package meta-data. Some installers are compiled with locale or language specific properties. If this key is present, it is used to represent the package locale for an installer.

 NOTE: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>Platform</b> - The installer supported operating system</summary>

 **Optional Field**

 This key represents the Windows platform targeted by the installer. The Windows Package Manager currently supports "Windows.Desktop" and "Windows.Universal". The Windows Package Manager client currently has no behavior associated with this property. It was added for future looking scenarios.

 NOTE: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>MinimumOSVersion</b> - The installer minimum operating system version</summary>

 **Optional Field**

 This key represents the minimum version of the Windows operating system supported by the package.

 NOTE: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>InstallerType</b> - Enumeration of supported installer types.</summary>

 **Required Field**

 This key represents the installer type for the package. The Windows Package Manager supports [MSIX], [MSI], and executable installers. Some well known formats ([Inno], [Nullsoft], [WiX], and [Burn]) provide standard sets of installer switches to provide different installer experiences. Portable packages are supported as of Windows Package Manager 1.3. Zip packages are supported as of Windows Package Manager 1.5.

 IMPORTANT: The Windows Package Manager 1.6 does not support loose executables with the .com file extension directly. Progressive Web Applications (PWAs) and fonts are also not supported.

 NOTE: The Windows Package Manager defaults to the install mode providing install progress. A best practice is to determine if one of the supported installer technologies was used to build an installer with the .exe file extension. The [Windows Package Manager Manifest Creator] tool can be used to determine if one of the known tools was used to build an installer with the .exe file extension.

 NOTE: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
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

 NOTE: The [Windows Package Manager Manifest Creator] can be used to determine the SHA 256 of the installer. The `winget hash &lt;pathToInstaller&gt;` command can also be used to determine the SHA 256 of the installer.
</details>

<details>
 <summary><b>SignatureSha256</b> - SignatureSha256 is recommended for appx or msix. It is the sha256 of signature file inside appx or msix. Could be used during streaming install if applicable</summary>

 **Optional Field**

 This key represents the signature file (AppxSignature.p7x) inside an MSIX installer. It is used to provide streaming install for MSIX packages.

 IMPORTANT: MSIX installers must be signed to be included in the Microsoft community package repository. If the installer is an MSIX this signature should be included in the manifest. The [Windows Package Manager Manifest Creator] can be used to determine the signature SHA 256. The `winget hash <pathToInstaller> --msix` command can also be used to determine the signature SHA 256.
</details>

<details>
 <summary><b>NestedInstallerType</b> - NestedInstallerType is required when InstallerType is an archive type such as '.zip'</summary>

 **Required Field**

 This key represents the installer type of the file within the archive which will be used as the installer.
</details>

<details>
 <summary><b>NestedInstallerFiles</b> - NestedInstallerFiles is required when InstallerType is an archive type such as '.zip'</summary>

 **Required Field**

 This key is a list of all the installers to be executed within an archive.

 IMPORTANT: This field can only contain one nested installer file unless the NestedInstallerType is 'portable'
</details>

<details>
 <summary><b>RelativeFilePath</b> - RelativeFilePath is required within NestedInstallerFiles</summary>

 **Required Field**

 The relative path to the installer file contained within the archive.
</details>

<details>
 <summary><b>PortableCommandAlias</b> - The command alias to be used for calling the package</summary>

 **Optional Field**

 The alias which is added to the PATH for calling the package from the command line.

 IMPORTANT: This field is only valid when NestedInstallerType is 'portable'
</details>

<details>
 <summary><b>Scope</b> - Scope indicates if the installer is per user or per machine</summary>

 **Optional Field**

 This key represents the scope the package is installed under. The two configurations are "user" and "machine". Some installers support only one of these scopes while others support both via arguments passed to the installer using "InstallerSwitches".

 NOTE: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>InstallModes</b> - List of supported installer modes</summary>

 **Optional Field**

 This key represents the install modes supported by the installer. The Microsoft community package repository requires a package support "silent" and "silent with progress". The Windows Package Manager also supports "interactive" installers. The Windows Package Manager client does not have any behavior associated with this key.

 IMPORTANT: Some installers will attempt to install missing dependencies. If these dependencies require user interaction, the package will not be allowed into the Microsoft community package repository.

 NOTE: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
  <summary><b>InstallerSwitches</b> - Switches passed to installers</summary>

  **Optional Field**

  This key represents the set of switches passed to installers.

   **Windows Package Manager Community Repository**

   The Microsoft community repository currently requires support for silent and silent with progress installation. Many custom .exe installers will require the proper switches to meet this requirement. The [Windows Package Manager Manifest Creator] tool can be used to determine if one of the known tools was used to build an installer with the .exe file extension. In the event the tool is unable to determine the tool used to build the installer, the publisher may have documentation for the proper switches.
</details>

<details>
 <summary><b>Silent</b> - Silent is the value that should be passed to the installer when user chooses a silent or quiet install</summary>

 **Optional Field**

 This key represents switches passed to the installer to provide a silent install experience. These would be used when the command `winget install <package> --silent` is executed.

 NOTE: When the Windows Package Manager installs a package using the "silent" install mode, any custom switches will also be passed to the installer. If a user applies override switches via command line via the Windows Package Manager, none of the switches from the manifest will be passed to the installer.

 NOTE: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>SilentWithProgress</b> - SilentWithProgress is the value that should be passed to the installer when user chooses a non-interactive install</summary>

 **Optional Field**

 This key represents switches passed to the installer to provide a silent with progress install experience. This is intended to allow a progress indication to the user, and the indication may come from an installer UI dialogue, but it must not require user interaction to complete. The Windows Package Manager currently defaults to this install experience.

 NOTE: When the Windows Package Manager installs a package using the "silent with progress" install mode, any custom switches will also be passed to the installer. If a user applies override switches via command line via the Windows Package Manager, none of the switches from the manifest will be passed to the installer.
</details>

<details>
 <summary><b>Interactive</b> - Interactive is the value that should be passed to the installer when user chooses an interactive install</summary>

 **Optional Field**

 This key represents switches passed to the installer to provide an interactive install experience. This is intended to allow a user to interact with the installer. These would be used when the command `winget install <package> --interactive` is executed.

 NOTE: When the Windows Package Manager installs a package using the "interactive" install mode, any custom switches will also be passed to the installer. If a user applies override switches via command line via the Windows Package Manager, none of the switches from the manifest will be passed to the installer.
</details>

<details>
 <summary><b>InstallLocation</b> - InstallLocation is the value passed to the installer for custom install location. </summary>

 **Optional Field**

 This key represents the path to install the package if the installer supports installing the package in a user configurable location. The **&lt;INSTALLPATH&gt;** token can be included in the switch value so the Windows Package Manager will replace the token with user provided path.
</details>

<details>
 <summary><b>Log</b> - Log is the value passed to the installer for custom log file path.</summary>

 **Optional Field**

  This key represents the path logs will be directed to if the installer supports specifying the log path in a user configurable location. The **&lt;LOGPATH&gt;** token can be included in the switch value so the Windows Package Manager will replace the token with user provided path.
</details>

<details>
 <summary><b>Upgrade</b> - Upgrade is the value that should be passed to the installer when user chooses an upgrade.</summary>

 **Optional Field**

 This key represents the switches to be passed to the installer during an upgrade. This will happen only if the upgrade behavior is "install".

 NOTE: If a user applies override switches via command line via the Windows Package Manager, none of the switches from the manifest will be passed to the installer.
</details>

<details>
 <summary><b>Custom</b> - Custom switches will be passed directly to the installer by the Windows Package Manager.</summary>

 **Optional Field**

 This key represents any switches the Windows Package Manager will pass to the installer in addition to "Silent", "SilentWithProgress", and "Interactive".

 NOTE: If a user applies override switches via command line via the Windows Package Manager, none of the switches from the manifest will be passed to the installer.
</details>

<details>
 <summary><b>UpgradeBehavior</b> - The upgrade method</summary>

 **Optional Field**

 This key represents what the Windows Package Manager should do regarding the currently installed package during a package upgrade. If the package should be uninstalled first, the "uninstallPrevious" value should be specified. If the package should not be upgraded through WinGet, the "deny" value should be specified.

 NOTE: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>Commands</b> - List of commands or aliases to run the package</summary>

 **Optional Field**

 This key represents any commands or aliases used to execute the package after it has been installed.

 IMPORTANT: The Windows Package Manager does not update the path during the install workflow. In those cases, the user may need to restart their shell or terminal before the command will execute the newly installed package. The Windows Package Manager does not support any behavior related to commands or aliases.

 NOTE: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>Protocols</b> - List of protocols the package provides a handler for</summary>

 **Optional Field**

 This key represents any protocols (i.e. URI schemes) supported by the package. For example: `["ftp", "ldap"]`. Entries shouldn't have trailing colons. The Windows Package Manager does not support any behavior related to protocols handled by a package.

 NOTE: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>FileExtensions</b> - List of file extensions the package could support</summary>

 **Optional Field**

 This key represents any file extensions supported by the package. For example: `["html", "jpg"]`. Entries shouldn't have leading dots. The Windows Package Manager does not support any behavior related to the file extensions supported by the package.

 NOTE: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>Dependencies</b> - List of dependencies needed to install or execute the package</summary>

 **Optional Field**

 This key represents any dependencies required to install or run the package.

 IMPORTANT: External Dependencies are not supported. Package dependencies are referenced by their package identifier and must come from the same source. Windows Features may require a reboot before they are enabled. Windows Libraries are not supported.

 NOTE: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>ExternalDependencies</b> - List of external package dependencies</summary>

 **Optional Field**

 This key represents any external dependencies required to install or run the package.

 IMPORTANT: The Windows Package Manager does not support any behavior related to external dependencies.
</details>

<details>
 <summary><b>PackageDependencies</b> - List of package dependencies from current source</summary>

 **Optional Field**

 This key represents any packages from the same source required to install or run the package.

 IMPORTANT: Dependencies are referenced by their package identifier and must come from the same source.
</details>

<details>
 <summary><b>WindowsFeatures</b> - List of Windows feature dependencies</summary>

 **Optional Field**

 This key represents any Windows features required to install or run the package.
</details>

<details>
 <summary><b>WindowsLibraries</b> - List of Windows library dependencies</summary>

 **Optional Field**

 This key represents any Windows libraries required to install or run the package.

 IMPORTANT: The Windows Package Manager does not support any behavior related to Windows Libraries.
</details>

<details>
 <summary><b>PackageFamilyName</b> - PackageFamilyName for appx or msix installer. Could be used for correlation of packages across sources</summary>

 **Optional Field**

 This key represents the [package family name] specified in an MSIX installer. This value is used to assist with matching packages from a source to the program installed in Windows via Add / Remove Programs for list, and upgrade behavior.

 NOTE: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>Capabilities</b> - List of appx or msix installer capabilities</summary>

 **Optional Field**

 This key represents the capabilities provided by an MSIX package. More information is available for [App capability declarations]

 NOTE: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>RestrictedCapabilities</b> - List of appx or msix installer restricted capabilities</summary>

 **Optional Field**

 This key represents the restricted capabilities provided by an MSIX package. More information is available for [App capability declarations]

 NOTE: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>InstallerAbortsTerminal</b> - Indicator for installers that abort the terminal.</summary>

 **Optional Field**

 This key represents the behavior associated with installers that abort the terminal. This most often occurs when a user is performing an upgrade of the running terminal.

 NOTE: Windows Terminal no longer causes this to occur as the MSIX install behavior from the Windows Package Manager is deferred registration.
</details>

<details>
 <summary><b>InstallLocationRequired</b> - Indicator for packages requiring an install location to be specified.</summary>

 **Optional Field**

 This key represents the requirement to have an install location specified. These installers are known to deploy files to the location the installer is executed in.
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

* elevationRequired - Must be run from a shell that is running in an administrative context (e.g - Admin user using powershell/terminal/cmd with "Run as Administrator")
* elevationProhibited - Must be run from a shell that is not running in an administrative context
* elevatesSelf - If called from a non-administrative context, will request elevation. If called from an administrative context, may or may not request elevation.
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

  IMPORTANT: If a market is listed in both this key and the ExcludedMarkets key, the market will be excluded. Both keys are present to reduce the need to list the larger set of markets.
</details>

<details>
  <summary><b>ExcludedMarkets</b> - List of unsupported markets for a package.</summary>

  **Optional Field**

  This key represents any markets a package may not be installed in.

  IMPORTANT: If a market is listed in both this key and the Markets key, the market will be excluded. Both keys are present to reduce the need to list the larger set of markets.
</details>

<details>
 <summary><b>InstallerSuccessCodes</b> - List of additional non-zero installer success exit codes other than known default values by the Windows Package Manager.</summary>

 **Optional Field**

 This key represents any status codes returned by the installer representing a success condition other than zero.

 IMPORTANT: Some return codes indicate a reboot is suggested or required. The Windows Package Manager does not support the reboot behavior currently. Some installers will force a reboot, and the Windows Package Manager does not currently suppress reboot behavior.

 NOTE: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>ExpectedReturnCodes</b> - List of additional non-zero installer exit codes other than known default values by the Windows Package Manager.</summary>

 **Optional Field**

 This key represents any status codes returned by the installer representing a condition other than zero.

 IMPORTANT: Some return codes indicate a reboot is suggested or required. The Windows Package Manager does not support the reboot behavior currently. Some installers will force a reboot, and the Windows Package Manager does not currently suppress reboot behavior.

 NOTE: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>InstallerReturnCode</b> - The non-zero installer exit code other than known default values by the Windows Package Manager.</summary>

 **Optional Field**

 This key represents any status code returned by the installer representing a condition other than zero. MSIX and MSI packages have well known return codes. This is primarily intended for executable installers that have custom or unique return codes that can be mapped to a return response.
</details>

<details>
 <summary><b>ReturnResponse</b> - The return response to be displayed in the event an expected return code is encountered.</summary>

 **Optional Field**

 This key represents a return response to display when an installer returns an expected return code. MSIX and MSI packages have well known return codes. This is primarily intended for executable installers that have custom or unique return codes that can be mapped to a return response.

 NOTE: An enumerated list of values in the JSON schema must be specified for consistency of user experience.
</details>

<details>
 <summary><b>ReturnResponseUrl</b> - The return response URL to be displayed in the event an expected return code is encountered.</summary>

 **Optional Field**

 This key represents a return response URL to display when an installer returns an expected return code. MSIX and MSI packages have well known return codes. This is primarily intended for executable installers that have custom or unique return codes that can be mapped to a return response.

 NOTE: An enumerated list of values in the JSON schema must be specified for consistency of user experience.
</details>

<details>
 <summary><b>ProductCode</b> - ProductCode is used for correlation of packages with manifests is configured sources.</summary>

 **Optional Field**

 This key represents the [product code] specified in an MSI installer. This value is used to assist with matching packages from a source to the program installed in Windows via Add / Remove Programs for list, and upgrade behavior.

 NOTE: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

<details>
 <summary><b>AppsAndFeaturesEntries</b> - AppsAndFeaturesEntries are used to match installed packages with manifests in configured sources.</summary>

 **Optional Field**

  This key represents the values reported by Windows Apps & Features. When a package is installed, entries are made into the Windows Registry.
</details>

<details>
 <summary><b>DisplayName</b> - DisplayName is what is displayed in the Control Panel for installed packages.</summary>

 **Optional Field**

 This key represents the package name as displayed in Windows Apps & Features. This is the value of the `DisplayName` subkey for the package in the [Windows registry][uninstall-registry]. It is used to help correlate installed packages with manifests in configured sources.
</details>

<details>
 <summary><b>DisplayVersion</b> - DisplayVersion is the version displayed in the Control Panel for installed packages.</summary>

 **Optional Field**

 This key represents the package version as displayed in Windows Apps & Features. This is the value of the `DisplayVersion` subkey for the package in the [Windows registry][uninstall-registry]. It is used to help correlate installed packages with manifests in configured sources.

 > Note: When the PackageVersion and DisplayVersion are the same, the DisplayVersion should be omitted from the AppsAndFeaturesEntries
</details>

<details>
 <summary><b>Publisher</b> - Publisher is the value of the package publisher reported in the Windows registry.</summary>

 **Optional Field**

 This key represents the package publisher as displayed in Windows Apps & Features. This is the value of the `Publisher` subkey for the package in the [Windows registry][uninstall-registry]. It is used to help correlate installed packages with manifests in configured sources.
</details>

<details>
 <summary><b>ProductCode</b> - ProductCode is used for correlation of packages with manifests in configured sources.</summary>

 **Optional Field**

 This key represents the [product code] for a package. It is used to help correlate installed packages with manifests in configured sources.

 NOTE: This key is displayed twice for completeness. When AppsAndFeaturesEntries are specified, the ProductCode should be placed both within the installer and the AppsAndFeaturesEntries
</details>

<details>
 <summary><b>UpgradeCode</b> - UpgradeCode is used for correlation of packages with manifests in configured sources.</summary>

 **Optional Field**

 This key represents the [upgrade code] for a package. It is used to help correlate installed packages with manifests in configured sources.
</details>

<details>
 <summary><b>InstallerType</b> - Enumeration of supported installer types.</summary>

 **Optional Field**

 This key represents the installer type for the package. It is used to help correlate installed packages with manifests in configured sources. In some cases, an installer is an .exe based installer, but contains an MSI installer. This key will help the Windows Package Manager understand if upgrading an MSI should be performed when it is contained in an .exe installer.

 NOTE: This key is displayed twice for completeness. When AppsAndFeaturesEntries are specified, the InstallerType should be placed within the installer only, unless the AppsAndFeaturesEntries represent a different InstallerType
</details>

<details>
 <summary><b>UnsupportedArguments</b> - List of unsupported Windows Package Manager Client arguments for an installer.</summary>

 **Optional Field**

 This key represents the list of Windows Package Manager Client arguments the installer does not support. Only the `--log` and `--location` arguments can be specified as unsupported arguments for an installer.

</details>

<details>
 <summary><b>DisplayInstallWarnings</b> - Indicator for displaying a warning message prior to install or upgrade.</summary>

 **Optional Field**

This key represents whether a warning message is displayed to the user prior to install or upgrade if the package is known to interfere with any running applications.

NOTE: The DisplayInstallWarnings behavior is not implemented in the Windows Package Manager 1.6 client.
</details>

<details>
  <summary><b>ReleaseDate</b> - The Release Date for a package.</summary>

  **Optional Field**

  This key represents the release date for a package, in RFC 3339 / ISO 8601 format, i.e. "YYYY-MM-DD".
</details>

<details>
  <summary><b>InstallationMetadata</b> - Details about the installation.</summary>

  **Optional Field**

  This key allows for additional metadata to be used for deeper installation detection.
</details>

<details>
  <summary><b>DefaultInstallLocation</b> - The default installed package location.</summary>

  **Optional Field**

  This key represents the default install location for the package.
</details>

<details>
  <summary><b>Files</b> - The list of installed files.</summary>

  **Optional Field**

  This key represents the files installed for the package.
</details>

<details>
  <summary><b>RelativeFilePath</b> - The relative path to the installed file.</summary>

  **Optional Field**

  This key represents the path to the installed file relative to the default install location.
</details>

<details>
  <summary><b>FileSha256</b> - The optional Sha256 of the installed file.</summary>

  **Optional Field**

  This key represents the Sha256 hash of the installed file.
</details>

<details>
  <summary><b>FileType</b> - The optional installed file type.</summary>

  **Optional Field**

  This key represents the type of the installed file - `launch`, `uninstall`, or `other`. If not specified, the file is treated as `other`.
</details>

<details>
  <summary><b>InvocationParameter</b> - Optional parameter for invocable files.</summary>

  **Optional Field**

  This key represents the parameter to use for invocable files.
</details>

<details>
  <summary><b>DisplayName</b> - Optional display name for invocable files</summary>

  **Optional Field**

  This key represents the display name to use for invocable files.
</details>

<details>
  <summary><b>DownloadCommandProhibited</b> - Optional indicator for packages which cannot be downloaded for offline installation</summary>

  **Optional Field**

  When `true`, this flag will prohibit the manifest from being downloaded for offline installation with the `winget download` command
</details>

<details>
 <summary><b>ManifestType</b> - The manifest type</summary>

 **Required Field**

 This key must have the value "installer". The Microsoft community package repository validation pipelines also use this value to determine appropriate validation rules when evaluating this file.
</details>

<details>
 <summary><b>ManifestVersion</b> - The manifest syntax version</summary>

 **Required Field**

 This key must have the value "1.6.0". The Microsoft community package repository validation pipelines also use this value to determine appropriate validation rules when evaluating this file.
</details>
