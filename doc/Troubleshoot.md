# Troubleshooting Errors

Many issues can be caught before submitting your PR by following these steps:
1. **Validate the manifest file**:
   Run:
   ```winget validate <path-to-the-manifest>```

2. **Install the manifest locally**:
   This verifies the Sha256 Hash and checks if the application installs silently (without human interaction). Run:
   ```winget install --manifest <path-to-the-manifest>```
   or
   ```winget install -m <path-to-the-manifest>```

If these steps pass, here are some troubleshooting tips:


## Manifest-Validation-Error

Manifest validation errors indicate a problem with the manifest file. Validate the manifests before submission:
```winget validate <path-to-the-manifest>```

For documentation on the manifest specification, see the [manifest schema](manifest/README.md).

### Common Mistakes:
1. **Publisher folder and application name folder**:
   Ensure they match the `PackageIdentifier` of the manifest.
2. **Typos in the filename**:
   Filenames must match the `PackageIdentifier`.

> [!IMPORTANT]
`PackageIdentifier` is case-sensitive, as are the manifest path and filename.

- **PackageIdentifier**: `<publisher>.<name>`
- **Manifest Path**: `<first-letter-of-the-publisher>\<publisher>\<name>\<version>`
- **Filenames**:
  - Installer: `<PackageIdentifier>.installer.yaml`
  - Locale: `<PackageIdentifier>.locale.<language-code>.yaml`
  - Version: `<PackageIdentifier>.yaml`

## Binary-Validation-Error

Binary validation errors indicate the installer failed static analysis.

### Common Causes:
1. **Sha256 HASH mismatch**:
   Run:
   ```winget hash <installer>```
   to generate the correct hash.
2. **Invalid URL**:
   Ensure the installer URL is publicly available and valid.
3. **Malware detection**:
   If the installer is flagged as malware, submit it to the defender team for [analysis](https://docs.microsoft.com/windows/security/threat-protection/windows-defender-antivirus/antivirus-false-positives-negatives#submit-a-file-to-microsoft-for-analysis) as a potential false positive.


## SmartScreen-Validation-Error

Windows Defender SmartScreen validation errors indicate the URL provided has a bad reputation.


## Internal-Error

Internal errors indicate a service issue. Microsoft will investigate and pursue a fix.
For a list of known issues, see our repository [issues](https://github.com/microsoft/winget-pkgs/issues).
