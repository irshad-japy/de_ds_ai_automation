# POC-04 - Intelligent Document ETL with Azure AI Document Intelligence

Beginner-friendly Azure POC that converts **synthetic invoice PDFs** into validated analytical invoice tables.

This project implements the attached POC-04 requirements:

```text
Synthetic invoice PDF/image
   |
   v
ADLS Gen2 / documents/incoming
   |
   v
Azure AI Document Intelligence - prebuilt-invoice
   |
   +--> raw extracted JSON
   |
   v
Normalized stable schema
   |
   v
Validation + confidence rules
   |                  |
 valid              invalid
   |                  |
   v                  v
Azure SQL          documents/failed
header + lines      failure reason
   |
   v
documents/processed
```

The source POC also asks for Azure Functions, Key Vault, Managed Identity/RBAC and Application Insights. They are included, but the recommended learning path is:

1. **Run locally first** so each service is easy to troubleshoot.
2. **Then deploy the Azure Function** to automate the same pipeline.

---

## 1. What you will learn

- Create synthetic invoices (never use real financial documents).
- Create ADLS Gen2 storage and upload documents.
- Test the Document Intelligence **prebuilt invoice** model manually.
- Call Document Intelligence from Python.
- Persist raw extraction output and map it to a stable schema.
- Validate invoice totals and confidence scores.
- Route invalid documents to quarantine (`failed/`).
- Load valid header/line data into Azure SQL.
- Make processing idempotent with SHA-256 source hashes.
- Automate ingestion with an Azure Function Blob trigger.
- Use Managed Identity/RBAC for Azure-hosted access.
- Inspect logs/telemetry with Application Insights.
- Delete the complete POC resource group after testing.

---

## 2. Project structure

```text
POC_04_DOCUMENT_INTELLIGENCE_ETL_PROJECT/
|
|-- README.md
|-- .env.example
|-- .gitignore
|-- requirements.txt
|-- function_app.py                     # optional Azure Function automation
|-- host.json
|-- local.settings.json.example
|
|-- src/
|   |-- config.py
|   |-- storage_client.py
|   |-- extract_invoice.py              # calls prebuilt-invoice and normalizes fields
|   |-- validate_invoice.py             # business/confidence validation
|   |-- sql_loader.py                   # idempotent Azure SQL load
|   |-- pipeline.py                     # end-to-end orchestration
|   |-- upload_samples.py               # uploads local samples -> incoming/
|   `-- run_batch.py                    # processes one/all incoming documents
|
|-- samples/input/
|   |-- invoice_001.pdf
|   |-- invoice_002.pdf
|   |-- invoice_003.pdf
|   |-- invoice_004.pdf
|   |-- invoice_005.pdf
|   `-- invoice_006_malformed.pdf       # purposely missing ID + wrong total
|
|-- scripts/
|   |-- generate_sample_invoices.py
|   |-- 01_create_azure_resources.ps1
|   |-- 02_show_resource_values.ps1
|   `-- 99_cleanup.ps1
|
|-- schemas/
|   `-- invoice_schema.json
|
|-- sql/
|   |-- create_tables.sql
|   |-- create_function_identity_user.sql
|   `-- verify.sql
|
|-- docs/
|   |-- POC_04_SOURCE.md
|   |-- architecture.md
|   |-- portal_manual_steps.md
|   |-- confidence_rules.md
|   |-- troubleshooting.md
|   |-- interview_questions.md
|   `-- sample_redacted_output.json
|
`-- tests/
    `-- test_validation.py
```

---

# PART A - Prerequisites on your Windows laptop

## Step A1 - Check Python

Recommended for this project: Python 3.12.

```powershell
python --version
```

Expected:

```text
Python 3.12.x
```

## Step A2 - Install Azure CLI

Check:

```powershell
az version
```

If you get **`az is not recognized`**, install Azure CLI first, then close and reopen PowerShell/Command Prompt.

Login:

```powershell
az login
az account show
```

If you have multiple subscriptions:

```powershell
az account list -o table
az account set --subscription "<YOUR_SUBSCRIPTION_NAME_OR_ID>"
```

## Step A3 - Use the one-click Python setup

This project includes a ready-made setup script in the `python_toolchain_one_click` folder. Use it instead of manually creating a virtual environment.

### Windows

```powershell
cd .\python_toolchain_one_click\windows
./setup_venv_poery.bat
```

### macOS / Linux

```bash
cd ./python_toolchain_one_click/unix
bash ./setup_venv_poery.sh
```

The script will configure Poetry for in-project virtual environments, select Python 3.12, install dependencies, and run the local validation checks. This is the recommended setup for the POC.

