# Using PRWatcher.ps1
PRWatcher includes Watch-PRTitles, to give information about pull requests (PRs) from watching their titles in your clipboard. To use, load the file contents into your PowerShell application through your desired means. (Copy/paste, Import-Module, include in Profile, et cetera.) Then run "Watch-PRTitles" and the script will monitor your clipboard, attempting to parse PackageIdentifiers and version numbers, and comparing these to WinGet's public manifest.

## Utility Functions
Additionally included are utility functions:
- Get-CleanClip to extract the PackageIdentifier.
- Search-WinGetManifest to streamline non-interactive WinGet search.

These are library functions also used in other Manual Validation functions, as part of the philosophy of building a declarative layer to handle operations and build objects, and an imperative layer on top to orchestrate operations. These utility functions are in the declarative layer, while Watch-PRTitles is in the imperative layer.

# WinGet repository on GitHub
This script is designed for use with the [WinGet package repository](https://github.com/microsoft/WinGet-pkgs) on GitHub, specifically for PR approvers and working with package PRs in general.

# Additional files
This script uses Auth.csv to provide hints to help a PR approver identify packages with restricted manifest submitters. These hints are not authoritative and are planned to be superseded by a more formal process in the future.

## Features
- Logging of valid PR titles, filtering on PR # at the end.
- Default semantic versioning for more accurate versions. Fail-back to string-based versioning is planned to be working again soon.
- "Automatic removal" clipboard insertion of output, to paste as PR comment confirming that the newer version is already available through WinGet.

# Command Line Arguments
PRWatcher provides additional arguments for more specific functionality.

`Watch-PRTitles [-noNew] [-authFile C:\path\to\Auth.csv] [-LogFile C:\path\to\Log.txt]`

## -noNew
This setting prevents logging the PR title if the package isn't already in the WinGet public manifest. This allows for streamlining acceptance of existing package upgrades, so an approver can skip  new packages for more thorough examination later.

## -authFile
Location of Auth.csv - defaults to current path location. This might become a built-in web location in future versions.

## -LogFile
Location of logging file - defaults to "Log.txt" in current path location.

## -Chromatic
Color schemes, for accessability and variety:

Color    | Warning | Caution | OK
Default | Red   | Yellow | Green
MonoWarm| Red | Yellow | White
MonoCool | Blue  | Cyan | Green
RainbowRotate| Red, Blue, Magenta | Yellow, DarkCyan, Cyan | Green, White, Gray
