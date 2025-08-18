[JSON Schema]:                              https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.0.0/manifest.installer.1.0.0.json
[Manifest Specification]:                   https://github.com/microsoft/winget-pkgs/blob/master/doc/manifest/README.md
[Windows Package Manager Manifest Creator]: https://github.com/microsoft/winget-create
[YAML]:                                     https://yaml.org/spec
[semantic version]:                         https://semver.org
[`winget upgrade`]:                         https://docs.microsoft.com/windows/package-manager/winget/upgrade
[App capability declarations]:              https://docs.microsoft.com/windows/uwp/packaging/app-capability-declarations
[MSIX]:                                     https://docs.microsoft.com/windows/msix/overview
[MSI]:                                      https://docs.microsoft.com/windows/win32/msi/windows-installer-portal
[Inno]:                                     https://jrsoftware.org/isinfo.php
[Nullsoft]:                                 https://sourceforge.net/projects/nsis
[WiX]:                                      https://wixtoolset.org
[Burn]:                                     https://wixtoolset.org/docs/v3/bundle/

# Windows Package Manager
## Manifest Schema v1.0.0 Installer File
All Windows Package Manager manifests in the Microsoft community repository are submitted using [YAML] syntax. A JSON schema is provided to aid authoring these files in editors, and in the other tooling related to the Windows Package Manager. This document provides detailed information regarding the usage of the YAML keys in the [installer][JSON Schema] file for multi-file manifests. Please review the [Manifest Specification] if you are not familiar with this file.


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

 The Windows Package Manager client uses this version to determine if an upgrade for a package is available. In some cases, packages may be released with a marketing driven version, and that causes trouble with the [`winget upgrade`] command.

 >Note: The current best practice is to use the value reported in Add / Remove Programs when this version of the package is installed. In some cases, packages do not report a version resulting in an upgrade loop or other unwanted behavior. This practice may seem contrary to using semantic versioning, but it provides the best end to end experience for customers. It will take time for publishers and ISVs to migrate to semantic versioning, and some may intentionally choose to preserve other versioning schemes.
</details>

### Channel
<details>
 <summary>The distribution channel</summary>

 #### Optional Field
 This key represents the distribution channel for a package. Examples may include "stable" or "beta".

 >Note: This key is included for future use. The Windows Package Manager currently does not have any behavior associated with this key. The intent behind this key is to help disambiguate the different channels for packages lacking support for side by side installation. Some packages support having more than one package channel available on a system simultaneously; in this case it is better to use unique packages rather than channels. This key is intended to ensure the proper channel for a package is used during install and upgrade scenarios.
 </details>

### Platform
<details>
 <summary>The installer supported operating system</summary>

 #### Optional Field
 This key represents the Windows platform targeted by the installer. The Windows Package Manager currently supports "Windows.Desktop" and "Windows.Universal". The Windows Package Manager client currently has no behavior associated with this property. It was added for future looking scenarios.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

### MinimumOSVersion
<details>
 <summary>The installer minimum operating system version</summary>

 #### Optional Field
 This key represents the minimum version of the Windows operating system supported by the package.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

### InstallerType
<details>
 <summary>Enumeration of supported installer types. InstallerType is required in either root level or individual Installer level</summary>

 #### Required Field
 This key represents the installer type for the package. The Windows Package Manager supports [MSIX], [MSI], and executable installers. Some well known formats ([Inno], [Nullsoft], [WiX], and [Burn]) provide standard sets of installer switches to provide different installer experiences.

 >Note: The Windows Package Manager defaults to the install mode providing install progress. A best practice is to determine if one of the supported installer technologies was used to build an installer with the .exe file extension. The [Windows Package Manager Manifest Creator] tool can be used to determine if one of the known tools was used to build an installer with the .exe file extension.

 >Note: The Windows Package Manager does not support loose executables with the .exe or .com file extension directly. Compressed files containing installers,  loose executables, and Progressive Web Applications (PWAs) are also not supported.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

### Scope
<details>
 <summary>Scope indicates if the installer is per user or per machine</summary>

 #### Optional Field
 This key represents the scope the package is installed under. The two configurations are "user" and "machine". Some installers support only one of these scopes while others support both via arguments passed to the installer using "InstallerSwitches".

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

### InstallModes
<details>
 <summary>List of supported installer modes</summary>

 #### Optional Field
 This key represents the install modes supported by the installer. The Microsoft community package repository requires a package support "silent" and "silent with progress". The Windows Package Manager also supports "interactive" installers. The Windows Package Manager client does not have any behavior associated with this key.

 >Note: Some installers will attempt to install missing dependencies. If these dependencies require user interaction, the package will not be allowed into the Microsoft community package repository.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

### InstallerSwitches
<details>
 <summary>Switches passed to installers</summary>

 #### Optional Field
 This key represents the set of switches passed to installers.

 >Note: The Microsoft community repository currently requires support for silent and silent with progress installation. Many custom .exe installers will require the proper switches to meet this requirement. The [Windows Package Manager Manifest Creator] tool can be used to determine if one of the known tools was used to build an installer with the .exe file extension. In the event the tool is unable to determine the tool used to build the installer, the publisher may have documentation for the proper switches.