> Do not manually run `python -m venv .venv` or `pip install -r requirements.txt` unless you are intentionally troubleshooting a custom setup.

## Step A4 - Run local unit tests (no Azure required)

```powershell
python -m pytest -q
```

Expected:

```text
3 passed
```

This proves the validation logic works before you spend time debugging Azure.

---

# PART B - Understand/generate the synthetic invoices

Six synthetic PDFs are already included. To regenerate them:

```powershell
python scripts/generate_sample_invoices.py
```

Expected files:

```text
samples/input/invoice_001.pdf
...
samples/input/invoice_006_malformed.pdf
```

- `invoice_001` to `invoice_005`: intended success documents.
- `invoice_006_malformed`: intentionally missing invoice ID and has an incorrect invoice total so it should go to quarantine.

**Important:** all names/addresses/account information are fictional.

---

# PART C - Create Azure resources

You have two choices.

## Option 1 - Beginner/manual portal setup

Follow:

```text
docs/portal_manual_steps.md
```

This is best if you want to learn where every setting is in Azure Portal.

## Option 2 - Azure CLI/PowerShell helper

Review the script first, especially region and cost-related settings:

```powershell
Get-Content scripts/01_create_azure_resources.ps1
```

Then run:

```powershell
.\scripts\01_create_azure_resources.ps1
```

It creates:

- Resource Group
- ADLS Gen2 data Storage Account
- `documents` container
- Azure AI Document Intelligence resource
- Key Vault
- Azure SQL Server + Database
- Function runtime Storage Account
- Azure Function App
- system-assigned Managed Identity and major RBAC assignments

The script creates `.poc04-resources.txt` containing resource names/endpoints but **no passwords/keys**.

### Cost guardrail

Document Intelligence F0 is used if available. Azure SQL and other services can incur charges. Review Azure Portal cost estimates and delete the resource group after the POC.

---

# PART D - First manual Document Intelligence Studio test

Do this **before Python automation**.

1. Open Azure Portal -> your Document Intelligence resource.
2. Open Document Intelligence Studio/current Analyze experience.
3. Choose **Invoice / prebuilt invoice**.
4. Upload:

```text
samples/input/invoice_001.pdf
```

5. Run analysis.
6. Look for fields such as:
   - Invoice ID
   - Invoice Date
   - Vendor Name
   - Customer Name
   - Items
   - SubTotal
   - TotalTax
   - InvoiceTotal
7. Inspect confidence scores.

**Pass condition:** the service returns structured invoice fields, not only OCR text.

---

# PART E - Configure `.env` for local execution

Copy the template:

```powershell
Copy-Item .env.example .env
```

Open `.env` and fill these values.

## Storage

```text
AZURE_STORAGE_ACCOUNT_NAME=<data-storage-name>
AZURE_STORAGE_CONTAINER=documents
```

Your user must have `Storage Blob Data Contributor` on the storage account. The resource creation script assigns this.

## Document Intelligence

```text
DOCUMENTINTELLIGENCE_ENDPOINT=https://<resource>.cognitiveservices.azure.com/
```

### Easiest beginner local authentication

Retrieve the DI key from Key Vault created by the helper script:

```powershell
az keyvault secret show `
  --vault-name <YOUR_KEY_VAULT_NAME> `
  --name document-intelligence-key `
  --query value -o tsv
