# Using YamlCreate.ps1
Using the YamlCreate script is easy. First, [create a fork](https://docs.github.com/get-started/quickstart/fork-a-repo) of this repository and then [clone it](https://docs.github.com/repositories/creating-and-managing-repositories/cloning-a-repository) to your computer. Once the repository has finished cloning, open file explorer and navigate to the folder that the repository was cloned into. Inside this folder, you should be able to navigate to the `Tools` folder, which contains the script. Right click on "YamlCreate" and select "Run with PowerShell". If it is your first time running the script, you may see a message that it is installing some additional packages - [NuGet](https://docs.microsoft.com/nuget/), and [powershell-yaml](https://www.powershellgallery.com/packages/powershell-yaml/0.4.2) ([See it on GitHub](https://github.com/cloudbase/powershell-yaml)). These are required for the script to run.

Once the script begins, it will walk you through a series of prompts to create manifests. Enter the requested information for each of the prompts and once all the prompts are completed, the manifest will be generated! If you have Windows Sandbox enabled and the GitHub CLI installed, you can even automatically test and submit your manifest instead of having to do it manually.

# Optional Software
## Windows Package Manager
Because the script is meant for creating manifests for the Windows Package Manager, we highly recommend you install it. This allows the script to automatically validate the manifests that are generated and also provides you the ability to easily install other optional software packages. Instructions for [installing the package manager](https://github.com/microsoft/winget-cli#installing-the-client) can be found over on the [winget-cli repository](https://github.com/microsoft/winget-cli).

## Windows Sandbox

The Windows Sandbox is an optional feature within windows that allows you to run a virtual environment to test software. The [SandboxTest.ps1](../../Tools/SandboxTest.ps1) script integrates with the Windows Sandbox to allow manifests to be tested without needing to install the software onto your machine. The script can automatically run the same validation as long as the Windows Sandbox is enabled. To enable the sandbox, open PowerShell and run the command `Enable-WindowsOptionalFeature -FeatureName "Containers-DisposableClientVM" -All -Online`. Once the command completes, restart your computer to finish the installation.

## Git

The script can automatically create commits and branches within your fork of the repo. In order to do this, you need to have Git installed. The easiest way to do this is to use winget! Open up PowerShell and install Git using `winget install Git`. This will allow the script to push the new manifest to your fork of the repository and provide you with a link to submit your pull request.

## GitHub CLI

If you have Git installed, you can also create the pull request for your manifest directly from the script. You will have to install the GitHub CLI and authorize it with your GitHub Account. Again, winget makes installing the CLI easy. Open up PowerShell and install the GitHub CLI using `winget install GitHub.CLI`. Once the CLI is installed, close, then re-open PowerShell. To log in and authorize the CLI, run the command `gh auth login`. Follow the prompts that appear to finish the authorization.

# Command Line Arguments

When running YamlCreate through the command line, you can specify additional arguments such as the package identifier or the package version. You can also use the settings switch to open the settings file. More information on the available settings is below.

`.\YamlCreate.ps1 [-PackageIdentifier <identifier>] [-PackageVersion <version>] [-Mode <1-5>] [-Settings] [-SkipPRCheck]`

# YamlCreate Settings

YamlCreate offers a few settings to customize your manifest creation experience. The settings file is found in the `%LOCALAPPDATA%\YamlCreate` folder on Windows and `/home/<username>/.config/YamlCreate` on Linux and macOS. It is empty by default, but you can copy the sample below which describes what all of the available options are; or, you can enter just specific keys as you see fit.

```yaml
# This setting allows you to set a default action for whether or not to test your manifest in windows sandbox
    # always - Always tests manifests
    # never - Never tests manifests
TestManifestsInSandbox: ask

# This setting allows you to define a default action for whether or not to save files to the temporary folder
    # always - Always saves files to the temporary folder
    # never - Always removes the files from the temporary folder after script execution
    # manual - Never downloads any files. All InstallerSha256 values must be entered manually
SaveToTemporaryFolder: ask

# This setting allows you to set a default action for whether or not to submit PR's
    # always - Always submits PR's automatically
    # never - Never submits PR's automatically
AutoSubmitPRs: ask

# This setting allows you to set a default action for when conflicting PRs are detected
    # always - Skips checking for conflicting PRs
    # never - Exits the script if conflicting PRs are detected
ContinueWithExistingPRs: ask

# This setting allows you to set a default action for when redirected URLs are detected
    # always - Always uses the detected destination URL
    # never - Always uses the originally entered URL
UseRedirectedURL: ask

# This setting allows you to set a default value for whether or not you have signed the Microsoft CLA
# If this value is set to true, all automatic PR's will be marked as having the CLA signed
SignedCLA: false

# This setting allows you to skip the prompt to confirm you want to use quick update mode
# If this value is set to true, the Quick Update Warning will be skipped
SuppressQuickUpdateWarning: false

# This setting allows you to require that the exact key corresponding to a menu option be pressed
# If this value is set to true, there is effectively no default action for menus
ExplicitMenuOptions: false

# This settings allows for BURN installers to be automatically identified when possible
# If this value is set to true, the headers of exe files will be scanned for the BURN identifier
# WARNING: Enabling this setting will greatly increase the amount of time needed to process an .exe file
IdentifyBurnInstallers: false

# This setting allows you to set a default installer locale
# Any value defined here will be set as the installer locale if one is not entered
DefaultInstallerLocale: en-US

# This setting allows for the usage of various advanced modes
# Unless you know what you are doing, it is best to leave this disabled
EnableDeveloperOptions: false

# This setting allows for the selection of which manifest version is used
# The script is not tested with all manifest versions, and stability is not guaranteed. Use with caution
OverrideManifestVersion: 1.4.0
```
