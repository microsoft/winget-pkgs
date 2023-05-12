# Using SandboxTest.ps1
The sandbox test script is designed to allow you to test manifests locally without having to install the application to your Windows installation directly. To do this, it makes use of the [Windows Sandbox](https://docs.microsoft.com/windows/security/threat-protection/windows-sandbox/windows-sandbox-overview).

First, [create a fork](https://docs.github.com/get-started/quickstart/fork-a-repo) of this repository and then [clone it](https://docs.github.com/repositories/creating-and-managing-repositories/cloning-a-repository) to your computer. Once the repository has finished cloning, you will need to open a PowerShell terminal since the SandboxTest script is designed to be run from the command line. In the PowerShell terminal which you just opened, navigate to the folder the repository was cloned into and then into the `Tools` folder. You can do this by using `cd <drive>\<path-to-parent>\winget-pkgs\Tools`. Once you are here, you should be ready to run the script.

To test a manifest, simply call the script with the full path to the manifest as an argument. This will validate the manifest, open Windows Sandbox, and attempt to install the package defined in the manifest. If you have already validated your package, you can skip the validation by adding `-SkipManifestValidation` when running the command.

```raw
.\SandboxTest.ps1 <path-to-manifest> [-SkipManifestValidation]
```

# System Requirements
In order to use the SandboxTest script, you must have Windows Sandbox enabled. The Windows Sandbox has the following system requirements -
* Windows 10 Pro, Enterprise or Education build 18305 or Windows 11 (Windows Sandbox is currently not supported on Windows Home edition)
* AMD64 architecture
* Virtualization capabilities enabled in BIOS
* At least 4 GB of RAM
* At least 1 GB of free disk space
* At least two CPU cores

To enable the sandbox, open PowerShell and run the command `Enable-WindowsOptionalFeature -FeatureName "Containers-DisposableClientVM" -All -Online`. Once the command completes, restart your computer to finish the installation.

# References to SandboxTest.ps1
The SandboxTest script has been integrated as part of the toolset here in the winget-pkgs repository. The [YamlCreate Script](/doc/tools/YamlCreate.md) uses SandboxTest to test the creation of new manifests when they are created. The [PRTest Script](/Tools/PRTest.ps1) also uses SandboxTest as a dependency to test manifests which have been submitted to the repository in PRs.