```

Put it only in your local `.env`:

```text
DOCUMENTINTELLIGENCE_API_KEY=<LOCAL_KEY>
```

`.env` is ignored by Git and must never be committed.

### Better passwordless local authentication

Leave the key empty and use:

```powershell
az login
```

Your identity needs `Cognitive Services User`. Passwordless/Entra usage also depends on the correct single-service/custom endpoint configuration.

## Azure SQL passwordless local connection

Example:

```text
AZURE_SQL_CONNECTIONSTRING=Server=<sql-server>.database.windows.net;Database=sqldb-poc04;Authentication=ActiveDirectoryDefault;Encrypt=yes;TrustServerCertificate=no;
```

You must be configured as the Azure SQL Microsoft Entra administrator (or have a contained database user) and your current public IP must be allowed for local testing.

## Validation

Keep initially:

```text
CRITICAL_CONFIDENCE_THRESHOLD=0.70
AMOUNT_TOLERANCE=0.05
ENABLE_SQL_LOAD=true
```

---

# PART F - Create Azure SQL tables

Connect to the database as the Microsoft Entra administrator using one of:

- Azure Portal Query Editor
- SQL Server Management Studio
- VS Code MSSQL extension

Run:

```text
sql/create_tables.sql
```

Verify:

```sql
SELECT name FROM sys.tables WHERE name IN ('invoice_header', 'invoice_line');
```

Expected: two rows.

---

# PART G - Upload the six invoices to ADLS Gen2

Run:

```powershell
python -m src.upload_samples
```

Expected console output similar to:

```text
Uploaded: samples\input\invoice_001.pdf -> documents/incoming/invoice_001.pdf
...
Uploaded: samples\input\invoice_006_malformed.pdf -> documents/incoming/invoice_006_malformed.pdf
```

## Verify in Azure Portal

Storage account -> Containers -> `documents` -> `incoming`.

Expected: 6 PDF blobs.

---

# PART H - Run the complete ETL locally

Process all documents:

```powershell
python -m src.run_batch --prefix incoming/
```

Or process only one:

```powershell
python -m src.run_batch --blob incoming/invoice_001.pdf
```

What the code does for each blob:

1. Downloads source bytes from ADLS/Blob Storage.
2. Computes SHA-256 source hash.
3. Checks whether this exact document was already processed.
4. Calls Document Intelligence `prebuilt-invoice`.
5. Stores raw AI result under `processed/raw/`.
6. Maps AI fields to the stable internal invoice schema.
7. Validates required fields, confidence and totals.
8. Invalid -> writes failure JSON under `failed/`.
9. Valid -> loads header + lines to Azure SQL.
10. Writes normalized JSON under `processed/`.

---

# PART I - Verify every required POC behavior

## Test 1 - At least five invoices process successfully

Azure Portal -> Storage -> `documents/processed/`.

Expected: normalized JSON for the valid sample invoices plus raw JSON under `processed/raw/`.

Run SQL:

```sql
SELECT COUNT(*) AS header_count FROM dbo.invoice_header;
```

Target: at least 5 valid headers (AI extraction confidence can vary; inspect failed reasons if fewer).

## Test 2 - One malformed invoice goes to failed/quarantine

Storage -> `documents/failed/`.

Expected a file similar to:

```text
invoice_006_malformed.<hash>.failure.json
```

Open it. It contains `failure_reason` and the normalized invoice where available.

If the AI interprets the malformed invoice in an unexpected way, see `docs/troubleshooting.md` for deterministic ways to test quarantine.

## Test 3 - Reprocessing does not duplicate output

Run the same batch again:

```powershell
python -m src.run_batch --prefix incoming/
```

Expected statuses for previously valid documents:

```text
skipped_duplicate
```

Then run:

```sql
SELECT source_hash, COUNT(*) AS duplicate_count
FROM dbo.invoice_header
GROUP BY source_hash
HAVING COUNT(*) > 1;
```

Expected: **0 rows**.

## Test 4 - Header total reconciles with line totals

Run `sql/verify.sql`, or:

```sql
SELECT
    h.invoice_number,
    h.subtotal,
    SUM(COALESCE(l.amount, l.quantity * l.unit_price)) AS calculated_line_sum,
    h.total
