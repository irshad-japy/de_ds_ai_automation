# POC-08 Bicep deployment fix — 2026-09-07

## Errors fixed

### 1. Key Vault deployment failure

Error:

```text
The property "enablePurgeProtection" cannot be set to false.
Enabling the purge protection for a vault is an irreversible action.
```

Fix in `infra\bicep\modules\keyvault.bicep`:

Removed:

```bicep
enablePurgeProtection: false
```

For this disposable POC/lab, leaving this property unset avoids trying to explicitly
disable purge protection.

### 2. Azure AI Search Bicep warning

Warning:

```text
BCP036: The property "hostingMode" expected a value of type
'Default' | 'HighDensity' | null but the provided value is 'default'.
```

Fix in `infra\bicep\modules\search.bicep`:

Changed:

```bicep
hostingMode: 'default'
```

to:

```bicep
hostingMode: 'Default'
```

## Rerun steps

From the project root:

```powershell
cd infra\bicep
```

Compile:

```powershell
az bicep build --file main.bicep
```

Validate:

```powershell
az deployment sub validate `
  --location eastus `
  --parameters main.bicepparam `
  --no-prompt true `
  --name poc08-validate-fixed
```

Preview:

```powershell
az deployment sub what-if `
  --location eastus `
  --parameters main.bicepparam `
  --no-prompt true `
  --name poc08-whatif-fixed
```

Then deploy:

```powershell
.\deploy_bicep.ps1 -Profile beginner
```

## Important

The previous failed deployment may already have created some resources in
`rg-poc08-capstone`. You do not need to delete them first. ARM/Bicep deployment is
declarative, so the next deployment will reconcile the target state.

Verify afterwards:

```powershell
az resource list -g rg-poc08-capstone -o table
az keyvault list -g rg-poc08-capstone -o table
az search service list -g rg-poc08-capstone -o table
```
