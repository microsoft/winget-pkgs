$ErrorActionPreference = 'Stop'

Get-Process 'Sucrose*' | % {
	Write-Output ('Closing: {0}' -f $_.ProcessName)
	Stop-Process -InputObject $_ -Force
}

$packageArgs = @{
	packageName    = 'Sucrose Wallpaper Engine'
	checksumType   = 'sha256'
	fileType       = 'exe'
	silentArgs     = '/s'
	validExitCodes = @(0)
}

if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
	$packageArgs['checksum'] = '2BE9C44E1C02A29E7432801AAE8EB53BFD934522879C053F2E7B7DD837B8E15D'
	$packageArgs['url'] = 'https://github.com/Taiizor/Sucrose/releases/download/v25.4.7.0/Sucrose_Bundle_.NET_Framework_4.8_ARM64_25.4.7.0.exe'
} else {
	if ([Environment]::Is64BitOperatingSystem) {
		if ([System.Environment]::Is64BitProcess) {
			$packageArgs['checksum'] = '087C24847094F2ED6F91899D5779A242F317095D12F7D93E17EDD9BFBA930608'
			$packageArgs['url'] = 'https://github.com/Taiizor/Sucrose/releases/download/v25.4.7.0/Sucrose_Bundle_.NET_Framework_4.8_x64_25.4.7.0.exe'
		} else {
			$packageArgs['checksum'] = '096EEE5A020AE775F06F22AE13290636F14D3B9A7B4043ABA840B375693EC924'
			$packageArgs['url'] = 'https://github.com/Taiizor/Sucrose/releases/download/v25.4.7.0/Sucrose_Bundle_.NET_Framework_4.8_x86_25.4.7.0.exe'
		}
	} else {
		$packageArgs['checksum'] = '096EEE5A020AE775F06F22AE13290636F14D3B9A7B4043ABA840B375693EC924'
		$packageArgs['url'] = 'https://github.com/Taiizor/Sucrose/releases/download/v25.4.7.0/Sucrose_Bundle_.NET_Framework_4.8_x86_25.4.7.0.exe'
	}
}

Install-ChocolateyPackage @packageArgs