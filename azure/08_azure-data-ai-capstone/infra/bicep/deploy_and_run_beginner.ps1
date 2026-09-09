param(
    [string]$SubscriptionId = "",
    [string]$Location = "eastus"
)

$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $Here "..\..")).Path

Write-Host "============================================================"
Write-Host "POC-08 one-click BEGINNER Bicep infrastructure + data proof"
Write-Host "============================================================"

& (Join-Path $Here "deploy_bicep.ps1") `
    -Profile beginner `
    -SubscriptionId $SubscriptionId `
    -Location $Location

$LastDeploymentFile = Join-Path $Here "last-deployment.txt"
if (-not (Test-Path $LastDeploymentFile)) {
    throw "Deployment completed but last-deployment.txt was not found."
}

$DeploymentName = (Get-Content $LastDeploymentFile -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($DeploymentName)) {
    throw "The last deployment name is empty."
}

Write-Host ""
Write-Host "Running POC data-plane checks for deployment: $DeploymentName"
Push-Location $ProjectRoot
try {
    & (Join-Path $Here "run_after_bicep.ps1") -DeploymentName $DeploymentName
} finally {
    Pop-Location
}
