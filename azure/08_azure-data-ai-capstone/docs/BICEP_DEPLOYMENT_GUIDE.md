# POC-08 Azure Bicep Deployment Guide (Beginner, Windows + Poetry)

This is the primary infrastructure guide for POC-08. The project now uses **Azure Bicep** instead of Terraform.

> Important: Bicep creates Azure **control-plane resources**. It does not upload business data into ADLS, send Event Hubs messages, run Document Intelligence, or load an Azure AI Search index by itself. The included PowerShell + Poetry/Python scripts perform those data-plane steps immediately after infrastructure deployment.

> **Important `.bicepparam` rule:** these parameter files contain `using './main.bicep'`. On current Azure CLI/Bicep, deploy them with `--parameters main.bicepparam` and omit `--template-file`. Combining both causes the Azure CLI error: `Only a .bicep file is allowed with a .bicepparam file`.

## 1. What the Bicep deployment creates

The beginner profile creates the core POC resources:

- Resource group
- ADLS Gen2 storage account with `datalake` filesystem
- Event Hubs namespace + `shipment-events`
- Azure Data Factory + managed-identity ADLS linked service + raw-to-bronze copy pipeline
- Azure AI Search
- Azure AI Document Intelligence
- Microsoft Foundry resource + Foundry project
- Key Vault
- Log Analytics workspace
- Application Insights
- RBAC assignments for the signed-in developer where possible

Optional modules are included for:

- Azure Databricks workspace
- Azure SQL Database
- Linux Azure Function App
- Azure Machine Learning workspace
- Azure Synapse workspace
- Foundry chat and embedding model deployments

Fabric/OneLake is an alternative serving path in the capstone architecture. This runnable Bicep implementation uses Azure SQL (and optionally Synapse) as the automated serving path because Fabric workspace/data-plane provisioning is separate from the simple ARM/Bicep resource deployment used here.

## 2. Prerequisites

Open **PowerShell** and verify:

```powershell
az --version
az bicep version
py -3.12 --version
poetry --version
```

If Azure CLI is not installed, install it first, close/reopen the terminal, then verify again.

Upgrade the Bicep CLI bundled with Azure CLI:

```powershell
az bicep upgrade
az bicep version
```

## 3. Login and choose the Azure subscription

```powershell
az login
az account list -o table
```

If you have more than one subscription:

```powershell
az account set --subscription "<YOUR-SUBSCRIPTION-ID>"
```

Verify:

```powershell
az account show --query "{Subscription:name,SubscriptionId:id,TenantId:tenantId,User:user.name}" -o table
```

Unlike the previous Terraform flow, **Bicep does not ask for `var.subscription_id`**. The active subscription from `az account show` is used.

## 4. Go to the Bicep folder

From the project root:

```powershell
cd infra\bicep
```

You should see:

```text
main.bicep
main.bicepparam
main.full.bicepparam
main.models.bicepparam
modules\
deploy_bicep.ps1
run_after_bicep.ps1
configure_env_from_deployment.ps1
register_providers.ps1
destroy_bicep.ps1
```

## 5. Register Azure resource providers

Run once per subscription:

```powershell
.\register_providers.ps1
```

Or explicitly pass the subscription:

```powershell
.\register_providers.ps1 -SubscriptionId "<YOUR-SUBSCRIPTION-ID>"
```

Check registration:

```powershell
az provider list --query "[?registrationState!='Registered'].[namespace,registrationState]" -o table
```

Some providers take a few minutes to change to `Registered`.

## 6. Build/compile Bicep before deployment

```powershell
az bicep build --file main.bicep
```

Expected: no Bicep compilation error. A generated `main.json` can appear; it is ignored by Git.

You can also compile the parameter file:

```powershell
az bicep build-params --file main.bicepparam
```

## 7. Beginner deployment — recommended first

The beginner profile creates the integration core while keeping Databricks, SQL, Functions, Azure ML, Synapse and model deployments disabled.

From `infra\bicep`:

```powershell
.\deploy_bicep.ps1 -Profile beginner
```

The script performs:

