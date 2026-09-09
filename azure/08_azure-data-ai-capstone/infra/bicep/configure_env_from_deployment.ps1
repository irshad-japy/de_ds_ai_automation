param(
    [Parameter(Mandatory = $true)]
    [string]$DeploymentName
)

$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $Here "..\..")).Path
$EnvExample = Join-Path $ProjectRoot ".env.example"
$EnvFile = Join-Path $ProjectRoot ".env"

if (-not (Test-Path $EnvFile)) {
    Copy-Item $EnvExample $EnvFile
}

$outputs = az deployment sub show --name $DeploymentName --query properties.outputs -o json | ConvertFrom-Json
if (-not $outputs) {
    throw "No outputs found for subscription deployment '$DeploymentName'."
}

function V([string]$Name) {
    return $outputs.$Name.value
}

function Set-DotEnv([string]$Name, [string]$Value) {
    if ($null -eq $Value) { $Value = "" }
    $lines = Get-Content $EnvFile
    $pattern = "^$([regex]::Escape($Name))="
    $replacement = "$Name=$Value"
    $found = $false
    $newLines = foreach ($line in $lines) {
        if ($line -match $pattern) {
            $found = $true
            $replacement
        } else {
            $line
        }
    }
    if (-not $found) { $newLines += $replacement }
    Set-Content -Path $EnvFile -Value $newLines -Encoding utf8
}

$subscriptionId = az account show --query id -o tsv
$tenantId = az account show --query tenantId -o tsv
$rg = V "resourceGroupName"
$docName = V "documentIntelligenceName"
$searchName = V "searchServiceName"
$foundryName = V "foundryAccountName"

Set-DotEnv "AZURE_AUTH_MODE" "default"
Set-DotEnv "AZURE_SUBSCRIPTION_ID" $subscriptionId
Set-DotEnv "AZURE_TENANT_ID" $tenantId
Set-DotEnv "AZURE_RESOURCE_GROUP" $rg
Set-DotEnv "AZURE_LOCATION" (V "location")
Set-DotEnv "ADLS_ACCOUNT_NAME" (V "storageAccountName")
Set-DotEnv "ADLS_ACCOUNT_URL" (V "adlsAccountUrl")
Set-DotEnv "ADLS_FILE_SYSTEM" (V "adlsFileSystem")
Set-DotEnv "EVENTHUB_FULLY_QUALIFIED_NAMESPACE" (V "eventHubFullyQualifiedNamespace")
Set-DotEnv "EVENTHUB_NAME" (V "eventHubName")
Set-DotEnv "DOCUMENTINTELLIGENCE_ENDPOINT" (V "documentIntelligenceEndpoint")
Set-DotEnv "AZURE_SEARCH_ENDPOINT" (V "searchEndpoint")
Set-DotEnv "AZURE_SEARCH_INDEX" "capstone-knowledge"
Set-DotEnv "FOUNDRY_PROJECT_ENDPOINT" (V "foundryProjectEndpoint")
Set-DotEnv "FOUNDRY_MODEL_DEPLOYMENT" (V "chatDeploymentName")
Set-DotEnv "AZURE_OPENAI_ENDPOINT" (V "azureOpenAIEndpoint")
Set-DotEnv "AZURE_OPENAI_EMBEDDING_DEPLOYMENT" (V "embeddingDeploymentName")
Set-DotEnv "SEARCH_VECTOR_DIMENSIONS" "1536"

# Beginner-friendly key configuration. These keys stay only in local .env, which is gitignored.
try {
    $docKey = az cognitiveservices account keys list --resource-group $rg --name $docName --query key1 -o tsv 2>$null
    Set-DotEnv "DOCUMENTINTELLIGENCE_API_KEY" $docKey
} catch { Write-Warning "Could not read Document Intelligence key. You can use the portal or assign RBAC later." }

try {
    $searchAdminKey = az search admin-key show --resource-group $rg --service-name $searchName --query primaryKey -o tsv 2>$null
    Set-DotEnv "AZURE_SEARCH_ADMIN_KEY" $searchAdminKey
    $searchQueryKey = az search query-key list --resource-group $rg --service-name $searchName --query "[0].key" -o tsv 2>$null
    Set-DotEnv "AZURE_SEARCH_QUERY_KEY" $searchQueryKey
} catch { Write-Warning "Could not read Azure AI Search keys. Entra auth can still work if the RBAC assignments completed." }

try {
    $foundryKey = az cognitiveservices account keys list --resource-group $rg --name $foundryName --query key1 -o tsv 2>$null
    Set-DotEnv "AZURE_OPENAI_API_KEY" $foundryKey
} catch { Write-Warning "Could not read Foundry/Azure OpenAI key. Entra auth remains supported by the Python code." }

$sqlServer = V "sqlServerName"
$sqlDb = V "sqlDatabaseName"
if ($sqlServer -and $sqlDb -and $env:POC08_SQL_ADMIN_PASSWORD) {
    $sqlLogin = V "sqlAdministratorLogin"
    $sqlConn = "Driver={ODBC Driver 18 for SQL Server};Server=tcp:$sqlServer.database.windows.net,1433;Database=$sqlDb;Uid=$sqlLogin;Pwd=$($env:POC08_SQL_ADMIN_PASSWORD);Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
    Set-DotEnv "AZURE_SQL_ODBC_CONNECTION_STRING" $sqlConn
}

Write-Host "[SUCCESS] Updated $EnvFile from Bicep deployment outputs."
Write-Host "Secrets were written only to .env; .env must remain excluded from Git."
