####
# Description: Returns the values from the Properties menu of a file
# Inputs: Path to file
# Outputs: Dictonary of properties
####
function Get-FileMetadata {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return
    }

    $shell = New-Object -ComObject Shell.Application
    $folder = $shell.Namespace((Split-Path $FilePath))
    $file = $folder.ParseName((Split-Path $FilePath -Leaf))

    [PSCustomObject] $metadata = @{}

    for ($i = 0; $i -lt 400; $i++) {
        $key = $folder.GetDetailsOf($folder.Items, $i)
        $value = $folder.GetDetailsOf($file, $i)

        if ($key -and $value) {
            $metadata[$key] = $value
        }
    }

    # Clean up COM objects
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($file) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($folder) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null

    return $metadata
}

####
# Description: Gets the specified bytes from a byte array
# Inputs: Array of Bytes, Integer offset, Integer Length
# Outputs: Array of bytes
####
function Get-OffsetBytes {
    param (
        [Parameter(Mandatory = $true)]
        [byte[]] $ByteArray,
        [Parameter(Mandatory = $true)]
        [int] $Offset,
        [Parameter(Mandatory = $true)]
        [int] $Length,
        [Parameter(Mandatory = $false)]
        [bool] $LittleEndian = $false # Bool instead of a switch for use with other functions
    )

    if ($Offset -gt $ByteArray.Length) { return @() } # Prevent null exceptions
    $Start = if ($LittleEndian) { $Offset + $Length - 1 } else { $Offset }
    $End = if ($LittleEndian) { $Offset } else { $Offset + $Length - 1 }
    return $ByteArray[$Start..$End]
}