1. Azure login check.
2. Active subscription check.
3. Developer object-ID detection for lab RBAC.
4. Provider registration.
5. `az bicep build`.
6. Subscription-scope deployment validation.
7. Azure `what-if` preview.
8. Actual Bicep deployment.
9. Saves `deployment-outputs.json`.
10. Creates/updates root `.env` automatically from deployment outputs and service keys.

### Manual equivalent commands

If you prefer to run every command yourself:

```powershell
az bicep build --file main.bicep

az deployment sub validate `
  --location eastus `
  --parameters main.bicepparam `
  --no-prompt true `
  --name poc08-validate

az deployment sub what-if `
  --location eastus `
  --parameters main.bicepparam `
  --no-prompt true `
  --name poc08-whatif

az deployment sub create `
  --location eastus `
  --parameters main.bicepparam `
  --no-prompt true `
  --name poc08-beginner
```

Show outputs:

```powershell
az deployment sub show --name poc08-beginner --query properties.outputs -o table
```

Configure `.env` from the deployment:

```powershell
.\configure_env_from_deployment.ps1 -DeploymentName poc08-beginner
```

## 8. Verify Azure resources after deployment

Get the resource group from deployment output or use the default:

```powershell
az group show --name rg-poc08-capstone -o table
az resource list --resource-group rg-poc08-capstone -o table
```

Storage:

```powershell
az storage account list -g rg-poc08-capstone -o table
```

Event Hubs:

```powershell
az eventhubs namespace list -g rg-poc08-capstone -o table
```

ADF:

```powershell
az datafactory list -g rg-poc08-capstone -o table
```

AI Search:

```powershell
az search service list -g rg-poc08-capstone -o table
```

Cognitive/Foundry resources:

```powershell
az cognitiveservices account list -g rg-poc08-capstone -o table
```

## 9. Run the data deployment after Bicep

Return to project root:

```powershell
cd ..\..
```

Install Poetry environment:

```powershell
poetry env use 3.12
poetry install
poetry run python --version
poetry run pytest
```

Run local Bronze -> Silver -> Gold proof:

```powershell
poetry run python -m scripts.smoke_test
```

Then run the automated post-Bicep data workflow. Use the exact deployment name printed by `deploy_bicep.ps1`:

```powershell
.\infra\bicep\run_after_bicep.ps1 -DeploymentName "poc08-beginner-YYYYMMDD-HHMMSS"
```

It performs the following where enabled/configured:

- local tests + local Gold generation;
- upload `orders_001.csv` to ADLS `raw/orders`;
- run ADF `pl_orders_raw_to_bronze`;
- send shipment events to Event Hubs;
- receive events and write them to ADLS Bronze;
- run Document Intelligence on `invoice_001.pdf`;
- prepare RAG documents;
- create/index/query Azure AI Search if the embedding deployment exists;
- run grounded RAG if the chat deployment exists;
- load Gold data to Azure SQL if SQL is enabled;
- zip-deploy the optional Function App if it is enabled.

## 10. Deploy Foundry models

Model names/versions/SKUs and quota are region/subscription dependent. This is intentionally a separate step.

First inspect the resource name:

```powershell
az deployment sub show --name "<YOUR-DEPLOYMENT-NAME>" --query "properties.outputs.foundryAccountName.value" -o tsv
```

Check available models in your region/subscription in Foundry or with the appropriate Cognitive Services model-list command supported by your Azure CLI version.

The included model profile defaults to:

```text
chat:       gpt-5-mini
embedding:  text-embedding-3-small
```

Deploy the model profile:

```powershell
cd infra\bicep
.\deploy_bicep.ps1 -Profile models
```

If your subscription/region requires different model versions or SKU, set environment variables before running:

```powershell
$env:POC08_CHAT_MODEL="gpt-5-mini"
$env:POC08_CHAT_MODEL_VERSION="<VERSION-AVAILABLE-IN-YOUR-REGION>"
$env:POC08_CHAT_SKU="GlobalStandard"
$env:POC08_EMBEDDING_MODEL="text-embedding-3-small"
$env:POC08_EMBEDDING_MODEL_VERSION="1"
$env:POC08_EMBEDDING_SKU="Standard"

.\deploy_bicep.ps1 -Profile models
```

