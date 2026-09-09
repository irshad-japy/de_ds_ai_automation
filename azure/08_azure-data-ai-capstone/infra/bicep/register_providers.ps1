param(
    [string]$SubscriptionId = ""
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) is not installed or not on PATH. Install it, open a new terminal, then rerun."
}

if (-not (az account show 2>$null)) {
    Write-Host "Azure login is required..."
    az login | Out-Host
}

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId
}

$providers = @(
    "Microsoft.Resources",
    "Microsoft.Storage",
    "Microsoft.EventHub",
    "Microsoft.DataFactory",
    "Microsoft.Search",
    "Microsoft.CognitiveServices",
    "Microsoft.KeyVault",
    "Microsoft.OperationalInsights",
    "Microsoft.Insights",
    "Microsoft.Authorization",
    "Microsoft.Databricks",
    "Microsoft.Sql",
    "Microsoft.Web",
    "Microsoft.MachineLearningServices",
    "Microsoft.Synapse"
)

foreach ($provider in $providers) {
    $state = az provider show --namespace $provider --query registrationState -o tsv 2>$null
    if ($state -ne "Registered") {
        Write-Host "Registering $provider ..."
        az provider register --namespace $provider | Out-Null
    } else {
        Write-Host "[OK] $provider already registered"
    }
}

Write-Host ""
Write-Host "Provider registration was requested. Some providers can take a few minutes."
Write-Host "Check with: az provider list --query `"[?registrationState!='Registered'].[namespace,registrationState]`" -o table"