####
# Description: Gets the PE Section Table of a file
# Inputs: Path to File
# Outputs: Array of Object if valid PE file, null otherwise
####
function Get-PESectionTable {
    # TODO: Switch to using FileReader to be able to seek through the file instead of reading from the start
    param
    (
        [Parameter(Mandatory = $true)]
        [String] $Path
    )
    # https://learn.microsoft.com/en-us/windows/win32/debug/pe-format
    # The first 64 bytes of the file contain the DOS header. The first two bytes are the "MZ" signature, and the 60th byte contains the offset to the PE header.
    $DOSHeader = Get-Content -Path $Path -AsByteStream -TotalCount 64 -WarningAction 'SilentlyContinue'
    $MZSignature = Get-OffsetBytes -ByteArray $DOSHeader -Offset 0 -Length 2
    if (Compare-Object -ReferenceObject $([byte[]](0x4D, 0x5A)) -DifferenceObject $MZSignature ) { return $null } # The MZ signature is invalid
    $PESignatureOffsetBytes = Get-OffsetBytes -ByteArray $DOSHeader -Offset 60 -Length 4
    $PESignatureOffset = [BitConverter]::ToInt32($PESignatureOffsetBytes, 0)

    # These are known sizes
    $PESignatureSize = 4 # Bytes
    $COFFHeaderSize = 20 # Bytes
    $SectionTableEntrySize = 40 # Bytes

    # Read 24 bytes past the PE header offset to get the PE Signature and COFF header
    $RawBytes = Get-Content -Path $Path -AsByteStream -TotalCount $($PESignatureOffset + $PESignatureSize + $COFFHeaderSize) -WarningAction 'SilentlyContinue'
    $PESignature = Get-OffsetBytes -ByteArray $RawBytes -Offset $PESignatureOffset -Length $PESignatureSize
    if (Compare-Object -ReferenceObject $([byte[]](0x50, 0x45, 0x00, 0x00)) -DifferenceObject $PESignature ) { return $null } # The PE header is invalid if it is not 'PE\0\0'

    # Parse out information from the header
    $COFFHeaderBytes = Get-OffsetBytes -ByteArray $RawBytes -Offset $($PESignatureOffset + $PESignatureSize) -Length $COFFHeaderSize
    $MachineTypeBytes = Get-OffsetBytes -ByteArray $COFFHeaderBytes -Offset 0 -Length 2
    $NumberOfSectionsBytes = Get-OffsetBytes -ByteArray $COFFHeaderBytes -Offset 2 -Length 2
    $TimeDateStampBytes = Get-OffsetBytes -ByteArray $COFFHeaderBytes -Offset 4 -Length 4
    $PointerToSymbolTableBytes = Get-OffsetBytes -ByteArray $COFFHeaderBytes -Offset 8 -Length 4
    $NumberOfSymbolsBytes = Get-OffsetBytes -ByteArray $COFFHeaderBytes -Offset 12 -Length 4
    $SizeOfOptionalHeaderBytes = Get-OffsetBytes -ByteArray $COFFHeaderBytes -Offset 16 -Length 2
    $HeaderCharacteristicsBytes = Get-OffsetBytes -ByteArray $COFFHeaderBytes -Offset 18 -Length 2

    # Convert the data into real numbers
    $NumberOfSections = [BitConverter]::ToInt16($NumberOfSectionsBytes, 0)
    $TimeDateStamp = [BitConverter]::ToInt32($TimeDateStampBytes, 0)
    $SymbolTableOffset = [BitConverter]::ToInt32($PointerToSymbolTableBytes, 0)
    $NumberOfSymbols = [BitConverter]::ToInt32($NumberOfSymbolsBytes, 0)
    $OptionalHeaderSize = [BitConverter]::ToInt16($SizeOfOptionalHeaderBytes, 0)

    # Read the section table from the file
    $SectionTableStart = $PESignatureOffset + $PESignatureSize + $COFFHeaderSize + $OptionalHeaderSize
    $SectionTableLength = $NumberOfSections * $SectionTableEntrySize
    $RawBytes = Get-Content -Path $Path -AsByteStream -TotalCount $($SectionTableStart + $SectionTableLength) -WarningAction 'SilentlyContinue'
    $SectionTableContents = Get-OffsetBytes -ByteArray $RawBytes -Offset $SectionTableStart -Length $SectionTableLength

    $SectionData = @();
    # Parse each of the sections
    foreach ($Section in 0..$($NumberOfSections - 1)) {
        $SectionTableEntry = Get-OffsetBytes -ByteArray $SectionTableContents -Offset ($Section * $SectionTableEntrySize) -Length $SectionTableEntrySize

        # Get the raw bytes
        $SectionNameBytes = Get-OffsetBytes -ByteArray $SectionTableEntry -Offset 0 -Length 8
        $VirtualSizeBytes = Get-OffsetBytes -ByteArray $SectionTableEntry -Offset 8 -Length 4
        $VirtualAddressBytes = Get-OffsetBytes -ByteArray $SectionTableEntry -Offset 12 -Length 4
        $SizeOfRawDataBytes = Get-OffsetBytes -ByteArray $SectionTableEntry -Offset 16 -Length 4
        $PointerToRawDataBytes = Get-OffsetBytes -ByteArray $SectionTableEntry -Offset 20 -Length 4
        $PointerToRelocationsBytes = Get-OffsetBytes -ByteArray $SectionTableEntry -Offset 24 -Length 4
        $PointerToLineNumbersBytes = Get-OffsetBytes -ByteArray $SectionTableEntry -Offset 28 -Length 4
        $NumberOfRelocationsBytes = Get-OffsetBytes -ByteArray $SectionTableEntry -Offset 32 -Length 2
        $NumberOfLineNumbersBytes = Get-OffsetBytes -ByteArray $SectionTableEntry -Offset 34 -Length 2
        $SectionCharacteristicsBytes = Get-OffsetBytes -ByteArray $SectionTableEntry -Offset 36 -Length 4

        # Convert the data into real values
        $SectionName = [Text.Encoding]::UTF8.GetString($SectionNameBytes)
        $VirtualSize = [BitConverter]::ToInt32($VirtualSizeBytes, 0)
        $VirtualAddressOffset = [BitConverter]::ToInt32($VirtualAddressBytes, 0)
        $SizeOfRawData = [BitConverter]::ToInt32($SizeOfRawDataBytes, 0)
        $RawDataOffset = [BitConverter]::ToInt32($PointerToRawDataBytes, 0)
        $RelocationsOffset = [BitConverter]::ToInt32($PointerToRelocationsBytes, 0)
        $LineNumbersOffset = [BitConverter]::ToInt32($PointerToLineNumbersBytes, 0)
        $NumberOfRelocations = [BitConverter]::ToInt16($NumberOfRelocationsBytes, 0)
        $NumberOfLineNumbers = [BitConverter]::ToInt16($NumberOfLineNumbersBytes, 0)

        # Build the object
        $SectionEntry = [PSCustomObject]@{
            SectionName                 = $SectionName
            SectionNameBytes            = $SectionNameBytes
            VirtualSize                 = $VirtualSize
            VirtualAddressOffset        = $VirtualAddressOffset
            SizeOfRawData               = $SizeOfRawData
            RawDataOffset               = $RawDataOffset
            RelocationsOffset           = $RelocationsOffset
            LineNumbersOffset           = $LineNumbersOffset
            NumberOfRelocations         = $NumberOfRelocations
            NumberOfLineNumbers         = $NumberOfLineNumbers
            SectionCharacteristicsBytes = $SectionCharacteristicsBytes
        }
        # Add the section to the output
        $SectionData += $SectionEntry
    }

    return $SectionData
}

