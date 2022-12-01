# Troubleshooting Errors
Many of the issues can be caught before submitting your PR, if you follow these steps:
1) Validate the manifest file by running ```winget validate <path-to-the-manifest>```
2) Install the manifest on your local machine. This will verify the Sha256 Hash and check whether the application is able to install silently (without any human interaction) or not. You can do this by running: ```winget install --manifest <path-to-the-manifest>``` or ```winget install -m <path-to-the-manifest>```

Once those steps pass, here are some troubleshooting tips:

## Manifest-Validation-Error
Manifest validation errors indicate that there is a problem with the manifest file. Many of the issues can be caught before submitting your PR, when you validate the manifests before submission:  ```winget validate <path-to-the-manifest>```

For documentation on the manifest specification, please see the [manifest schema](/doc/manifest/schema)

Here are some common mistakes not discovered by the winget validation.

1) Check the publisher folder and application name folder.
2) Check for typos in the filename.

Both of them should match the `PackageIdentifier` of the manifest.
> Note: `PackageIdentifier` is case-sensitive and so the path of the manifest and filename.

PackageIdentifier: `<publisher>.<name>`

Manifest Path: `<first-letter-of-the-publisher>\<publisher>\<name>\<version>`

Filenames:
- For singleton manifest: `<publisher>.<name>.yaml`
- For multi-manifests
  - Installer: `<PackageIdentifier>.installer.yaml`
  - Locale: `<PackageIdentifier>.locale.<language-code>.yaml`
  - Version: `<PackageIdentifier>.yaml`

## Binary-Validation-Error
Binary validation errors indicate that the installer failed static analysis.

Here are some common causes for the Binary-Validation-Error label:
1) The Sha256 HASH in the manifest does not match the HASH of the installer. Run ```winget hash <installer>``` to generate the hash.
2) The URL is not valid. Make sure the URL to the installer is publicly available and valid.
3) The installer has been identified as malware. If the installer is detected as malware, you can submit the installer to the defender team for [analysis](https://docs.microsoft.com/windows/security/threat-protection/windows-defender-antivirus/antivirus-false-positives-negatives#submit-a-file-to-microsoft-for-analysis) as a potential false positive.

## SmartScreen-Validation-Error
Windows Defender SmartScreen validation errors indicate that the URL you provided has a bad reputation.

## Internal-Error
Internal-Errors indicate there was an error hit by the service. Microsoft will investigate these and pursue a fix. For a list of known issues, see our repository [issues](https://github.com/microsoft/winget-pkgs/issues)
