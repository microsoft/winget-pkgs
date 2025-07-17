[versionSchema]:        https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.0.0/manifest.version.1.0.0.json
[defaultLocaleSchema]:  https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.0.0/manifest.defaultLocale.1.0.0.json
[localeSchema]:         https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.0.0/manifest.locale.1.0.0.json
[installerSchema]:      https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.0.0/manifest.installer.1.0.0.json

# Windows Package Manager
## Manifest Schema 1.0

The Windows Package Manager 1.1 client does not support all fields in the 1.0 schema.

Manifests submitted to the Windows Package Manager Community Repository should be submitted as a multi-file manifest. Only one version of a package may be submitted per pull request.

A multi-file manifest contains:
* One [version](version.md) ([JSON Schema][versionSchema]) file
* One [default locale](defaultLocale.md) ([JSON Schema][defaultLocaleSchema]) file
* One [installer](installer.md) ([JSON Schema][installerSchema]) file
* Additional optional [locale](locale.md) ([JSON Schema][localeSchema]) files
