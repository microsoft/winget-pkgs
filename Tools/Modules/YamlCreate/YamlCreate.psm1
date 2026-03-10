
# Import all sub-modules
$script:moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Get-ChildItem -Path $script:moduleRoot -Recurse -Depth 1 -Filter '*.psd1'| ForEach-Object {
    if ($_.Name -eq 'YamlCreate.psd1') {
        # Skip the main module manifest as it is already handled
        return
    }
    $moduleFolder = Join-Path -Path $script:moduleRoot -ChildPath $_.Directory.Name
    $moduleFile = Join-Path -Path $moduleFolder -ChildPath $_.Name
    Import-Module $moduleFile -Force -Scope Global -ErrorAction 'Stop'
}