After model deployment, run `configure_env_from_deployment.ps1`, then rerun `run_after_bicep.ps1` so the Search/RAG steps execute.

## 11. Full lab deployment

This profile turns on Databricks, Azure SQL, Function App, Azure ML and Synapse. It can incur materially more cost.

Set a strong temporary SQL/Synapse admin password in the current PowerShell process. Do not put it in Git:

```powershell
$env:POC08_SQL_ADMIN_PASSWORD="<STRONG-LAB-PASSWORD>"
```

Optional: let Azure SQL accept your current public IP by setting:

```powershell
$env:POC08_CLIENT_IP="<YOUR-PUBLIC-IP>"
```

Then:

```powershell
cd infra\bicep
.\deploy_bicep.ps1 -Profile full
```

The secure SQL password is read from the environment by `main.full.bicepparam` using `readEnvironmentVariable(...)`; it is not stored in the parameter file.

## 12. Databricks handoff

Bicep creates the Azure Databricks workspace, but importing notebooks, creating/starting a cluster and executing notebook jobs are Databricks **data-plane** actions. Follow:

```text
docs/DATABRICKS_BICEP_HANDOFF.md
```

For the beginner capstone, reusing the Databricks workspace from POC-02 is recommended to reduce cost.

## 13. Function App code deployment

If `deployFunctionApp=true`, Bicep creates the Function infrastructure. Deploy the Python code with:

```powershell
.\infra\bicep\deploy_function_code.ps1 -DeploymentName "<YOUR-DEPLOYMENT-NAME>"
```

The deployment package uses `ingestion/functions/function_app.py` and writes accepted Event Hubs events to the main ADLS `datalake/bronze/events/...` path.

## 14. Verify ADLS raw and bronze paths

Get the storage account name:

```powershell
$storage = az deployment sub show --name "<YOUR-DEPLOYMENT-NAME>" --query "properties.outputs.storageAccountName.value" -o tsv
```

List data:

```powershell
az storage fs file list `
  --account-name $storage `
  --file-system datalake `
  --path raw/orders `
  --auth-mode login `
  -o table

az storage fs file list `
  --account-name $storage `
  --file-system datalake `
  --path bronze/orders `
  --auth-mode login `
  -o table
```

Expected: `orders_001.csv` exists in both raw and bronze after the upload + ADF run.

## 15. Common deployment errors

### `AuthorizationFailed` on roleAssignments

Your login can create resources but cannot assign RBAC. You need `Owner` or `User Access Administrator` (or equivalent permission) at the relevant scope. This template also assigns the ADF managed identity to ADLS, so the deployer needs permission to create role assignments. Use an account with `Owner` or `User Access Administrator` plus resource-creation permissions, or ask your Azure administrator to perform/approve the RBAC assignments.

### Search `free` SKU fails

A subscription can have free-tier limitations. Set:

```powershell
$env:POC08_SEARCH_SKU="basic"
```

Then redeploy. Basic is billable, so clean it up after the POC.

### Document Intelligence `F0` fails

You may already have a free Document Intelligence account. Set:

```powershell
$env:POC08_DOCUMENT_SKU="S0"
```

S0 is billable.

### Model deployment fails

Typical causes:

- model not available in the selected region;
- model version changed;
- deployment SKU unsupported;
- no quota/capacity;
- Foundry resource/model policy restrictions.

The core POC infrastructure can still be deployed with `deployFoundryModels=false`; fix model deployment separately.

### Provider is not registered

Run:

```powershell
.\infra\bicep\register_providers.ps1
```

Wait a few minutes and retry.

### Bicep command not found

```powershell
az bicep install
az bicep upgrade
az bicep version
```

## 16. Cleanup

Because all POC resources are grouped under one dedicated resource group, cleanup is simple:

```powershell
.\infra\bicep\destroy_bicep.ps1 -ResourceGroupName rg-poc08-capstone
```

Type:

```text
DELETE
```

Verify:

```powershell
az group exists --name rg-poc08-capstone
```

Expected after deletion completes:

```text
false
```

Also check Azure Cost Management after the POC, especially if Databricks, Synapse, Azure ML, paid Search, SQL, or model deployments were enabled.
