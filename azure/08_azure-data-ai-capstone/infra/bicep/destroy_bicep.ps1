param(
    [string]$ResourceGroupName = "rg-poc08-capstone",
    [switch]$NoWait
)

$ErrorActionPreference = "Stop"
Write-Host "This deletes the complete POC-08 resource group and every resource inside it: $ResourceGroupName"
$answer = Read-Host "Type DELETE to continue"
if ($answer -ne "DELETE") {
    Write-Host "Cancelled."
    exit 0
}

if ($NoWait) {
    az group delete --name $ResourceGroupName --yes --no-wait
} else {
    az group delete --name $ResourceGroupName --yes
}

Write-Host "Cleanup command submitted/completed. Verify with: az group exists --name $ResourceGroupName"
