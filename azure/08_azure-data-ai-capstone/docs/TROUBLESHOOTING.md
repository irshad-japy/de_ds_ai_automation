# Troubleshooting

## `poetry` is not recognized
Install Poetry using the official Poetry installer or `pipx install poetry`, then open a new terminal and run `poetry --version`.

## Poetry selects the wrong Python

```powershell
poetry env remove --all
poetry env use 3.12
poetry run python --version
```

Expected: Python 3.12.x.

## `az` is not recognized
You do not need Azure CLI for the Python POC. Set `AZURE_AUTH_MODE=browser`. Bicep deployment requires Azure CLI. Install Azure CLI and restart your terminal so PATH is refreshed.

## 403 from ADLS
Confirm Storage Blob Data Contributor is assigned at the storage account/container scope and sign in again. RBAC propagation can take a few minutes.

## Event Hubs CBS / authorization failure
Confirm `EVENTHUB_NAME` is the hub name, not the namespace. For RBAC, assign Data Sender/Receiver. For connection-string mode, use a policy that has the required Send/Listen right.

## Search vector dimension error
The search index vector field dimension must match the embedding model output. Set `SEARCH_VECTOR_DIMENSIONS` correctly, delete/recreate the index if necessary, then re-index.

## Search 403
For key mode, use admin key to create/load the index and query key for query-only operations. For RBAC, check Search Service Contributor / Search Index Data Contributor / Search Index Data Reader roles as applicable.

## Foundry `AttributeError` / endpoint problem
This project targets the new Foundry SDK (`azure-ai-projects>=2.0`). Confirm the endpoint looks like:

`https://<resource>.services.ai.azure.com/api/projects/<project>`

Then run `poetry show azure-ai-projects` and verify you did not accidentally install a classic 1.x environment.

## Document Intelligence `InvalidContent`
Confirm the file exists and is a supported PDF/image, then rerun with `data/synthetic/invoice_001.pdf`. If a custom scan fails, open it locally to verify it is not corrupt.

---

# Bicep-specific troubleshooting

## Bicep asks for `subscription_id`

It should not. This edition does not define a `subscription_id` parameter. Select the subscription with:

```powershell
az account set --subscription "<SUBSCRIPTION-ID>"
az account show -o table
```

Then rerun the Bicep deployment.

## `az bicep` command fails

```powershell
az bicep install
az bicep upgrade
az bicep version
```

Open a new terminal after updating Azure CLI if necessary.

## `MissingSubscriptionRegistration`

```powershell
.\infra\bicep\register_providers.ps1
```

Wait until the needed provider reports `Registered`, then retry.

## `AuthorizationFailed` while creating roleAssignments

The deployment identity needs permission to assign RBAC, usually Owner or User Access Administrator at the needed scope. If you cannot get that permission, deploy without developer object-ID RBAC and assign the Storage/Event Hubs/Search/Foundry data roles manually.

## Azure AI Search free tier fails

If a free Search service already exists or the subscription/region cannot create another free service:

```powershell
$env:POC08_SEARCH_SKU="basic"
.\infra\bicep\deploy_bicep.ps1 -Profile beginner
```

`basic` is billable.

## Document Intelligence F0 fails

Use S0 only if you accept the cost:

```powershell
$env:POC08_DOCUMENT_SKU="S0"
.\infra\bicep\deploy_bicep.ps1 -Profile beginner
```

## Foundry model deployment fails

Model availability and quota are region/subscription specific. The core resource/project can be deployed without models. Verify the model name/version/SKU for the selected region, update the environment variables described in `docs/BICEP_DEPLOYMENT_GUIDE.md`, then use the `models` profile.

## Full profile fails because SQL password is blank

```powershell
$env:POC08_SQL_ADMIN_PASSWORD="<STRONG-LAB-PASSWORD>"
.\infra\bicep\deploy_bicep.ps1 -Profile full
```

Do not commit the password to source control.
