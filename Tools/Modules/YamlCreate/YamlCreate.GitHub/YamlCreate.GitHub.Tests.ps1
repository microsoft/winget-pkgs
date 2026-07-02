Describe 'YamlCreate.GitHub Module' {
    BeforeAll {
        # Import the module to test
        $ModulePath = Split-Path -Parent $PSCommandPath
        Import-Module (Join-Path $ModulePath 'YamlCreate.GitHub.psd1') -Force
    }

    Context 'Module Import' {
        It 'Should import the module successfully' {
            Get-Module 'YamlCreate.GitHub' | Should -Not -BeNullOrEmpty
        }

        It 'Should declare FileOperations as a required module dependency' {
            $ModulePath = Split-Path -Parent $PSCommandPath
            $manifest = Import-PowerShellDataFile -Path (Join-Path $ModulePath 'YamlCreate.GitHub.psd1')
            (@($manifest.RequiredModules) -contains 'FileOperations') | Should -Be $true
        }

        It 'Should export all expected functions' {
            $ExportedFunctions = (Get-Module 'YamlCreate.GitHub').ExportedFunctions.Keys
            'Get-Remote' -in $ExportedFunctions | Should -Be $true
            'Set-Remote' -in $ExportedFunctions | Should -Be $true
            'Find-PullRequest' -in $ExportedFunctions | Should -Be $true
            'Get-PrTemplate' -in $ExportedFunctions | Should -Be $true
        }
    }

    Context 'wingetUpstream Variable' {
        It 'Should have correct value for wingetUpstream' {
            $wingetUpstream | Should -Be 'https://github.com/microsoft/winget-pkgs.git'
        }
    }

    Context 'Get-Remote Function' {
        It 'Should return $null for non-existent remote' {
            $result = Get-Remote -RemoteName 'nonexistent-remote-xyz'
            $result | Should -BeNullOrEmpty
        }

        It 'Should accept RemoteName parameter' {
            { Get-Remote -RemoteName 'origin' } | Should -Not -Throw
        }
    }

    Context 'Set-Remote Function' {
        It 'Should accept RemoteName and Url parameters' {
            { Set-Remote -RemoteName 'test' -Url 'https://example.com/test.git' } | Should -Not -Throw
        }

        It 'Should return boolean result' {
            $result = Set-Remote -RemoteName 'test' -Url 'https://example.com/test.git'
            ($result -is [System.Boolean]) | Should -Be $true
        }
    }

    Context 'Find-PullRequest Function' {
        It 'Should accept PackageIdentifier and PackageVersion parameters' {
            { Find-PullRequest -PackageIdentifier 'Test.Package' -PackageVersion '1.0.0' } | Should -Not -Throw
        }

        It 'Should handle web request errors gracefully' {
            { Find-PullRequest -PackageIdentifier 'Invalid...Package' -PackageVersion '1.0.0' } | Should -Not -Throw
        }
    }

    Context 'Get-PrTemplate Function' {
        It 'Should not throw when called' {
            { Get-PrTemplate } | Should -Not -Throw
        }

        It 'Should return string or null' {
            $result = Get-PrTemplate
            (($result -is [string]) -or ($result -eq $null)) | Should -Be $true
        }

        It 'Should handle web request failures gracefully' {
            { $result = Get-PrTemplate; $result } | Should -Not -Throw
        }
    }
}