</details>

### Silent
<details>
 <summary>Silent is the value that should be passed to the installer when user chooses a silent or quiet install</summary>

 #### Optional Field
 This key represents switches passed to the installer to provide a silent install experience. These would be used when the command `winget install <package> --silent` is executed.

 >Note: When the Windows Package Manager installs a package using the "silent" install mode, any custom switches will also be passed to the installer. If a user applies override switches via command line via the Windows Package Manager, none of the switches from the manifest will be passed to the installer.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

### SilentWithProgress
<details>
 <summary>SilentWithProgress is the value that should be passed to the installer when user chooses a non-interactive install</summary>

 #### Optional Field
 This key represents switches passed to the installer to provide a silent with progress install experience. This is intended to allow a progress indication to the user, and the indication may come from an installer UI dialogue, but it must not require user interaction to complete. The Windows Package Manager currently defaults to this install experience.

 >Note: When the Windows Package Manager installs a package using the "silent with progress" install mode, any custom switches will also be passed to the installer. If a user applies override switches via command line via the Windows Package Manager, none of the switches from the manifest will be passed to the installer.
</details>

### Interactive
<details>
 <summary>Interactive is the value that should be passed to the installer when user chooses an interactive install</summary>

 #### Optional Field
 This key represents switches passed to the installer to provide an interactive install experience. This is intended to allow a user to interact with the installer. These would be used when the command `winget install <package> --interactive` is executed.

 >Note: When the Windows Package Manager installs a package using the "interactive" install mode, any custom switches will also be passed to the installer. If a user applies override switches via command line via the Windows Package Manager, none of the switches from the manifest will be passed to the installer.

</details>

### InstallLocation
<details>
 <summary>InstallLocation is the value passed to the installer for custom install location. </summary>

 #### Optional Field
 This key represents the path to install the package if the installer supports installing the package in a user configurable location. The **&lt;INSTALLPATH&gt;** token can be included in the switch value so the Windows Package Manager will replace the token with user provided path.
</details>

### Log
<details>
 <summary>Log is the value passed to the installer for custom log file path.</summary>

 #### Optional Field
  This key represents the path logs will be directed to if the installer supports specifying the log path in a user configurable location. The **&lt;LOGPATH&gt;** token can be included in the switch value so the Windows Package Manager will replace the token with user provided path.
</details>

### Upgrade
<details>
 <summary>Upgrade is the value that should be passed to the installer when user chooses an upgrade</summary>

 #### Optional Field
 This key represents the switches to be passed to the installer during an upgrade. This will happen only if the upgrade behavior is "install".

 >Note: If a user applies override switches via command line via the Windows Package Manager, none of the switches from the manifest will be passed to the installer.
</details>

### Custom
<details>
 <summary>Custom switches will be passed directly to the installer by winget</summary>

 #### Optional Field
 This key represents any switches the Windows Package Manager will pass to the installer in addition to "Silent", "SilentWithProgress", and "Interactive".

 >Note: If a user applies override switches via command line via the Windows Package Manager, none of the switches from the manifest will be passed to the installer.
</details>

### InstallerSuccessCodes
<details>
 <summary>List of additional non-zero installer success exit codes other than known default values by winget</summary>

 #### Optional Field
 This key represents any status codes returned by the installer representing a success condition other than zero.

 >Note: Some return codes indicate a reboot is suggested or required. The Windows Package Manager does not support the reboot behavior currently. Some installers will force a reboot, and the Windows Package Manager does not currently suppress reboot behavior.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

### UpgradeBehavior
<details>
 <summary>The upgrade method</summary>

 #### Optional Field
 This key represents what the Windows Package Manager should do regarding the currently installed package during a package upgrade. If the package should be uninstalled first, the "uninstallPrevious" value should be specified.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

### Commands
<details>
 <summary>List of commands or aliases to run the package</summary>

 #### Optional Field
 This key represents any commands or aliases used to execute the package after it has been installed.

 >Note: The Windows Package Manager does not update the path during the install workflow. In those cases, the user may need to restart their shell or terminal before the command will execute the newly installed package. The Windows Package Manager does not support any behavior related to commands or aliases.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

### Protocols
<details>
 <summary>List of protocols the package provides a handler for</summary>

 #### Optional Field
 This key represents any protocols supported by the package. The Windows Package Manager does not support any behavior related to protocols handled by a package.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

### FileExtensions
<details>
 <summary>List of file extensions the package could support</summary>

 #### Optional Field
 This key represents any file extensions supported by the package. The Windows Package Manager does not support any behavior related to the file extensions supported by the package.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

### Dependencies
<details>
 <summary>List of dependencies needed to install or execute the package</summary>

 #### Optional Field
 This key represents any dependencies required to install or run the package.

 >Note: The Windows Package Manager does not support any behavior related to dependencies.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

