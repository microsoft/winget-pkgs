[schemaFolder]:                             https://github.com/microsoft/winget-cli/tree/master/schemas/JSON/manifests/v1.5.0
[versionSchema]:                            https://github.com/microsoft/winget-cli/tree/master/schemas/JSON/manifests/v1.5.0/manifest.version.1.5.0.json
[defaultLocaleSchema]:                      https://github.com/microsoft/winget-cli/tree/master/schemas/JSON/manifests/v1.5.0/manifest.defaultLocale.1.5.0.json
[localeSchema]:                             https://github.com/microsoft/winget-cli/tree/master/schemas/JSON/manifests/v1.5.0/manifest.locale.1.5.0.json
[installerSchema]:                          https://github.com/microsoft/winget-cli/tree/master/schemas/JSON/manifests/v1.5.0/manifest.installer.1.5.0.json
[Windows Package Manager Manifest Creator]: https://github.com/microsoft/winget-create
[YAML Create]:                              https://github.com/microsoft/winget-pkgs/blob/master/Tools/YamlCreate.ps1

# Windows Package Manager

## Manifest Schema 1.5

The Windows Package Manager 1.5 client does not support all fields in the 1.5 schema.

The Windows Package Manager uses manifests (YAML files) to locate and install packages for Windows users. This specification provides references to JSON schemas as well as best practices.

Manifests submitted to the Windows Package Manager Community Repository should be submitted as a multi-file manifest. Only one version of a package may be submitted per pull request. The [singleton](singleton.md) manifest format is supported by the client, but has been deprecated in the community repository. Rich tooling exists to generate manifests. The [Windows Package Manager Manifest Creator] and [YAML Create] were both designed to produce well formed and rich manifests.

A multi-file manifest contains:
* One [version](version.md) ([JSON Schema][versionSchema]) file
* One [default locale](defaultLocale.md) ([JSON Schema][defaultLocaleSchema]) file
* One [installer](installer.md) ([JSON Schema][installerSchema]) file
* Additional optional [locale](locale.md) ([JSON Schema][localeSchema]) files

## YAML file name and folder structure
YAML files shall be added to the repository with the following folder structure:
manifests / p / publisher / package / packageVersion / publisher.package.&lt;manifestFile&gt;.yaml

Example:
`manifests/m/Microsoft/WindowsTerminal/1.9.1942/Microsoft.WindowsTerminal.installer.yaml`

* Manifests are partitioned by the first letter of the publisher name (in lower case). For example: m.
* Publisher folder is the name of the company that publishes the tool. For example: Microsoft.
* The child folder package is the name of the application or tool. For example: WindowsTerminal.
* The child folder package version is the version of the package. For example: 1.6.10571.0.
* The filename must be a combination of the publisher name and the application name. For example: Microsoft.WindowsTerminal.yaml.

The publisher and application folders MUST match the values used to define the Id. See PackageIdentifier: in the YAML for more detail.
The version in the folder name MUST match the version field value in the YAML file. See PackageVersion: in the YAML for more detail.

There are two primary types of manifests. A single file manifest (singleton) and a multi-file manifest.
[JSON schemas][schemaFolder] have been provided
to help strongly type attributes and requirements.

## YAML Syntax
Each field in the file must be PascalCased and cannot be duplicated.

## Best Practices
The package identifier must be unique. You cannot have multiple submissions with the same package identifier. Only one pull request per package version is allowed.

Avoid creating multiple publisher folders. For example, do not create "Contoso Ltd." if there is already a "Contoso" folder.

All tools must support a silent install to be permitted in the Windows Package Manager Community Repository. If you have an executable that does not support a silent install, then we cannot provide that tool at this time.

Provide as many fields as possible. The more meta-data you provide the better the user experience will be. In some cases, the fields may not yet be supported by the Windows Package Manager client (winget.exe).

The length of strings in this specification should be limited to 100 characters before a line break.