FROM dbo.invoice_header h
LEFT JOIN dbo.invoice_line l ON h.invoice_key = l.invoice_key
GROUP BY h.invoice_number, h.subtotal, h.total;
```

Expected: calculated line sum should approximately match subtotal for valid documents.

## Test 5 - No real documents are used

Only use `samples/input/`. Do not upload employer/customer invoices, bank statements, IDs, or real account numbers.

---

# PART J - Optional: deploy/enable Azure Function automation

Complete the local batch first.

The project uses the **Python v2 Azure Functions programming model** in `function_app.py`.

The trigger listens to:

```text
documents/incoming/{name}
```

and uses the identity-based connection name:

```text
InvoiceStorage
```

## Step J1 - Make sure Function managed identity has access

The helper script assigns:

- ADLS data account: `Storage Blob Data Owner`
- ADLS data account: `Storage Queue Data Contributor`
- Document Intelligence: `Cognitive Services User`

## Step J2 - Create Function identity user in Azure SQL

Open:

```text
sql/create_function_identity_user.sql
```

Replace:

```text
<FUNCTION_APP_NAME>
```

with the actual Function App name and execute as Azure SQL Microsoft Entra admin.

This grants `db_datareader` and `db_datawriter` to the Function managed identity.

## Step J3 - Check app settings

Function App -> Configuration / Environment variables should include:

```text
AZURE_STORAGE_ACCOUNT_NAME=<data-storage>
AZURE_STORAGE_CONTAINER=documents
DOCUMENTINTELLIGENCE_ENDPOINT=<endpoint>
AZURE_SQL_CONNECTIONSTRING=Server=<server>.database.windows.net;Database=sqldb-poc04;Authentication=ActiveDirectoryMSI;Encrypt=yes;TrustServerCertificate=no;
ENABLE_SQL_LOAD=true
InvoiceStorage__blobServiceUri=https://<data-storage>.blob.core.windows.net
InvoiceStorage__queueServiceUri=https://<data-storage>.queue.core.windows.net
```

No Document Intelligence key is required when the Function uses Managed Identity.

## Step J4 - Deploy the Function

Install Azure Functions Core Tools if you do not have it:

```powershell
func --version
```

From the project root:

```powershell
func azure functionapp publish <YOUR_FUNCTION_APP_NAME> --python
```

## Step J5 - Function test

Upload/overwrite a new synthetic PDF with a new file name, for example:

```powershell
Copy-Item samples/input/invoice_001.pdf samples/input/invoice_function_test.pdf
python -m src.upload_samples
```

Then inspect Function App -> Monitor / Application Insights.

Look for logs:

```text
Invoice trigger received blob
Invoice pipeline result
```

Verify a new `processed/*.json` is created and Azure SQL contains the record.

---

# PART K - Observability checks

The source POC asks to measure:

- documents processed
- success/failure
- processing latency
- low-confidence field count

This project records latency and low-confidence count in each normalized JSON under `telemetry` and writes Function execution logs to Application Insights when run as an Azure Function.

For a production system, add custom metrics/counters and dashboards rather than relying only on log text.

---

# PART L - Common errors

See:

```text
docs/troubleshooting.md
```

Most common beginner problems:

- Azure CLI not installed / `az` not recognized.
- Missing Storage Blob Data Contributor.
- Wrong Document Intelligence endpoint/key.
- Missing Cognitive Services User for Entra auth.
- SQL server firewall does not allow your current IP.
- SQL Microsoft Entra admin not configured.
- Azure RBAC assignment still propagating.
- F0 Document Intelligence tier already used in that subscription/region.

---

# PART M - Cleanup to avoid cost

After screenshots/verification are complete:

```powershell
.\scripts\99_cleanup.ps1
```

Or directly:

```powershell
az group delete --name rg-poc04-docintel --yes --no-wait
```

This deletes the POC resource group and all resources inside it.

---

# POC completion checklist

- [ ] 6 synthetic invoice PDFs available locally.
- [ ] ADLS Gen2 storage created with `documents` container.
- [ ] `incoming/`, `processed/`, `failed/` paths verified.
- [ ] One invoice tested manually using prebuilt-invoice.
- [ ] Python environment installed and `pytest -q` passes.
- [ ] 6 sample invoices uploaded.
- [ ] At least 5 invoices processed successfully (subject to AI extraction confidence).
- [ ] Malformed/low-confidence test is present in `failed/` with failure reason.
- [ ] Raw Document Intelligence JSON persisted.
- [ ] Normalized JSON persisted.
- [ ] Azure SQL `invoice_header` and `invoice_line` populated.
- [ ] Line totals reconcile to subtotal.
- [ ] Re-run skips duplicates / SQL has no duplicate `source_hash`.
- [ ] Function managed identity configured.
- [ ] Function Blob trigger tested (optional after local proof).
- [ ] Application Insights logs reviewed.
- [ ] No real financial document used.
- [ ] Resource group deleted after validation if no longer needed.

---

# GitHub safety checklist

Safe to commit:

- Python code
- synthetic invoices
- JSON schema
- redacted/synthetic output examples
- SQL scripts
- README/docs

Never commit:

- `.env`
- `local.settings.json`
- keys/secrets/passwords
- real invoices
- private account/customer information

---

# Useful official references

- Azure AI Document Intelligence SDK quickstart (v4): https://learn.microsoft.com/azure/ai-services/document-intelligence/quickstarts/get-started-sdks-rest-api?view=doc-intel-4.0.0
- Document Intelligence Studio quickstart: https://learn.microsoft.com/azure/ai-services/document-intelligence/quickstarts/get-started-studio?view=doc-intel-4.0.0
- Prebuilt invoice model: https://learn.microsoft.com/azure/ai-services/document-intelligence/prebuilt/invoice?view=doc-intel-4.0.0
- Azure Blob Storage with Python: https://learn.microsoft.com/azure/storage/blobs/storage-blob-python-get-started
- Azure Functions Python reference: https://learn.microsoft.com/azure/azure-functions/functions-reference-python
- Azure SQL Python quickstart: https://learn.microsoft.com/azure/azure-sql/database/azure-sql-python-quickstart

---

# CV text - use only after you complete and verify the POC

- Built an Azure AI Document Intelligence ingestion pipeline to extract structured data from synthetic invoices into validated Azure SQL header/line tables.
- Added confidence-based quality rules, financial reconciliation, quarantine handling and SHA-256 based idempotent document processing.
- Integrated Azure Functions, ADLS Gen2 and identity-based Azure access with telemetry for processing success, latency and exceptions.
