# WinGet Manifests
The Windows Package Manager supports several different schema versions. The intent is to follow semantic versioning so earlier versions of the WinGet client are able to install packages using earlier versions of the schema.

This repository contains manifests for packages submitted by publishers and independent community members. Ideally, software publishers will automate the submission process when new releases are made available.

As new releases of the WinGet client are developed with new features and functionality, the schema is routinely updated. Detailed documentation is made available to help authors understand the behaviors associated with keys and values in the YAML manifests.

The community repository will often delay support for new schema versions until enough devices have been updated so customers can benefit from the newly added manifest keys. Please use the recommended schema version mentioned in the PR template.

## Manifest Schema Versions
* [1.10.0](schema/1.10.0/README.md)
* [1.9.0](schema/1.9.0/README.md)
* [1.7.0](schema/1.7.0/README.md)
* [1.6.0 (deprecated)](schema/1.6.0/README.md)
* [1.5.0 (deprecated)](schema/1.5.0/README.md)
* [1.4.0 (deprecated)](schema/1.4.0/README.md)
* [1.2.0 (deprecated)](schema/1.2.0/README.md)
* [1.1.0 (deprecated)](schema/1.1.0/README.md)
* [1.0.0 (deprecated)](schema/1.0.0/README.md)