### WindowsFeatures
<details>
 <summary>List of Windows feature dependencies</summary>

 #### Optional Field
 This key represents any Windows features required to install or run the package.

 >Note: The Windows Package Manager does not support any behavior related to dependencies.
</details>

### WindowsLibraries
<details>
 <summary>List of Windows library dependencies</summary>

 #### Optional Field
 This key represents any Windows libraries required to install or run the package.

 >Note: The Windows Package Manager does not support any behavior related to dependencies.
</details>

### PackageDependencies
<details>
 <summary>List of package dependencies from current source</summary>

 #### Optional Field
 This key represents any packages from the same source required to install or run the package.

 >Note: The Windows Package Manager does not support any behavior related to dependencies.
</details>

### ExternalDependencies
<details>
 <summary>List of external package dependencies</summary>

 #### Optional Field
 This key represents any external dependencies required to install or run the package.

 >Note: The Windows Package Manager does not support any behavior related to dependencies.
</details>

### PackageFamilyName
<details>
 <summary>PackageFamilyName for appx or msix installer. Could be used for correlation of packages across sources</summary>

 #### Optional Field
 This key represents the package family name specified in an MSIX installer. This value is used to assist with matching packages from a source to the program installed in Windows via Add / Remove Programs for list, and upgrade behavior.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

### ProductCode
<details>
 <summary>ProductCode could be used for correlation of packages across sources</summary>

 #### Optional Field
 This key represents the product code specified in an MSI installer. This value is used to assist with matching packages from a source to the program installed in Windows via Add / Remove Programs for list, and upgrade behavior.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

### Capabilities
<details>
 <summary>List of appx or msix installer capabilities</summary>

 #### Optional Field
 This key represents the capabilities provided by an MSIX package. More information is available for [App capability declarations]

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

### RestrictedCapabilities
<details>
 <summary>List of appx or msix installer restricted capabilities</summary>

 #### Optional Field
 This key represents the restricted capabilities provided by an MSIX package.More information is available for [App capability declarations]

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.
</details>

### Installer
<details>
 <summary>Package installer</summary>

 #### Required Field
 The key represents an installer for a package.

 >Note: Many of the keys related to installers may either be at the root level of the manifest, or included in an installer. Any values provided at the root level and not specified in an installer will be inherited.
</details>

### InstallerLocale
<details>
 <summary>Locale for package installer</summary>

 #### Optional Field
 This key represents the locale for an installer *not* the package meta-data. Some installers are compiled with locale or language specific properties. If this key is present, it is used to represent the package locale for an installer.

 >Note: This key may be present in the root of the manifest as the default value for all installer nodes. This key may also be present in an individual installer node as well. If this key is in the manifest root and in an installer node, the value in the installer node will apply.

</details>

### Architecture
<details>
 <summary>The installer target architecture</summary>

 #### Required Field
 This key represents the hardware architecture targeted by the installer. The Windows Package Manager will attempt to determine the best architecture to use. If emulation is available and the native hardware architecture does not have a supported installer, the emulated architecture may be used.
 </details>

### InstallerUrl
<details>
 <summary>The installer Url</summary>

 #### Required Field
 This key represents the URL to download the installer.
</details>

### InstallerSha256
<details>
 <summary>Sha256 is required. Sha256 of the installer</summary>

 #### Required Field
 This key represents the SHA 256 hash for the installer. It is used to confirm the installer has not been modified. The Windows Package Manager will compare the hash in the manifest with the calculated hash of the installer after it has been downloaded.

 >Note:  The [Windows Package Manager Manifest Creator] can be used to determine the SHA 256 of the installer. The `winget hash &lt;pathToInstaller&gt;` command can also be used to determine the SHA 256 of the installer.
</details>

### SignatureSha256
<details>
 <summary>SignatureSha256 is recommended for appx or msix. It is the sha256 of signature file inside appx or msix. Could be used during streaming install if applicable</summary>

 #### Optional Field
 This key represents the signature file (AppxSignature.p7x) inside an MSIX installer. It is used to provide streaming install for MSIX packages.

 >Note: MSIX installers must be signed to be included in the Microsoft community package repository. If the installer is an MSIX this signature should be included in the manifest. The [Windows Package Manager Manifest Creator] can be used to determine the signature SHA 256. The `winget hash <pathToInstaller> --msix` command can also be used to determine the signature SHA 256.
</details>

### Installers
<details>
 <summary>Array of package installers</summary>

 #### Required Field
 This key must be present for each installer for this version of the package. There may be multiple installer nodes to support different architectures, locales, install scopes (User vs. Machine)
</details>

### ManifestType
<details>
 <summary>The manifest type</summary>

 #### Required Field
 This key must have the value "installer". The Microsoft community package repository validation pipelines also use this value to determine appropriate validation rules when evaluating this file.
</details>

### ManifestVersion
<details>
 <summary>The manifest syntax version</summary>

 #### Required Field
 This key must have the value "1.0.0". The Microsoft community package repository validation pipelines also use this value to determine appropriate validation rules when evaluating this file.
</details>
