# Databricks handoff after Bicep

Bicep can create the Azure Databricks workspace resource. Notebook import, cluster creation/start, libraries and notebook execution are Databricks data-plane operations, so perform them after the Azure resource exists.

## Recommended beginner path

Reuse the workspace from POC-02 if it still exists. This avoids creating another paid workspace.

If you intentionally deployed the full Bicep profile, get the new workspace name:

```powershell
az deployment sub show --name "<DEPLOYMENT-NAME>" --query "properties.outputs.databricksWorkspaceName.value" -o tsv
```

Open Azure Portal -> Resource Group -> Databricks workspace -> Launch Workspace.

## Import the POC notebooks

Import these files into a workspace folder such as `/Shared/poc08`:

```text
lakehouse/bronze/01_bronze_orders.py
lakehouse/silver/02_silver_orders.py
lakehouse/gold/03_gold_orders.py
```

Run them in this order:

1. `01_bronze_orders.py`
2. `02_silver_orders.py`
3. `03_gold_orders.py`

Attach the same small lab cluster to each notebook.

## Verify

Confirm the Bronze, Silver and Gold Delta outputs/table locations used by your POC-02 conventions. Capture screenshots of:

- ADLS raw input;
- Bronze notebook success;
- Silver notebook success;
- Gold notebook success;
- final Gold rows/metrics.

The local `scripts.smoke_test` remains a quick proof of transformation logic before you spend Databricks compute.