####
# Description: Checks if a file is a Zip archive
# Inputs: Path to File
# Outputs: Boolean. True if file is a zip file, false otherwise
# Note: This function does not differentiate between other Zipped installer types. Any specific types like MSIX still result in an Zip file.
#       Use this function with care, as it may return overly broad results.
####
function Test-IsZip {
    param
    (
        [Parameter(Mandatory = $true)]
        [String] $Path
    )

    # The first 4 bytes of zip files are the same.
    # It isn't worth setting up a FileStream and BinaryReader here since only the first 4 bytes are being checked
    # https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT section 4.3.7
    $ZipHeader = Get-Content -Path $Path -AsByteStream -TotalCount 4 -WarningAction 'SilentlyContinue'
    return $null -eq $(Compare-Object -ReferenceObject $([byte[]](0x50, 0x4B, 0x03, 0x04)) -DifferenceObject $ZipHeader)
}

####
# Description: Checks if a file is an MSIX or APPX archive
# Inputs: Path to File
# Outputs: Boolean. True if file is a MSIX or APPX file, false otherwise
####
function Test-IsMsix {
    param
    (
        [Parameter(Mandatory = $true)]
        [String] $Path
    )
    if (!(Test-IsZip -Path $Path)) { return $false } # MSIX are really just a special type of Zip file
    Write-Debug 'Extracting file contents as a zip archive'
    $FileObject = Get-Item -Path $Path
    $temporaryFilePath = Join-Path -Path $env:TEMP -ChildPath "$($FileObject.BaseName).zip" # Expand-Archive only works if the file is a zip file
    $expandedArchivePath = Join-Path -Path $env:TEMP -ChildPath $(New-Guid)
    Copy-Item -Path $Path -Destination $temporaryFilePath
    Expand-Archive -Path $temporaryFilePath -DestinationPath $expandedArchivePath

    # There are a few different indicators that a package can be installed with MSIX technology, look for any of these file names
    $msixIndicators = @('AppxSignature.p7x'; 'AppxManifest.xml'; 'AppxBundleManifest.xml', 'AppxBlockMap.xml')
    $returnValue = $false
    foreach ($filename in $msixIndicators) {
        if (Get-ChildItem -Path $expandedArchivePath -Recurse -Depth 3 -Filter $filename) { $returnValue = $true } # If any of the files is found, it is an msix
    }

    # Cleanup the temporary files right away
    Write-Debug 'Removing extracted files'
    if (Test-Path $temporaryFilePath) { Remove-Item -Path $temporaryFilePath -Recurse }
    if (Test-Path $expandedArchivePath) { Remove-Item -Path $expandedArchivePath -Recurse }

    return $returnValue
}

