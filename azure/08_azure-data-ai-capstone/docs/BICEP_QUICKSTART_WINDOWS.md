# POC-08 Bicep Quick Start — Windows + Poetry

Use this page when you want the shortest **command-by-command** path. For explanations and troubleshooting, read `BICEP_DEPLOYMENT_GUIDE.md`.

> **Important `.bicepparam` rule:** these parameter files contain `using './main.bicep'`. On current Azure CLI/Bicep, deploy them with `--parameters main.bicepparam` and omit `--template-file`. Combining both causes the Azure CLI error: `Only a .bicep file is allowed with a .bicepparam file`.

## 1. Open PowerShell in the project root

```powershell
cd C:\Users\<you>\projects\08_azure_data-ai-capstone
```

## 2. Verify tools

```powershell
py -3.12 --version
poetry --version
az --version
az bicep version
```

If Bicep is not installed through Azure CLI:

```powershell
az bicep install
az bicep upgrade
az bicep version
```

## 3. Login and select your subscription

```powershell
az login
az account list -o table
az account set --subscription "9902e04b-fd65-40f4-86a2-1b09c1fe672c"
az account show --query "{Subscription:name,SubscriptionId:id,TenantId:tenantId,User:user.name}" -o table
```

**There is no `var.subscription_id` prompt in Bicep.** The active Azure CLI subscription is used.

## 4. Prepare Poetry/local proof first

```powershell
poetry env use 3.12
poetry install
Copy-Item .env.example .env -ErrorAction SilentlyContinue
poetry run pytest
poetry run python -m scripts.smoke_test
```

Expected local smoke-test summary:

```text
total_orders = 10
total_revenue = 675.50
average_order_value = 67.55
[SUCCESS] Local batch -> Bronze -> Silver -> Gold smoke test passed.
```

## 5. Compile and preview Bicep

```powershell
cd infra\bicep
.\register_providers.ps1
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
```

Do not continue if validation returns an error. Review the `what-if` output before creating resources.

## 6. Deploy the beginner/core platform

Recommended helper:

```powershell
.\deploy_bicep.ps1 -Profile beginner
```

Or manual command:

```powershell
az deployment sub create `
  --location eastus `
  --parameters main.bicepparam `
  --no-prompt true `
  --name poc08-beginner
```

The helper script automatically saves the deployment name in:

```text
infra\bicep\last-deployment.txt
```

It also updates the project-root `.env` from Azure deployment outputs/keys.

## 7. Verify resources

```powershell
az group show -n rg-poc08-capstone -o table
az resource list -g rg-poc08-capstone -o table
az storage account list -g rg-poc08-capstone -o table
az eventhubs namespace list -g rg-poc08-capstone -o table
az datafactory list -g rg-poc08-capstone -o table
az search service list -g rg-poc08-capstone -o table
az cognitiveservices account list -g rg-poc08-capstone -o table
```

## 8. Deploy the synthetic POC data / run data-plane tests

If you used `deploy_bicep.ps1`, return to the project root:

```powershell
cd ..\..
$deployment = Get-Content .\infra\bicep\last-deployment.txt
.\infra\bicep\run_after_bicep.ps1 -DeploymentName $deployment
```

This performs the available data-plane flow:

1. Poetry tests and local Bronze/Silver/Gold.
2. Upload `orders_001.csv` to ADLS `raw/orders`.
3. Trigger ADF `pl_orders_raw_to_bronze`.
4. Send shipment events to Event Hubs and write received events to ADLS Bronze.
5. Run Document Intelligence on the synthetic invoice.
6. Prepare Search/RAG documents.
7. If embedding/chat model deployments exist, create/load/query the Search index and run RAG.
8. If Azure SQL is enabled, load Gold into SQL.
9. If Function App is enabled, deploy the Python Function code.

## 9. Optional: create the full lab resources

This creates Databricks, Azure SQL, Function App, Azure ML and Synapse in addition to the core platform. It can cost more.

```powershell
$env:POC08_SQL_ADMIN_PASSWORD="<STRONG-TEMPORARY-LAB-PASSWORD>"
# Optional if you want a SQL firewall rule for your workstation:
$env:POC08_CLIENT_IP="<YOUR-PUBLIC-IP>"

cd infra\bicep
.\deploy_bicep.ps1 -Profile full
```

CMD wrapper after setting the environment variables:

```cmd
infra\bicep\deploy_full.cmd
```

## 10. Optional: deploy Foundry chat + embedding models

Model availability, version, quota and deployment SKU depend on your subscription and region. The model deployment is separated so the rest of the POC can succeed even if quota is unavailable.

```powershell
cd infra\bicep
.\deploy_bicep.ps1 -Profile models
```

Or:

```cmd
infra\bicep\deploy_models.cmd
```

After model deployment:

```powershell
cd ..\..
$deployment = Get-Content .\infra\bicep\last-deployment.txt
.\infra\bicep\run_after_bicep.ps1 -DeploymentName $deployment -SkipEvents -SkipDocuments -SkipSql -SkipFunctionCode
```

## 11. One-click beginner infrastructure + data flow

After Azure login/subscription selection:

```powershell
.\infra\bicep\deploy_and_run_beginner.ps1
```

This runs the beginner infrastructure deployment and then the post-deployment data tests.

## 12. Clean up

```powershell
.\infra\bicep\destroy_bicep.ps1 -ResourceGroupName rg-poc08-capstone
```

Type `DELETE` when prompted.

Verify:

```powershell
az group exists --name rg-poc08-capstone
```

Expected after deletion completes:

```text
false
```
