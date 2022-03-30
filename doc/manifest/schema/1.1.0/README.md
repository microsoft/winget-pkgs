# Windows Package Manager
## Manifest Schema 1.1

The Windows Package Manager 1.2 client does not support all fields in the 1.1 schema.

Manifests submitted to the Windows Package Manager Community Repository should be submitted as a multi-file manifest. Only one version of a package may be submitted per pull request.

A multi-file manifest contains:
* One "version" file
* One "installer" file
* One "defaultLocale" file
* Additional optional "locale" files