####
# Description: Checks if a file is an MSI installer
# Inputs: Path to File
# Outputs: Boolean. True if file is an MSI installer, false otherwise
# Note: This function does not differentiate between MSI installer types. Any specific packagers like WIX still result in an MSI installer.
#       Use this function with care, as it may return overly broad results.
####
function Test-IsMsi {
    param
    (
        [Parameter(Mandatory = $true)]
        [String] $Path
    )

    $MsiTables = Get-MSITable -Path $Path -ErrorAction SilentlyContinue
    if ($MsiTables) { return $true }
    # If the table names can't be parsed, it is not an MSI
    return $false
}

####
# Description: Checks if a file is a WIX installer
# Inputs: Path to File
# Outputs: Boolean. True if file is a WIX installer, false otherwise
####
function Test-IsWix {
    param
    (
        [Parameter(Mandatory = $true)]
        [String] $Path
    )

    $MsiTables = Get-MSITable -Path $Path -ErrorAction SilentlyContinue
    if (!$MsiTables) { return $false } # If the table names can't be parsed, it is not an MSI and cannot be WIX
    if ($MsiTables.Where({ $_.Table -match 'wix' })) { return $true } # If any of the table names match wix
    if (Get-MSIProperty -Path $Path -Property '*wix*' -ErrorAction SilentlyContinue) { return $true } # If any of the keys in the property table match wix

    # If we reach here, the metadata has to be checked to see if it is a WIX installer
    $FileMetadata = Get-FileMetadata -FilePath $Path

    # Check the created by program name matches WIX or XML, it is likely a WIX installer
    if ($FileMetadata.ContainsKey('Program Name') -and $FileMetadata.'Program Name' -match 'WIX|XML') {
        return $true
    }

    return $false # If none of the checks matched, it is not a WIX installer
}

