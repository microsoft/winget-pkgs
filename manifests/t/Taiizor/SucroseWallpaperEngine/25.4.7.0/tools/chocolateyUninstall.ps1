$ErrorActionPreference = 'Stop'
$packageArgs = @{
	packageName   = 'Sucrose Wallpaper Engine'
	fileType      = 'exe'
	validExitCodes= @(0)
}

$key = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Sucrose' -ErrorAction SilentlyContinue

if ($null -ne $key) {
	$packageArgs['file'] = "$($key.UninstallString)"

	#Start-Process -FilePath $uninstallString -Wait
	Uninstall-ChocolateyPackage @packageArgs
}
else {
	Write-Warning "$($packageArgs.packageName) is not installed or has already been uninstalled."
}