# YamlCreate.InstallerDetection Tests

This directory contains Pester tests for the YamlCreate.InstallerDetection PowerShell module.

## Overview

The test suite validates the functionality of the installer detection module, which provides functions to:
- Parse PE file structures
- Detect various installer types (ZIP, MSIX, MSI, WIX, Nullsoft, Inno, Burn)
- Identify font files
- Resolve installer types from file paths

## Running the Tests

### Prerequisites

- PowerShell 7.0 or later
- Pester 5.x (included with PowerShell 7+)

### Run All Tests

From the module directory, run:

```powershell
Invoke-Pester -Path ./YamlCreate.InstallerDetection.Tests.ps1
```

### Run Tests with Detailed Output

For more detailed test output:

```powershell
Invoke-Pester -Path ./YamlCreate.InstallerDetection.Tests.ps1 -Output Detailed
```

### Run Tests with Code Coverage

To see code coverage metrics:

```powershell
Invoke-Pester -Path ./YamlCreate.InstallerDetection.Tests.ps1 -CodeCoverage ./YamlCreate.InstallerDetection.psm1
```

## Test Structure

The test suite is organized into the following sections:

### Module Tests
- Module import validation
- Exported functions verification

### Function Tests
- **Get-OffsetBytes**: Tests for byte array extraction with various offsets and endianness
- **Get-PESectionTable**: Tests for PE file parsing
- **Test-IsZip**: Tests for ZIP file detection
- **Test-IsMsix**: Tests for MSIX/APPX detection
- **Test-IsMsi**: Tests for MSI installer detection
- **Test-IsWix**: Tests for WIX installer detection
- **Test-IsNullsoft**: Tests for Nullsoft installer detection
- **Test-IsInno**: Tests for Inno Setup installer detection
- **Test-IsBurn**: Tests for Burn installer detection
- **Test-IsFont**: Tests for font file detection (TTF, OTF, TTC)
- **Resolve-InstallerType**: Tests for the main installer type resolution function

## Known Limitations

Some tests are skipped due to complexity or external dependencies:

1. **ZIP Archive Tests**: Tests that require complete valid ZIP archives are skipped as they would need complex ZIP structure generation
2. **PE File Tests**: Some PE-related tests are skipped when they would require reading non-existent files
3. **External Dependencies**: The module relies on external commands (`Get-MSITable`, `Get-MSIProperty`, `Get-Win32ModuleResource`) that are stubbed in the test environment

## Test Coverage

Current test coverage includes:
- 32 passing tests
- 3 skipped tests (require complex setup)
- Covers all 11 exported functions
- Tests both positive and negative scenarios
- Validates edge cases and error handling

## Contributing

When adding new functions to the module:
1. Add corresponding tests to `YamlCreate.InstallerDetection.Tests.ps1`
2. Follow the existing test structure (Describe → Context → It blocks)
3. Use descriptive test names that explain what is being tested
4. Include both positive and negative test cases
5. Clean up any temporary files created during tests

## Additional Resources

- [Pester Documentation](https://pester.dev/)
- [PowerShell Testing Best Practices](https://pester.dev/docs/usage/test-file-structure)