####
# Description: Checks if a file is a Nullsoft installer
# Inputs: Path to File
# Outputs: Boolean. True if file is a Nullsoft installer, false otherwise
####
function Test-IsNullsoft {
    param
    (
        [Parameter(Mandatory = $true)]
        [String] $Path
    )
    $SectionTable = Get-PESectionTable -Path $Path
    if (!$SectionTable) { return $false } # If the section table is null, it is not an EXE and therefore not nullsoft
    $LastSection = $SectionTable | Sort-Object -Property RawDataOffset -Descending | Select-Object -First 1
    $PEOverlayOffset = $LastSection.RawDataOffset + $LastSection.SizeOfRawData

    try {
        # Set up a file reader
        $fileStream = [System.IO.FileStream]::new($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
        $binaryReader = [System.IO.BinaryReader]::new($fileStream)
        # Read 8 bytes after the offset
        $fileStream.Seek($PEOverlayOffset, [System.IO.SeekOrigin]::Begin) | Out-Null
        $RawBytes = $binaryReader.ReadBytes(8)
    } catch {
        # Set to null as a precaution
        $RawBytes = $null
    } finally {
        if ($binaryReader) { $binaryReader.Close() }
        if ($fileStream) { $fileStream.Close() }
    }
    if (!$RawBytes) { return $false } # The bytes couldn't be read
    # From the first 8 bytes, get the Nullsoft header bytes
    $PresumedHeaderBytes = Get-OffsetBytes -ByteArray $RawBytes -Offset 4 -Length 4 -LittleEndian $true

    # DEADBEEF -or- DEADBEED
    # https://sourceforge.net/p/nsis/code/HEAD/tree/NSIS/branches/WIN64/Source/exehead/fileform.h#l222
    if (!(Compare-Object -ReferenceObject $([byte[]](0xDE, 0xAD, 0xBE, 0xEF)) -DifferenceObject $PresumedHeaderBytes)) { return $true }
    if (!(Compare-Object -ReferenceObject $([byte[]](0xDE, 0xAD, 0xBE, 0xED)) -DifferenceObject $PresumedHeaderBytes)) { return $true }
    return $false
}

####
# Description: Checks if a file is an Inno installer
# Inputs: Path to File
# Outputs: Boolean. True if file is an Inno installer, false otherwise
####
function Test-IsInno {
    param
    (
        [Parameter(Mandatory = $true)]
        [String] $Path
    )

    $Resources = Get-Win32ModuleResource -Path $Path -DontLoadResource -ErrorAction SilentlyContinue
    # https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Shared.Struct.pas#L417
    if ($Resources.Name.Value -contains '#11111') { return $true } # If the resource name is #11111, it is an Inno installer
    return $false
}

####
# Description: Checks if a file is a Burn installer
# Inputs: Path to File
# Outputs: Boolean. True if file is an Burn installer, false otherwise
####
function Test-IsBurn {
    param
    (
        [Parameter(Mandatory = $true)]
        [String] $Path
    )

    $SectionTable = Get-PESectionTable -Path $Path
    if (!$SectionTable) { return $false } # If the section table is null, it is not an EXE and therefore not Burn
    # https://github.com/wixtoolset/wix/blob/main/src/burn/engine/inc/engine.h#L8
    if ($SectionTable.SectionName -contains '.wixburn') { return $true }
    return $false
}

####
# Description: Checks if a file is a font which WinGet can install
# Inputs: Path to File
# Outputs: Boolean. True if file is a supported font, false otherwise
# Note: Supported font formats are TTF, TTC, and OTF
####
function Test-IsFont {
    param
    (
        [Parameter(Mandatory = $true)]
        [String] $Path
    )

    # https://learn.microsoft.com/en-us/typography/opentype/spec/otff#organization-of-an-opentype-font
    $TrueTypeFontSignature = [byte[]](0x00, 0x01, 0x00, 0x00) # The first 4 bytes of a TTF file
    $OpenTypeFontSignature = [byte[]](0x4F, 0x54, 0x54, 0x4F) # The first 4 bytes of an OTF file
    # https://learn.microsoft.com/en-us/typography/opentype/spec/otff#ttc-header
    $TrueTypeCollectionSignature = [byte[]](0x74, 0x74, 0x63, 0x66) # The first 4 bytes of a TTC file

    $FontSignatures = @(
        $TrueTypeFontSignature,
        $OpenTypeFontSignature,
        $TrueTypeCollectionSignature
    )

    # It isn't worth setting up a FileStream and BinaryReader here since only the first 4 bytes are being checked
    $FontHeader = Get-Content -Path $Path -AsByteStream -TotalCount 4 -WarningAction 'SilentlyContinue'
    return $($FontSignatures | ForEach-Object { !(Compare-Object -ReferenceObject $_ -DifferenceObject $FontHeader) }) -contains $true # If any of the signatures match, it is a font

}

####
# Description: Attempts to identify the type of installer from a file path
# Inputs: Path to File
# Outputs: Null if unknown type. String if known type
####
function Resolve-InstallerType {
    param
    (
        [Parameter(Mandatory = $true)]
        [String] $Path
    )

    # Ordering is important here due to the specificity achievable by each of the detection methods
    # if (Test-IsFont -Path $Path) { return 'font' } # Font detection is not implemented yet
    if (Test-IsWix -Path $Path) { return 'wix' }
    if (Test-IsMsi -Path $Path) { return 'msi' }
    if (Test-IsMsix -Path $Path) { return 'msix' }
    if (Test-IsZip -Path $Path) { return 'zip' }
    if (Test-IsNullsoft -Path $Path) { return 'nullsoft' }
    if (Test-IsInno -Path $Path) { return 'inno' }
    if (Test-IsBurn -Path $Path) { return 'burn' }
    return $null
}

Export-ModuleMember -Function Get-OffsetBytes
Export-ModuleMember -Function Get-PESectionTable
Export-ModuleMember -Function Test-IsZip
Export-ModuleMember -Function Test-IsMsix
Export-ModuleMember -Function Test-IsMsi
Export-ModuleMember -Function Test-IsWix
Export-ModuleMember -Function Test-IsNullsoft
Export-ModuleMember -Function Test-IsInno
Export-ModuleMember -Function Test-IsBurn
Export-ModuleMember -Function Test-IsFont
Export-ModuleMember -Function Resolve-InstallerType
