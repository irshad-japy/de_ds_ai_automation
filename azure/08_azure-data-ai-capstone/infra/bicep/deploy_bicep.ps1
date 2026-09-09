param(
    [ValidateSet("beginner", "full", "models")]
    [string]$Profile = "beginner",
    [string]$SubscriptionId = "",
    [string]$Location = "eastus",
    [string]$DeploymentName = "",
    [switch]$SkipWhatIf,
    [switch]$SkipProviderRegistration,
    [switch]$SkipEnvConfiguration,
    [switch]$SkipDeveloperRbac
)

$ErrorActionPreference = "Stop"

function Assert-NativeSuccess([string]$Step) {
    if ($LASTEXITCODE -ne 0) {
        throw "$Step failed with exit code $LASTEXITCODE."
    }
}
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Template = Join-Path $Here "main.bicep"

switch ($Profile) {
    "beginner" { $ParameterFile = Join-Path $Here "main.bicepparam" }
    "full"     { $ParameterFile = Join-Path $Here "main.full.bicepparam" }
    "models"   { $ParameterFile = Join-Path $Here "main.models.bicepparam" }
}

if (-not $DeploymentName) {
    $DeploymentName = "poc08-$Profile-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) is not installed or not on PATH."
}

if (-not (az account show 2>$null)) {
    Write-Host "Opening Azure login..."
    az login | Out-Host
}

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId
    Assert-NativeSuccess "az account set"
}

# Keep the resource location parameter in the .bicepparam profile aligned with this script argument.
$env:POC08_LOCATION = $Location

Write-Host ""
Write-Host "Active Azure account:"
az account show --query "{subscription:name,subscriptionId:id,tenantId:tenantId,user:user.name}" -o table

# Bicep uses the active Azure CLI subscription, so there is no Terraform-style subscription_id prompt.
if ($SkipDeveloperRbac) {
    $env:POC08_DEVELOPER_OBJECT_ID = ""
    Write-Warning "Developer RBAC assignments are disabled. ADF still needs permission to assign its managed identity to ADLS."
} else {
    try {
        $developerObjectId = az ad signed-in-user show --query id -o tsv 2>$null
        if ($developerObjectId) {
            $env:POC08_DEVELOPER_OBJECT_ID = $developerObjectId
            Write-Host "Developer object ID will be used for lab RBAC: $developerObjectId"
        }
    } catch {
        Write-Warning "Could not resolve signed-in user object ID. Infrastructure can continue, but local Entra data-plane access might need manual role assignment."
    }
}

if ($Profile -eq "full" -and [string]::IsNullOrWhiteSpace($env:POC08_SQL_ADMIN_PASSWORD)) {
    throw "Full profile needs POC08_SQL_ADMIN_PASSWORD. Example: `$env:POC08_SQL_ADMIN_PASSWORD='Use-A-Strong-Lab-Password!123'"
}

if (-not $SkipProviderRegistration) {
    & (Join-Path $Here "register_providers.ps1") -SubscriptionId $SubscriptionId
}

Write-Host ""
Write-Host "[1/4] Bicep version/build"
az bicep version
Assert-NativeSuccess "az bicep version"
az bicep build --file $Template
Assert-NativeSuccess "az bicep build"

Write-Host ""
Write-Host "[2/4] Azure deployment validation"
az deployment sub validate `
    --location $Location `
    --parameters $ParameterFile `
    --no-prompt true `
    --name "$DeploymentName-validate" | Out-Host
Assert-NativeSuccess "Bicep subscription validation"

if (-not $SkipWhatIf) {
    Write-Host ""
    Write-Host "[3/4] WHAT-IF - review resources before creation"
    az deployment sub what-if `
        --location $Location `
        --parameters $ParameterFile `
        --no-prompt true `
        --name "$DeploymentName-whatif" | Out-Host
    Assert-NativeSuccess "Bicep what-if"
} else {
    Write-Host "[3/4] WHAT-IF skipped by request"
}

Write-Host ""
Write-Host "[4/4] Creating Azure resources"
az deployment sub create `
    --location $Location `
    --parameters $ParameterFile `
    --no-prompt true `
    --name $DeploymentName `
    --output table | Out-Host
Assert-NativeSuccess "Bicep deployment create"

$OutputPath = Join-Path $Here "deployment-outputs.json"
az deployment sub show --name $DeploymentName --query properties.outputs -o json | Set-Content -Path $OutputPath -Encoding utf8
Assert-NativeSuccess "Read deployment outputs"
$LastDeploymentPath = Join-Path $Here "last-deployment.txt"
Set-Content -Path $LastDeploymentPath -Value $DeploymentName -Encoding ascii

Write-Host ""
Write-Host "[SUCCESS] Bicep deployment completed: $DeploymentName"
Write-Host "Outputs saved to: $OutputPath"
Write-Host "Deployment name saved to: $LastDeploymentPath"

if (-not $SkipEnvConfiguration) {
    & (Join-Path $Here "configure_env_from_deployment.ps1") -DeploymentName $DeploymentName
}

Write-Host ""
Write-Host "NEXT: from the project root run:"
Write-Host "  poetry install"
Write-Host "  poetry run python -m scripts.smoke_test"
Write-Host "  .\infra\bicep\run_after_bicep.ps1 -DeploymentName $DeploymentName"
