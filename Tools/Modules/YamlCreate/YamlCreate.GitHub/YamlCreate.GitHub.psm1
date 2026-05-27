# Module variable for upstream remote URL
$script:wingetUpstream = 'https://github.com/microsoft/winget-pkgs.git'
$script:AppInstallerPFN = 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe'
$script:AppInstallerDataFolder = Join-Path -Path (Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Packages') -ChildPath $script:AppInstallerPFN
$script:TokenValidationCache = Join-Path -Path $script:AppInstallerDataFolder -ChildPath 'TokenValidationCache'
$script:CachedTokenExpiration = 30 # Days
$script:GitHubToken = $env:WINGET_PKGS_GITHUB_TOKEN
$script:GitHubApiBaseUri = 'https://api.github.com'

function Test-GithubToken {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'The standard workflow that users use with other applications requires the use of plaintext GitHub Access Tokens')]

    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [String] $Token
    )

    if ([string]::IsNullOrWhiteSpace($Token)) { return $false }

    $_memoryStream = [System.IO.MemoryStream]::new()
    $_streamWriter = [System.IO.StreamWriter]::new($_memoryStream)
    $_streamWriter.Write($Token)
    $_streamWriter.Flush()
    $_memoryStream.Position = 0

    $tokenHash = Get-FileHash -InputStream $_memoryStream | Select-Object -ExpandProperty Hash

    $_streamWriter.DisposeAsync() 1> $null
    $_memoryStream.DisposeAsync() 1> $null

    if (-not (Initialize-Folder -FolderPath $script:TokenValidationCache)) { return $false }
    $cachedToken = Get-ChildItem -Path $script:TokenValidationCache -Filter $tokenHash -ErrorAction SilentlyContinue

    if ($cachedToken) {
        $cachedTokenAge = (Get-Date) - $cachedToken.LastWriteTime | Select-Object -ExpandProperty TotalDays
        $cachedTokenAge = [Math]::Round($cachedTokenAge, 2)
        $cacheIsExpired = $cachedTokenAge -ge $script:CachedTokenExpiration
        $cachedTokenContent = (Get-Content $cachedToken -Raw).Trim()
        $cachedTokenIsEmpty = [string]::IsNullOrWhiteSpace($cachedTokenContent)

        if (!$cacheIsExpired -and !$cachedTokenIsEmpty) {
            $cachedExpirationForParsing = $cachedTokenContent.TrimEnd(' UTC')
            $cachedExpirationDate = [System.DateTime]::MinValue
            [System.DateTime]::TryParse($cachedExpirationForParsing, [ref]$cachedExpirationDate) | Out-Null

            $tokenExpirationDays = $cachedExpirationDate - (Get-Date) | Select-Object -ExpandProperty TotalDays
            $tokenExpirationDays = [Math]::Round($tokenExpirationDays, 2)

            if ($cachedExpirationForParsing -eq [System.DateTime]::MaxValue.ToLongDateString().Trim()) {
                return $true
            }

            if ($tokenExpirationDays -gt 0) {
                return $true
            } elseif ($cachedExpirationDate -eq [System.DateTime]::MinValue) {
                Invoke-FileCleanup -FilePaths $cachedToken.FullName
            } else {
                return $false
            }
        } else {
            Invoke-FileCleanup -FilePaths $cachedToken.FullName
        }
    }

    $requestParameters = @{
        Uri            = 'https://api.github.com/rate_limit'
        Authentication = 'Bearer'
        Token          = $(ConvertTo-SecureString "$Token" -AsPlainText)
        ErrorAction    = 'Stop'
    }

    $apiResponse = Invoke-WebRequest @requestParameters
    $rateLimit = @($apiResponse.Headers['X-RateLimit-Limit'])
    $tokenExpiration = @($apiResponse.Headers['github-authentication-token-expiration'])

    if (!$rateLimit) { return $false }
    if ([int]$rateLimit[0] -le 60) {
        return $false
    }

    $tokenExpiration = $tokenExpiration[0] -replace '[^0-9]+$', ''
    if (!$tokenExpiration -or [string]::IsNullOrWhiteSpace($tokenExpiration)) {
        $tokenExpiration = [System.DateTime]::MaxValue
    }
    if ([DateTime]::TryParse($tokenExpiration, [ref]$tokenExpiration)) {
        $null = $tokenExpiration
    } else {
        $tokenExpiration = [System.DateTime]::MinValue
    }

    $tokenExpiration = $tokenExpiration.ToString()
    New-Item -ItemType File -Path $script:TokenValidationCache -Name $tokenHash -Value $tokenExpiration -Force | Out-Null
    return $true
}

function Invoke-GitHubRequest {
    param (
        [Parameter(Mandatory = $true)]
        [string] $Uri
    )

    $requestUri = $Uri
    if ($requestUri -notmatch '^https?://') {
        if (-not $requestUri.StartsWith('/')) {
            $requestUri = "/$requestUri"
        }
        $requestUri = "$script:GitHubApiBaseUri$requestUri"
    }

    $requestParameters = @{
        Uri         = $requestUri
        UseBasicParsing = $true
        ErrorAction = 'Stop'
    }

    $hasValidToken = $false
    if (-not [string]::IsNullOrWhiteSpace($script:GitHubToken)) {
        try {
            $hasValidToken = Test-GithubToken -Token $script:GitHubToken
        } catch {
            $hasValidToken = $false
        }
    }

    if ($hasValidToken) {
        $requestParameters.Headers = @{
            Authorization = "Bearer $($script:GitHubToken)"
        }
    }

    try {
        return Invoke-WebRequest @requestParameters
    } catch {
        if ($hasValidToken) {
            $requestParameters.Remove('Headers')
            return Invoke-WebRequest @requestParameters
        }
        throw
    }
}

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

function Find-PullRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PackageIdentifier,

        [Parameter(Mandatory = $true)]
        [string] $PackageVersion
    )

    try {
        $manifestPath = '{0}/{1}' -f ($PackageIdentifier -replace '\.', '/'), $PackageVersion
        $searchTerms = @(
            'repo:microsoft/winget-pkgs'
            'is:pr'
            $manifestPath
            'in:path'
        )
        $query = [System.Uri]::EscapeDataString(($searchTerms -join ' '))
        $uri = "/search/issues?q=$query&per_page=1"

        $webResponse = Invoke-GitHubRequest -Uri $uri
        $response = @($webResponse.Content | ConvertFrom-Json)[0]
        return $response
    } catch {
        return $null
    }
}

function Get-PrTemplate {
    try {
        $contentsApiUrl = '/repos/microsoft/winget-pkgs/contents/.github/PULL_REQUEST_TEMPLATE.md?ref=master'
        $templateResponse = Invoke-GitHubRequest -Uri $contentsApiUrl
        if ($templateResponse) {
            $templateFile = $templateResponse.Content | ConvertFrom-Json
            if ($templateFile.content) {
                $encodedContent = ($templateFile.content -replace '\s', '')
                return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encodedContent))
            }
            Write-Warning 'PR template response did not include file content'
            return $null
        } else {
            Write-Warning 'Could not fetch PR template from upstream remote'
            return $null
        }
    } catch {
        Write-Warning "Could not fetch PR template from upstream remote: $_"
        return $null
    }
}

# Export module variables and functions
Export-ModuleMember -Variable 'wingetUpstream' -Function @('Get-Remote', 'Set-Remote', 'Find-PullRequest', 'Get-PrTemplate')
