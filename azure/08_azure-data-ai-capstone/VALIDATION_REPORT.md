# Validation report

Validation performed while packaging this **Azure Bicep + Poetry** edition of POC-08:

- Python source compiled successfully with `python -m compileall`.
- `python -m scripts.verify_config --profile local` passed.
- `python -m scripts.smoke_test` passed.
- Local Bronze -> Silver -> Gold result: 10 orders, total revenue 675.50, average order value 67.55.
- `pytest -q` passed: 4 tests.
- Synthetic invoice PDF is included and is a valid PDF file.
- The repository contains Bicep modules, `.bicepparam` profiles, Azure CLI/PowerShell deploy scripts, Azure DevOps Bicep validation/deploy YAML, post-deployment data scripts, verification commands, and cleanup scripts.

## Not executed in the packaging environment

- Live Azure deployment was not executed because the packaging environment does not have the user's Azure subscription/credentials.
- `az bicep build` / `az deployment sub validate` were not executed because Azure CLI/Bicep CLI is not installed in the packaging environment.
- Databricks notebook execution, Azure SQL load, Event Hubs, Document Intelligence, Search indexing, Foundry model deployment/RAG, and Function code deployment require live Azure resources and therefore were not executed here.

Before creating resources, run the exact checks documented in `docs/BICEP_QUICKSTART_WINDOWS.md` and `docs/BICEP_DEPLOYMENT_GUIDE.md`:

```powershell
az bicep build --file infra/bicep/main.bicep
az deployment sub validate --location eastus --parameters infra/bicep/main.bicepparam --name poc08-validate
az deployment sub what-if --location eastus --parameters infra/bicep/main.bicepparam --name poc08-whatif
```

The deployment helper script performs these checks automatically before `create`.
