# Five-minute final demo checklist

1. **Architecture** — show `architecture/architecture.md`.
2. **Raw input** — show `data/synthetic/orders_001.csv` and shipment events.
3. **Pipeline run** — run batch upload or show ADF successful run.
4. **Gold table** — show Databricks Gold or `output/gold/customer_metrics.csv`.
5. **Search retrieval** — run `ai.rag.query_search` and show correct source.
6. **Assistant** — run policy, metric, and mixed questions; show citations/tool source.
7. **Monitoring** — show `monitoring/checklist.md`, logs or Foundry trace.
8. **Security** — show `security/rbac_matrix.md` and explain read-only agent tools.
9. **Cleanup** — show Cost Management / Bicep resource-group cleanup plan.

Interview story:

> I built a small Azure Data + AI platform using synthetic retail data. ADF and Event Hubs handled batch/streaming ingestion into ADLS. Databricks created governed Bronze/Silver/Gold Delta data. Fabric/Synapse/Azure SQL provided analytical serving. Document Intelligence handled unstructured invoices. Azure AI Search and Microsoft Foundry provided grounded RAG and a constrained read-only agent. I applied identity-based access, Key Vault, monitoring, IaC/CI-CD and cost controls across the stack.
