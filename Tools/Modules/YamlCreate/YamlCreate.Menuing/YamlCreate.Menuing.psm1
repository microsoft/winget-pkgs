[ConsoleKey[]] $Numeric0 = @( [System.ConsoleKey]::D0; [System.ConsoleKey]::NumPad0 ); $Numeric0 | Out-Null
[ConsoleKey[]] $Numeric1 = @( [System.ConsoleKey]::D1; [System.ConsoleKey]::NumPad1 ); $Numeric1 | Out-Null
[ConsoleKey[]] $Numeric2 = @( [System.ConsoleKey]::D2; [System.ConsoleKey]::NumPad2 ); $Numeric2 | Out-Null
[ConsoleKey[]] $Numeric3 = @( [System.ConsoleKey]::D3; [System.ConsoleKey]::NumPad3 ); $Numeric3 | Out-Null
[ConsoleKey[]] $Numeric4 = @( [System.ConsoleKey]::D4; [System.ConsoleKey]::NumPad4 ); $Numeric4 | Out-Null
[ConsoleKey[]] $Numeric5 = @( [System.ConsoleKey]::D5; [System.ConsoleKey]::NumPad5 ); $Numeric5 | Out-Null
[ConsoleKey[]] $Numeric6 = @( [System.ConsoleKey]::D6; [System.ConsoleKey]::NumPad6 ); $Numeric6 | Out-Null
[ConsoleKey[]] $Numeric7 = @( [System.ConsoleKey]::D7; [System.ConsoleKey]::NumPad7 ); $Numeric7 | Out-Null
[ConsoleKey[]] $Numeric8 = @( [System.ConsoleKey]::D8; [System.ConsoleKey]::NumPad8 ); $Numeric8 | Out-Null
[ConsoleKey[]] $Numeric9 = @( [System.ConsoleKey]::D9; [System.ConsoleKey]::NumPad9 ); $Numeric9 | Out-Null

####
# Description: Waits for the user to press a key
# Inputs: Boolean for whether to echo the key value to the console
# Outputs: Key which was pressed
####
function Get-Keypress {
    param (
        [Parameter(Mandatory = $false)]
        [bool] $EchoKey = $false
    )

    do {
        $keyInfo = [Console]::ReadKey(!$EchoKey)
    } until ($keyInfo.Key)
    return $keyInfo.Key
}

####
# Description: Waits for a valid keypress from the user
# Inputs: List of valid keys, Default key to return, Boolean for strict mode
# Outputs: Key which was pressed
####
function Resolve-Keypress {
    param (
        [Parameter(Mandatory = $true)]
        [System.ConsoleKey[]] $ValidKeys,
        [Parameter(Mandatory = $true)]
        [System.ConsoleKey] $DefaultKey,
        [Parameter(Mandatory = $false)]
        [bool] $UseStrict = $false
    )

    do {
        # Get a keypress
        $key = Get-Keypress -EchoKey $false

        # If the key pressed is in the valid keys, it doesn't matter if strict mode is enabled or not
        if ($ValidKeys -contains $key) {
            return $key
        }

        # If the key pressed is the default key, it doesn't matter if strict mode is enabled or not
        if ($key -eq $DefaultKey) {
            return $key
        }

        if (!$UseStrict) {
            # The key pressed is not in the valid keys, is not the default key, and strict mode is not enabled
            # Since strict mode is not enabled, we will return the default key
            return $DefaultKey
        }

        # If we reach here, the key pressed is not in the valid keys, is not the default key, and strict mode is enabled
        # We will inform the user that the key pressed is invalid and prompt them to press a valid key
        Write-Information @"
${vtForegroundRed}Invalid key pressed. Please press one of the valid keys: $($ValidKeys -join ', ')
${vtForegroundDefault}
"@

    } while ( $true ) # Loop until a valid key is pressed

    return $DefaultKey # This line is never reached, but it's here for completeness
}

Export-ModuleMember -Function Get-Keypress
Export-ModuleMember -Function Resolve-Keypress
Export-ModuleMember -Variable Numeric*
