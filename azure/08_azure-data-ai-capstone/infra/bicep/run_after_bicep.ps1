param(
    [Parameter(Mandatory = $true)]
    [string]$DeploymentName,
    [switch]$SkipEvents,
    [switch]$SkipDocuments,
    [switch]$SkipSearch,
    [switch]$SkipSql,
    [switch]$SkipFunctionCode
)

$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $Here "..\..")).Path
Push-Location $ProjectRoot
try {
    if (-not (Get-Command poetry -ErrorAction SilentlyContinue)) {
        throw "Poetry is not installed/on PATH."
    }

    Write-Host "[1] Install/check Poetry environment"
    poetry env use 3.12
    poetry install
    poetry run python -m scripts.verify_config --profile local
    poetry run pytest

    Write-Host "[2] Generate local Bronze/Silver/Gold proof"
    poetry run python -m scripts.smoke_test

    Write-Host "[3] Upload synthetic orders file to ADLS raw/orders"
    poetry run python -m scripts.verify_config --profile adls
    poetry run python -m ingestion.batch.upload_orders

    $outputs = az deployment sub show --name $DeploymentName --query properties.outputs -o json | ConvertFrom-Json
    $rg = $outputs.resourceGroupName.value
    $adf = $outputs.dataFactoryName.value
    $pipeline = $outputs.dataFactoryPipelineName.value

    Write-Host "[4] Run ADF raw -> bronze copy pipeline"

    # The `az datafactory` command group is supplied by an Azure CLI extension.
    # Install/update it explicitly before capturing create-run output so that an
    # interactive extension-install prompt can never contaminate the run ID.
    Write-Host "Checking Azure CLI Data Factory extension..."
    $dfExtension = az extension show --name datafactory --query name -o tsv 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($dfExtension)) {
        Write-Host "Installing Azure CLI Data Factory extension..."
        az extension add --name datafactory --upgrade --yes | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "Could not install the Azure CLI 'datafactory' extension."
        }
    }

    $runOutput = az datafactory pipeline create-run `
        --resource-group $rg `
        --factory-name $adf `
        --name $pipeline `
        --query runId `
        -o tsv `
        --only-show-errors

    if ($LASTEXITCODE -ne 0) {
        throw "ADF pipeline create-run failed."
    }

    # Be defensive: take the final non-empty line and require an Azure-style GUID.
    $runId = [string](($runOutput | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 1))
    $runId = $runId.Trim()

    if ($runId -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
        throw "ADF returned an invalid run ID: '$runId'"
    }

    Write-Host "ADF run id: $runId"

    $status = ""
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 5
        $statusOutput = az datafactory pipeline-run show `
            --resource-group $rg `
            --factory-name $adf `
            --run-id $runId `
            --query status `
            -o tsv `
            --only-show-errors

        if ($LASTEXITCODE -ne 0) {
            throw "Could not read ADF pipeline status for run ID '$runId'."
        }

        $status = ([string]$statusOutput).Trim()
        Write-Host "ADF status: $status"

        if ($status -eq "Succeeded") { break }

        if ($status -in @("Failed", "Cancelled")) {
            Write-Host "ADF run details:"
            az datafactory pipeline-run show `
                --resource-group $rg `
                --factory-name $adf `
                --run-id $runId `
                -o jsonc | Out-Host
            throw "ADF pipeline ended with status: $status"
        }
    }

    if ($status -ne "Succeeded") {
        throw "ADF pipeline did not complete within the expected wait period."
    }

    if (-not $SkipEvents) {
        Write-Host "[5] Event Hubs send + receive-to-ADLS test"
        poetry run python -m scripts.verify_config --profile events
        poetry run python -m ingestion.events.send_events
        poetry run python -m ingestion.events.receive_events_to_adls --max-events 3
    }

    if (-not $SkipDocuments) {
        Write-Host "[6] Document Intelligence invoice extraction"
        poetry run python -m scripts.verify_config --profile documents
        poetry run python -m ai.document_intelligence.extract_invoice
    }

    $foundryName = $outputs.foundryAccountName.value
    $embeddingName = $outputs.embeddingDeploymentName.value
    $chatName = $outputs.chatDeploymentName.value
    $deployments = @(az cognitiveservices account deployment list --resource-group $rg --name $foundryName --query "[].name" -o tsv 2>$null)
    $hasEmbedding = $deployments -contains $embeddingName
    $hasChat = $deployments -contains $chatName

    if (-not $SkipSearch) {
        Write-Host "[7] Prepare RAG documents"
        poetry run python -m ai.rag.prepare_documents
        if ($hasEmbedding) {
            Write-Host "Embedding deployment found. Building Search vector index and loading documents."
            poetry run python -m scripts.verify_config --profile search
            poetry run python -m scripts.verify_config --profile embeddings
            poetry run python -m ai.rag.create_index
            poetry run python -m ai.rag.index_documents
            poetry run python -m ai.rag.query_search "When is a shipment considered delayed?"
            if ($hasChat) {
                poetry run python -m ai.rag.rag_answer "When is a shipment considered delayed?"
            } else {
                Write-Warning "Chat deployment '$chatName' is not present, so RAG answer generation is skipped."
            }
        } else {
            Write-Warning "Embedding deployment '$embeddingName' is not present. Use deploy_bicep.ps1 -Profile models after checking model availability/quota, then rerun this script."
        }
    }

    $sqlServer = $outputs.sqlServerName.value
    if (-not $SkipSql -and $sqlServer) {
        Write-Host "[8] Optional Azure SQL serving load"
        poetry install --with sql
        poetry run python -m serving.sql.load_gold
    }

    $functionApp = $outputs.functionAppName.value
    if (-not $SkipFunctionCode -and $functionApp) {
        Write-Host "[9] Optional Function App code deployment"
        & (Join-Path $Here "deploy_function_code.ps1") -DeploymentName $DeploymentName
    }

    Write-Host ""
    Write-Host "[SUCCESS] Automated post-Bicep checks finished."
    Write-Host "Databricks notebook import/run remains a data-plane handoff; follow docs\DATABRICKS_BICEP_HANDOFF.md."
} finally {
    Pop-Location
}
