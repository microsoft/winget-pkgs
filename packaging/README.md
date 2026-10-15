# Packaging

## winget

`winget/manifests/s/Soheilous/GenLauncher/<version>/` holds the three manifest files for the Windows Package Manager
(`winget install Soheilous.GenLauncher`). Check them with `winget validate --manifest <that folder>`.

To publish a version: fork <https://github.com/microsoft/winget-pkgs>, copy the version folder to the same path there
(`manifests/s/Soheilous/GenLauncher/<version>/`) and open a pull request. Or let `wingetcreate` do it:

```
wingetcreate update Soheilous.GenLauncher --version <version> --urls <installer url> --submit
```

For a new release, bump `PackageVersion`, the installer URL, `InstallerSha256` (uppercase SHA-256 of the released
installer) and `ReleaseDate` in all three files. winget checks the file's hash, so installing this way does not trigger
the Windows SmartScreen prompt.
