# Cost cleanup

POC-08 is a lab. Several services can incur ongoing charges even when you are not actively testing.

## Bicep edition cleanup

The Bicep deployment places the lab resources in one dedicated resource group by default:

```text
rg-poc08-capstone
```

From the project root:

```powershell
.\infra\bicep\destroy_bicep.ps1 -ResourceGroupName rg-poc08-capstone
```

Type `DELETE` when prompted.

Or use Azure CLI directly:

```powershell
az group delete --name rg-poc08-capstone --yes
```

Verify:

```powershell
az group exists --name rg-poc08-capstone
```

Expected after deletion completes:

```text
false
```

## Services to pay special attention to

If enabled, make sure these are stopped/deleted when the lab is complete:

- Azure Databricks clusters/workspace;
- Azure Synapse resources;
- Azure Machine Learning compute/endpoints;
- Azure SQL Database;
- Event Hubs namespace;
- paid Azure AI Search tier;
- Microsoft Foundry model deployments;
- Function App/hosting resources;
- any separately created resources reused from earlier POCs.

Also check Azure Cost Management after cleanup. Deleting the POC-08 resource group does **not** delete resources from previous POCs that you chose to reuse.
