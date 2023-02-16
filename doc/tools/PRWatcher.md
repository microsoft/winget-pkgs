# Using PRWatcher.ps1
PRWatcher includes Watch-PRTitles, to give information about pull requests (PRs) from watching their titles in your clipboard. Also includes utility programs Get-CleanClip and Search-Winget. To use, load the file contents into your PowerShell application through your desired means. (Copy/paste, Import-Module, include in Profile, et cetera.) Then run "Watch-PRTitles" and the script will monitor your clipboard, attempting to parse PackageIdentifiers and version numbers, and comparing these to Winget's public manifest.

# Utility Functions
Additionally included are utility functions:  
- Get-CleanClip to extract the PackageIdentifier. 
- Search-Winget, to streamline non-interactive Winget search. 

These are library functions also used in other Manual Validation functions, as part of the philosophy of building a declarative layer to handle operations and build objects, and an imperative layer on top to orchestrate operations. These utility functions are in the declarative layer, while Watch-PRTitles is in the imperative layer.

## Winget repository on GitHub
This script is designed for use with the [Winget package repository](https://github.com/microsoft/winget-pkgs) on GitHub, specifically for PR approvers and working with package PRs in general.

## Features
- Logging of valid PR titles, filtering on PR # at the end.
- Default semantic versioning for more accurate versions. Failback to string-based versioning is planned to be working again soon.
- "Automatic removal" clipboard insertion of output, to paste as PR comment confirming that the newer version is already available through Winget.

# Command Line Arguments
PRWatcher provides additional arguments for more specific functionality. 

`Watch-PRTitles [-noNew] [-authFile C:\path\to\Auth.csv] [-LogFile C:\path\to\Log.txt]`

## -noNew
This setting prevents logging the PR title if the package isn't already in the Winget public manifest. This allows for streamlining acceptance of existing package upgrades, so an approver can skip  new packages for more thorough examination later. 

## -authFile
Location of Auth.csv - defaults to current path location. This might become a built-in web location in future versions.

## -LogFIle
Location of logging file - defaults to "Log.txt" in current path location.

 


