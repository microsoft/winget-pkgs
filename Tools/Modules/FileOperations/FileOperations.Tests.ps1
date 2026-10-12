Describe 'FileOperations Module' {
    BeforeAll {
        $ModulePath = Split-Path -Parent $PSCommandPath
        Import-Module (Join-Path $ModulePath 'FileOperations.psd1') -Force
    }

    Context 'Module Import' {
        It 'Should import the module successfully' {
            Get-Module 'FileOperations' | Should -Not -BeNullOrEmpty
        }

        It 'Should export all expected functions' {
            $ExportedFunctions = (Get-Module 'FileOperations').ExportedFunctions.Keys
            'Initialize-Folder' -in $ExportedFunctions | Should -Be $true
            'Invoke-FileCleanup' -in $ExportedFunctions | Should -Be $true
            'Request-RemoveItem' -in $ExportedFunctions | Should -Be $true
        }
    }
}

Describe 'Initialize-Folder' {
    It 'Should create a folder and return true when it does not exist' {
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
        $targetFolder = Join-Path -Path $tempRoot -ChildPath 'created'

        try {
            $result = Initialize-Folder -FolderPath $targetFolder
            $result | Should -Be $true
            (Test-Path -Path $targetFolder -PathType Container) | Should -Be $true
        } finally {
            if (Test-Path -Path $tempRoot) { Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    It 'Should return true for an existing folder' {
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
        New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null

        try {
            $result = Initialize-Folder -FolderPath $tempRoot
            $result | Should -Be $true
        } finally {
            if (Test-Path -Path $tempRoot) { Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    It 'Should return false when a file exists at the folder path' {
        $tempFile = New-TemporaryFile

        try {
            $result = Initialize-Folder -FolderPath $tempFile.FullName
            $result | Should -Be $false
        } finally {
            if (Test-Path -Path $tempFile.FullName) { Remove-Item -Path $tempFile.FullName -Force -ErrorAction SilentlyContinue }
        }
    }
}

Describe 'Request-RemoveItem' {
    It 'Should remove a file path' {
        $tempFile = New-TemporaryFile
        Request-RemoveItem -Path $tempFile.FullName
        (Test-Path -Path $tempFile.FullName) | Should -Be $false
    }

    It 'Should remove a directory path recursively' {
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
        $nestedFolder = Join-Path -Path $tempRoot -ChildPath 'nested'
        $nestedFile = Join-Path -Path $nestedFolder -ChildPath 'payload.txt'
        New-Item -Path $nestedFolder -ItemType Directory -Force | Out-Null
        Set-Content -Path $nestedFile -Value 'payload'

        Request-RemoveItem -Path $tempRoot
        (Test-Path -Path $tempRoot) | Should -Be $false
    }

    It 'Should be a no-op when path does not exist' {
        $missingPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
        { Request-RemoveItem -Path $missingPath } | Should -Not -Throw
    }
}

Describe 'Invoke-FileCleanup' {
    It 'Should remove files and folders in the provided list' {
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
        $tempFolder = Join-Path -Path $tempRoot -ChildPath 'cleanup'
        $tempFile = Join-Path -Path $tempRoot -ChildPath 'file.txt'
        New-Item -Path $tempFolder -ItemType Directory -Force | Out-Null
        New-Item -Path $tempFile -ItemType File -Force | Out-Null

        Invoke-FileCleanup -FilePaths @($tempFolder, $tempFile)

        (Test-Path -Path $tempFolder) | Should -Be $false
        (Test-Path -Path $tempFile) | Should -Be $false

        if (Test-Path -Path $tempRoot) { Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'Should not throw when file list is empty' {
        { Invoke-FileCleanup -FilePaths @() } | Should -Not -Throw
    }

    It 'Should not throw when file list contains missing paths' {
        $missingPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
        { Invoke-FileCleanup -FilePaths @($missingPath) } | Should -Not -Throw
    }
}
