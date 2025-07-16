$vtSupported = (Get-Host).UI.SupportsVirtualTerminal

####
# Deglobalion: If Virtual Terminal is supported, convert the operation code to its virtual terminal sequence
# Inputs: Integer. Operation Code
# Outputs: Nullable Virtual Terminal Sequence String
####
filter Initialize-VirtualTerminalSequence {
  if ($vtSupported) {
    "$([char]0x001B)[${_}m"
  }
}

$vtBold = 1 | Initialize-VirtualTerminalSequence; $vtBold | Out-Null
$vtNotBold = 22 | Initialize-VirtualTerminalSequence; $vtNotBold | Out-Null
$vtUnderline = 4 | Initialize-VirtualTerminalSequence; $vtUnderline | Out-Null
$vtNotUnderline = 24 | Initialize-VirtualTerminalSequence; $vtNotUnderline | Out-Null
$vtNegative = 7 | Initialize-VirtualTerminalSequence; $vtNegative | Out-Null
$vtPositive = 27 | Initialize-VirtualTerminalSequence; $vtPositive | Out-Null
$vtForegroundBlack = 30 | Initialize-VirtualTerminalSequence; $vtForegroundBlack | Out-Null
$vtForegroundRed = 31 | Initialize-VirtualTerminalSequence; $vtForegroundRed | Out-Null
$vtForegroundGreen = 32 | Initialize-VirtualTerminalSequence; $vtForegroundGreen | Out-Null
$vtForegroundYellow = 33 | Initialize-VirtualTerminalSequence; $vtForegroundYellow | Out-Null
$vtForegroundBlue = 34 | Initialize-VirtualTerminalSequence; $vtForegroundBlue | Out-Null
$vtForegroundMagenta = 35 | Initialize-VirtualTerminalSequence; $vtForegroundMagenta | Out-Null
$vtForegroundCyan = 36 | Initialize-VirtualTerminalSequence; $vtForegroundCyan | Out-Null
$vtForegroundWhite = 37 | Initialize-VirtualTerminalSequence; $vtForegroundWhite | Out-Null
$vtForegroundDefault = 39 | Initialize-VirtualTerminalSequence; $vtForegroundDefault | Out-Null
$vtBackgroundBlack = 40 | Initialize-VirtualTerminalSequence; $vtBackgroundBlack | Out-Null
$vtBackgroundRed = 41 | Initialize-VirtualTerminalSequence; $vtBackgroundRed | Out-Null
$vtBackgroundGreen = 42 | Initialize-VirtualTerminalSequence; $vtBackgroundGreen | Out-Null
$vtBackgroundYellow = 43 | Initialize-VirtualTerminalSequence; $vtBackgroundYellow | Out-Null
$vtBackgroundBlue = 44 | Initialize-VirtualTerminalSequence; $vtBackgroundBlue | Out-Null
$vtBackgroundMagenta = 45 | Initialize-VirtualTerminalSequence; $vtBackgroundMagenta | Out-Null
$vtBackgroundCyan = 46 | Initialize-VirtualTerminalSequence; $vtBackgroundCyan | Out-Null
$vtBackgroundWhite = 47 | Initialize-VirtualTerminalSequence; $vtBackgroundWhite | Out-Null
$vtBackgroundDefault = 49 | Initialize-VirtualTerminalSequence; $vtBackgroundDefault | Out-Null
$vtForegroundBrightBlack = 90 | Initialize-VirtualTerminalSequence; $vtForegroundBrightBlack | Out-Null
$vtForegroundBrightRed = 91 | Initialize-VirtualTerminalSequence; $vtForegroundBrightRed | Out-Null
$vtForegroundBrightGreen = 92 | Initialize-VirtualTerminalSequence; $vtForegroundBrightGreen | Out-Null
$vtForegroundBrightYellow = 93 | Initialize-VirtualTerminalSequence; $vtForegroundBrightYellow | Out-Null
$vtForegroundBrightBlue = 94 | Initialize-VirtualTerminalSequence; $vtForegroundBrightBlue | Out-Null
$vtForegroundBrightMagenta = 95 | Initialize-VirtualTerminalSequence; $vtForegroundBrightMagenta | Out-Null
$vtForegroundBrightCyan = 96 | Initialize-VirtualTerminalSequence; $vtForegroundBrightCyan | Out-Null
$vtForegroundBrightWhite = 97 | Initialize-VirtualTerminalSequence; $vtForegroundBrightWhite | Out-Null
$vtBackgroundBrightRed = 101 | Initialize-VirtualTerminalSequence; $vtBackgroundBrightRed | Out-Null
$vtBackgroundBrightGreen = 102 | Initialize-VirtualTerminalSequence; $vtBackgroundBrightGreen | Out-Null
$vtBackgroundBrightYellow = 103 | Initialize-VirtualTerminalSequence; $vtBackgroundBrightYellow | Out-Null
$vtBackgroundBrightBlue = 104 | Initialize-VirtualTerminalSequence; $vtBackgroundBrightBlue | Out-Null
$vtBackgroundBrightMagenta = 105 | Initialize-VirtualTerminalSequence; $vtBackgroundBrightMagenta | Out-Null
$vtBackgroundBrightCyan = 106 | Initialize-VirtualTerminalSequence; $vtBackgroundBrightCyan | Out-Null
$vtBackgroundBrightWhite = 107 | Initialize-VirtualTerminalSequence; $vtBackgroundBrightWhite | Out-Null

Export-ModuleMember -Function Initialize-VirtualTerminalSequence
Export-ModuleMember -Variable *
