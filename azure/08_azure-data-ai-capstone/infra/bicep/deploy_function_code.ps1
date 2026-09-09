param(
    [Parameter(Mandatory = $true)]
    [string]$DeploymentName
)

$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $Here "..\..")).Path
$outputs = az deployment sub show --name $DeploymentName --query properties.outputs -o json | ConvertFrom-Json
$rg = $outputs.resourceGroupName.value
$appName = $outputs.functionAppName.value
if (-not $appName) {
    Write-Host "Function App was not enabled in this deployment. Nothing to deploy."
    exit 0
}

$temp = Join-Path $env:TEMP "poc08-function-package"
$zip = Join-Path $env:TEMP "poc08-function-package.zip"
Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $zip -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $temp | Out-Null

Copy-Item (Join-Path $ProjectRoot "ingestion\functions\function_app.py") (Join-Path $temp "function_app.py")
Copy-Item (Join-Path $ProjectRoot "ingestion") (Join-Path $temp "ingestion") -Recurse
Set-Content -Path (Join-Path $temp "requirements.txt") -Value "azure-functions>=1.21,<2.0" -Encoding ascii
Compress-Archive -Path (Join-Path $temp "*") -DestinationPath $zip -Force

az functionapp deployment source config-zip `
    --resource-group $rg `
    --name $appName `
    --src $zip `
    --build-remote true | Out-Host

Write-Host "[SUCCESS] Function code deployed to $appName"
