# POC-08 Azure Bicep infrastructure

Bicep is the primary IaC path in this edition.

Start here:

```text
../../docs/BICEP_DEPLOYMENT_GUIDE.md
```

Quick beginner deployment from PowerShell:

```powershell
az login
az account set --subscription "<SUBSCRIPTION-ID>"
cd infra\bicep
.\deploy_bicep.ps1 -Profile beginner
```

Then from project root:

```powershell
poetry install
poetry run python -m scripts.smoke_test
.\infra\bicep\run_after_bicep.ps1 -DeploymentName "<NAME-PRINTED-BY-DEPLOY-SCRIPT>"
```

Profiles:

- `main.bicepparam` / `-Profile beginner`: core platform, low-risk starting point.
- `main.models.bicepparam` / `-Profile models`: core + Foundry chat/embedding deployments.
- `main.full.bicepparam` / `-Profile full`: optional Databricks, SQL, Function App, Azure ML, Synapse; can be expensive.

`subscription_id` is not requested by the template. Bicep uses the Azure subscription selected with `az account set`.

One-click beginner infrastructure + data proof after `az login` / subscription selection:

```powershell
.\infra\bicep\deploy_and_run_beginner.ps1
```

Or from CMD:

```cmd
infra\bicep\deploy_and_run_beginner.cmd
```
