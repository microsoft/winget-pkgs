# Using SandboxTest.ps1

The `SandboxTest.ps1` script allows you to test manifests locally using the [Windows Sandbox](https://docs.microsoft.com/windows/security/threat-protection/windows-sandbox/windows-sandbox-overview) without installing the application directly on your system.

## Prerequisites

1. **Fork and Clone the Repository**
   - [Fork this repository](https://docs.github.com/get-started/quickstart/fork-a-repo).
   - [Clone the forked repository](https://docs.github.com/repositories/creating-and-managing-repositories/cloning-a-repository) to your computer.

2. **Enable Windows Sandbox**
   Ensure Windows Sandbox is enabled. Run the following command in PowerShell:
   ```powershell
   Enable-WindowsOptionalFeature -FeatureName "Containers-DisposableClientVM" -All -Online
   ```
   Restart your computer after the command completes.

### System Requirements

- Windows 10 or 11 Pro, Enterprise, or Education (build 18305 or later);
  *Windows Sandbox is not supported on Windows Home edition*
- AMD64 architecture
- Virtualization enabled in BIOS
- At least 4 GB of RAM, 1 GB of free disk space, and two CPU cores


## Usage

Open a PowerShell terminal and navigate to the `Tools` folder:
```powershell
cd <drive>\<path-to-parent>\winget-pkgs\Tools
```

Run the script with the full path to the manifest as an argument. This validates the manifest, opens Windows Sandbox, and attempts to install the package.

```powershell
.\SandboxTest.ps1 <path-to-manifest> [<options>]
```

### Supported Options

| Argument                     | Description                                                                 |
|------------------------------|-----------------------------------------------------------------------------|
| **-Manifest**                | Path to the manifest to install in the Sandbox                             |
| **-Script**                  | Post-installation script to run in the Sandbox                             |
| **-MapFolder**               | Folder to map in Sandbox (default: current directory)                      |
| **-WinGetVersion**           | Specify the version of WinGet to use in Sandbox                            |
| **-WinGetOptions**           | Additional options for the `winget install` command                        |
| **-Unattended**              | Wait up to the specified number of minutes for the Sandbox run to finish, then write its output to the host |
| **-SkipManifestValidation**  | Skip `winget validate -m <manifest>` if already validated                  |
| **-Prerelease**              | Use preview release versions of WinGet                                    |
| **-EnableExperimentalFeatures** | Enable WinGet experimental features                                     |
| **-Clean**                   | Force re-download of WinGet and dependencies                               |

> [!IMPORTANT]
> The `-GitHubToken` option has been removed. Use the `WINGET_PKGS_GITHUB_TOKEN` environment variable instead.

---

## Examples

### Test a Manifest with the Latest Stable WinGet
```powershell
.\SandboxTest.ps1 <path-to-manifest>
```

### Test a Manifest with the Latest Preview WinGet
```powershell
.\SandboxTest.ps1 <path-to-manifest> -Prerelease
```

### Test a Manifest with a Specific WinGet Version
```powershell
.\SandboxTest.ps1 <path-to-manifest> -WinGetVersion 1.10.340 -Prerelease -Script {Write-Host 'Script finished'}
```

### Install a Package from the Repository in Sandbox
```powershell
.\SandboxTest.ps1 -WinGetVersion 1.9 -Script {winget install <PackageIdentifier> --accept-source-agreements}
```

---

## Unattended Mode

By default the script starts the Sandbox and returns immediately; the output of the session running inside the Sandbox stays inside the Sandbox. The `-Unattended` option makes the script wait for that session to finish and then write its output to the host, which is useful for automation.

`-Unattended` requires a value, which is the number of minutes to wait before giving up. 15 is a good starting point.

```powershell
.\SandboxTest.ps1 <path-to-manifest> -Unattended 15
```

The Sandbox is left open after the run finishes.

### Results

The Sandbox session writes its results to `%LOCALAPPDATA%\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\SandboxTest\Results`:

| Item             | Description                                                              |
|------------------|--------------------------------------------------------------------------|
| `transcript.log` | Full PowerShell transcript of the Sandbox session                        |
| `metadata.json`  | WinGet version, OS build, manifest folder name, `winget install` exit code (decimal and hexadecimal), `-Script` exit status, and start/end timestamps |
| `WinGetLogs\`    | WinGet diagnostic logs copied from the Sandbox                           |
| `done`           | Marker file written once the Sandbox session has finished                |

This folder is deleted at the start of every run, so copy anything you want to keep before running the script again.

The transcript and the metadata are also written to the host output once the run finishes. If the run does not finish within the given number of minutes, the script writes whatever the transcript contains so far and exits with code 5.

---

## Integration with Other Scripts

- **[YamlCreate Script](../../Tools/YamlCreate.ps1):** Uses `SandboxTest.ps1` to test newly created manifests.
- **[PRTest Script](../../Tools/PRTest.ps1):** Depends on `SandboxTest.ps1` to validate manifests submitted in pull requests.
