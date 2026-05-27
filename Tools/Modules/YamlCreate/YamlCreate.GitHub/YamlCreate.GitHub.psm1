# Module variable for upstream remote URL
$script:wingetUpstream = 'https://github.com/microsoft/winget-pkgs.git'

<#
.SYNOPSIS
    Gets the URL of a git remote.

.DESCRIPTION
    Gets the URL for a specified git remote by name.

.PARAMETER RemoteName
    The name of the git remote (e.g., 'origin', 'upstream').

.OUTPUTS
    System.String - The URL of the remote, or $null if the remote does not exist.

.EXAMPLE
    PS> Get-Remote -RemoteName upstream
    https://github.com/microsoft/winget-pkgs.git
#>
function Get-Remote {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RemoteName
    )

    try {
        $remoteUrl = git remote get-url $RemoteName 2>$null
        if ($remoteUrl) {
            return $remoteUrl
        }
        return $null
    } catch {
        return $null
    }
}

<#
.SYNOPSIS
    Sets or adds a git remote.

.DESCRIPTION
    Sets the URL for an existing git remote, or adds a new remote if it doesn't exist.

.PARAMETER RemoteName
    The name of the git remote (e.g., 'origin', 'upstream').

.PARAMETER Url
    The URL to set for the remote.

.OUTPUTS
    System.Boolean - $true if successful, $false otherwise.

.EXAMPLE
    PS> Set-Remote -RemoteName upstream -Url 'https://github.com/microsoft/winget-pkgs.git'
    True
#>
function Set-Remote {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RemoteName,

        [Parameter(Mandatory = $true)]
        [string] $Url
    )

    try {
        $existingUrl = Get-Remote -RemoteName $RemoteName
        if ($existingUrl) {
            git remote set-url $RemoteName $Url 2>$null
        } else {
            git remote add $RemoteName $Url 2>$null
        }
        return $?
    } catch {
        return $false
    }
}

<#
.SYNOPSIS
    Finds open pull requests for a package version.

.DESCRIPTION
    Queries the GitHub API for open pull requests matching the specified package identifier and version.

.PARAMETER PackageIdentifier
    The package identifier (e.g., 'Microsoft.WindowsTerminal').

.PARAMETER PackageVersion
    The version of the package (e.g., '1.18.0').

.OUTPUTS
    System.Object - The PR API response object if found, or $null if none found.

.EXAMPLE
    PS> Find-PullRequest -PackageIdentifier 'Microsoft.WindowsTerminal' -PackageVersion '1.18.0'
#>
function Find-PullRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PackageIdentifier,

        [Parameter(Mandatory = $true)]
        [string] $PackageVersion
    )

    try {
        $query = "repo%3Amicrosoft%2Fwinget-pkgs%20is%3Apr%20$($PackageIdentifier -replace '\.', '%2F'))%2F$PackageVersion%20in%3Apath"
        $uri = "https://api.github.com/search/issues?q=$query&per_page=1"

        $response = @(Invoke-WebRequest $uri -UseBasicParsing -ErrorAction SilentlyContinue | ConvertFrom-Json)[0]
        return $response
    } catch {
        return $null
    }
}

<#
.SYNOPSIS
    Gets the PR template content from the upstream remote.

.DESCRIPTION
    Fetches the PULL_REQUEST_TEMPLATE.md content from the upstream remote repository.
    If the template cannot be fetched, a warning is issued but the function continues.

.OUTPUTS
    System.String - The template content if available, or $null if unavailable.

.EXAMPLE
    PS> Get-PrTemplate
    # PR Template Content...
#>
function Get-PrTemplate {
    try {
        $rawContentUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/.github/PULL_REQUEST_TEMPLATE.md"
        $template = Invoke-WebRequest $rawContentUrl -UseBasicParsing -ErrorAction SilentlyContinue
        if ($template) {
            return $template.Content
        } else {
            Write-Warning "Could not fetch PR template from upstream remote"
            return $null
        }
    } catch {
        Write-Warning "Could not fetch PR template from upstream remote: $_"
        return $null
    }
}

# Export module variables and functions
Export-ModuleMember -Variable 'wingetUpstream' -Function @('Get-Remote', 'Set-Remote', 'Find-PullRequest', 'Get-PrTemplate')
