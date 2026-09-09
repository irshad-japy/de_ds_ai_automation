# Bicep resource map

| Capstone capability | Bicep implementation | Default beginner profile |
|---|---|---|
| Resource isolation | Resource Group | On |
| Batch data lake | ADLS Gen2 + `datalake` filesystem | On |
| Batch orchestration | Azure Data Factory + managed-identity ADLS linked service + raw→bronze pipeline | On |
| Streaming | Event Hubs + `shipment-events` | On |
| Lakehouse compute | Azure Databricks workspace module | Off; reuse POC-02 first |
| Analytical serving | Azure SQL module | Off |
| Alternate analytical serving | Synapse workspace module | Off |
| Unstructured extraction | Document Intelligence | On |
| Vector/hybrid retrieval | Azure AI Search | On |
| RAG/agent project | Microsoft Foundry resource + project | On |
| Chat + embedding deployments | Foundry deployment resources | Off until region/quota is verified |
| Optional ML | Azure ML workspace | Off; reuse POC-07 first |
| Optional stream function | Linux Function App | Off |
| Secrets/security | Key Vault + RBAC | On |
| Monitoring | Log Analytics + Application Insights | On |
| CI/CD | Azure DevOps Bicep validation/deploy stage | Included |

## Why some components are opt-in

The capstone source describes an integrated architecture and says to deploy only the minimal set required for the demo during the fresh deployment test. Databricks, Synapse, Azure ML, paid Search tiers and model deployments can all incur cost or depend on subscription/region quota. Their Bicep modules are included, but the beginner profile keeps them off until the core flow is proven.

## Bicep vs data deployment

Bicep manages Azure Resource Manager resources. Data-plane actions are done by the included post-deploy scripts:

- ADLS upload: `ingestion.batch.upload_orders`
- ADF run: `run_after_bicep.ps1`
- Event Hubs send/receive: `ingestion.events.*`
- Document extraction: `ai.document_intelligence.extract_invoice`
- Search indexing/query: `ai.rag.*`
- Azure SQL load: `serving.sql.load_gold`
- Function code zip deploy: `deploy_function_code.ps1`
