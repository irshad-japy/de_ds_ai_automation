# POC-01 — Secure Batch Landing Zone with ADF, ADLS Gen2 and Azure SQL

Beginner-friendly Azure Data Engineering project:

**Synthetic CSV → ADLS Gen2 landing → Azure Data Factory → Azure SQL staging/curated → archive/quarantine → monitoring**

This repository implements the attached POC specification while adding only the small control/audit pieces needed to prove **new-file processing, idempotency, data-quality rejection, watermark-on-success, secure identity access, and verification**.

---

## 1. What you will learn

By completing this POC you will practice:

- Azure Resource Groups and tags
- Azure Cost Management budget awareness
- ADLS Gen2 / hierarchical namespace
- landing, archive, and quarantine zones
- Azure Data Factory pipelines
- ADF parameters, linked services, datasets, Copy Activity, Get Metadata, Lookup, If Condition, Stored Procedure, Delete Activity
- Azure SQL staging + curated design
- SQL `MERGE` for idempotent loading
- watermark and processed-file control tables
- Microsoft Entra ID and system-assigned Managed Identity
- Azure RBAC and least-privilege thinking
- Azure Key Vault patterns without committing secrets
- ADF monitoring and optional Log Analytics
- Python generation/upload using `DefaultAzureCredential`
- Terraform as the primary IaC practice and Bicep as a comparison
- GitHub-safe project hygiene

For plain-English explanations of every Azure service used here, read `docs/azure_services_explained.md`.

---

## 2. Business scenario

A retail company receives a daily order CSV. The platform must:

1. accept a new file in ADLS landing,
2. check that the file exists,
3. skip a file that was already successfully processed,
4. load compatible rows into SQL staging,
5. reject bad data,
6. merge valid rows into a curated table without duplicates,
7. update the watermark only after success,
8. preserve the raw source in archive,
9. place errors/reject evidence in quarantine/logging,
10. expose execution evidence in ADF Monitor.

---

## 3. Project structure

```text
poc_01_secure_batch_adf_adls_sql/
├── README.md
├── architecture.md
├── .gitignore
├── .env.example
├── requirements.txt
├── config/
│   └── poc_config.example.json
├── data/
│   └── sample/
│       └── orders_expected_example.csv
├── python/
│   ├── generate_orders.py
│   ├── inspect_orders.py
│   └── upload_to_adls.py
├── sql/
│   ├── 001_create_tables.sql
│   ├── 002_merge_orders.sql
│   ├── 003_create_adf_user.sql
│   ├── 004_verification_queries.sql
│   └── 005_reset_lab.sql
├── adf/
│   ├── README.md
│   ├── pipeline_sanitized.json
│   ├── linkedServices/
│   │   ├── LS_ADLS_GEN2_MI.json
│   │   └── LS_AZURE_SQL_MI.json
│   └── datasets/
│       ├── DS_ADLS_OrdersCsv.json
│       ├── DS_ADLS_Binary.json
│       └── DS_SQL_Table.json
├── infra/
│   ├── terraform/
│   │   ├── README.md
│   │   ├── versions.tf
│   │   ├── variables.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   └── bicep/
│       ├── README.md
│       └── storage_only.bicep
├── scripts/
│   ├── verify_resources.ps1
│   └── cleanup_resource_group.ps1
└── docs/
    ├── azure_services_explained.md
    ├── portal_build_steps.md
    ├── validation.md
    ├── troubleshooting.md
    ├── security_and_github.md
    ├── monitoring.md
    ├── optional_shir.md
    ├── interview_questions.md
    └── cleanup.md
```

---

# PART A — Before touching Azure

## 4. Prerequisites on your Windows laptop

Install/check:

- Python 3.10+ (3.12 is fine)
- Azure CLI
- Git
- VS Code
- SQL Server Management Studio (SSMS) **or** Azure Data Studio / another SQL client that can authenticate to Azure SQL with Microsoft Entra ID
- Optional for IaC: Terraform
- Optional for Bicep comparison: Azure CLI Bicep support

Verify in PowerShell or Command Prompt:

```powershell
python --version
az version
git --version
terraform -version
```

If Terraform is not installed, you can finish the POC through the Azure portal first and return to the IaC mini-lab later.

---

## 5. Sign in to Azure safely

```powershell
az login
az account show -o table
az account list -o table
```

If you have more than one subscription:

```powershell
az account set --subscription "<YOUR_SUBSCRIPTION_ID_OR_NAME>"
az account show -o table
```

**Verification:** confirm the displayed subscription is your intended personal Azure subscription before creating anything.

---

## 6. Use the one-click Python toolchain setup

This project includes a ready-to-use setup script in the `python_toolchain_one_click` folder. Use that instead of manually creating a virtual environment.

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

The script configures Poetry for an in-project environment, selects Python 3.12, installs dependencies, and runs the project verification checks. This is the recommended setup workflow for this POC.

> Do not manually run `python -m venv .venv` unless you intentionally want a custom environment for troubleshooting.

---

## 7. Generate the sample order file locally

```powershell
python python/generate_orders.py --rows 30 --output data/generated/orders_001.csv
```

Expected message:

```text
Generated 30 rows ...
Expected valid curated rows after POC validation: 28
Bad row #1: quantity = -2
Bad row #2: unit_price = NOT_A_PRICE
```

Inspect it:

```powershell
python python/inspect_orders.py data/generated/orders_001.csv
```

**Local verification checklist:**

- 30 data rows are present.
- Header is exactly:
  `order_id,customer_id,order_ts,product_id,quantity,unit_price,status`
- One row has `quantity=-2`.
- One row has `unit_price=NOT_A_PRICE`.
- Inspector reports 28 rows expected to become curated rows.

Do not "fix" the two bad rows. They are needed to prove the error-handling behavior.

---

# PART B — Create Azure resources (beginner portal path)

Detailed click-by-click notes are also in `docs/portal_build_steps.md`.

## 8. Choose names once

Azure names such as Storage Account, Data Factory, SQL Server, and Key Vault must be globally unique.

Use this pattern and replace `<suffix>` with something unique, for example your initials + digits:

```text
Resource Group:  rg-azde-poc01-dev
Storage:        stazdepoc01<suffix>
ADF:            adf-azde-poc01-<suffix>
SQL Server:     sql-azde-poc01-<suffix>
SQL Database:   sqldb-azde-poc01-dev
Key Vault:      kv-azde-poc01-<suffix>
Log Analytics:  law-azde-poc01-dev
```

Recommended region for an India-based personal lab: choose an Azure region that supports all selected services and is convenient for you, such as Central India if available for your subscription. Use one region consistently where practical.

---

## 9. Create the Resource Group

Azure Portal → **Resource groups** → **Create**

Use:

```text
Name: rg-azde-poc01-dev
Region: your chosen region
```

Add tags:

```text
project      = azure-poc
environment  = dev
owner        = personal
autoDelete   = true
```

Create it.

**Verify:** Resource Group → Overview → confirm name, subscription, region, and tags.

---

## 10. Create a Cost Management budget

Open **Cost Management + Billing / Cost Management** at subscription or resource-group scope → **Budgets** → create a small monthly budget suitable for your account.

Add email threshold alerts (for example 50%, 80%, and 100%).

The purpose is awareness. Do not treat a budget as a hard spending stop.

**Verify:** the budget appears in the Budgets list with your selected scope and notification email.

---

## 11. Create ADLS Gen2

Portal → **Storage accounts** → **Create**

Suggested settings:

```text
Resource group: rg-azde-poc01-dev
Storage account: stazdepoc01<suffix>
Region: same lab region
Performance: Standard
Redundancy: LRS for this short-lived lab
Account kind: StorageV2 / General-purpose v2
Secure transfer required: Enabled
Minimum TLS: 1.2 or the current secure default
Public blob access: Disabled
```

On the Data Lake / Advanced area, ensure:

```text
Hierarchical namespace: Enabled
```

Create the account.

Then Storage Account → **Data storage / Containers** and create three private containers:

```text
landing
archive
quarantine
```

**Verify:** each container exists and is private.

---

## 12. Create Azure Data Factory

Portal → **Data factories** → **Create**

```text
Resource group: rg-azde-poc01-dev
Name: adf-azde-poc01-<suffix>
Region: same lab region
Git configuration: Configure later (simpler for first run)
```

Create it.

Open the Data Factory resource → **Properties** / **Managed identity** and note the system-assigned managed identity Object ID.

Azure Data Factory created through the portal has a system-assigned identity available for use. This identity is what the POC uses to access ADLS and Azure SQL.

**Verify:** you can see a Managed Identity Object ID for the Data Factory.

---

## 13. Grant ADF access to ADLS

Storage Account → **Access control (IAM)** → **Add role assignment**

Role:

```text
Storage Blob Data Contributor
```

Assign access to:

```text
Managed identity
```

Select:

```text
System-assigned managed identity → Data Factory → your ADF
```

Review + assign.

Why Contributor rather than Reader? The POC must read landing files, write archive/quarantine evidence, and delete the landing file after archival.

**Verify:** Storage Account → IAM → Role assignments → filter by your Data Factory name; confirm `Storage Blob Data Contributor`.

---

## 14. Grant your own developer identity access to ADLS

The Python uploader uses your signed-in Microsoft Entra identity through `az login`.

Storage Account → IAM → Add role assignment:

```text
Storage Blob Data Contributor
```

Member: your own signed-in user.

**Important:** being Owner/Contributor on the Azure resource does not automatically mean you have blob data-plane permission. Blob data access needs a data role such as Storage Blob Data Contributor.

**Verify:** your own user appears with the data role.

---

## 15. Create Azure SQL Database

Portal → **SQL databases** → **Create**

Create a new logical SQL server and database.

Suggested lab choices:

```text
Resource group: rg-azde-poc01-dev
Database: sqldb-azde-poc01-dev
Server: sql-azde-poc01-<suffix>.database.windows.net
Workload: Development
Compute: choose the smallest low-cost option available in your region/account
Backup redundancy: locally redundant if offered and appropriate for the lab
```

For a short POC, a small Basic/low-cost development configuration is enough. If you choose serverless, remember that a paused serverless database can cause an ADF activity to fail until the database has resumed.

During initial server creation you may be asked for a SQL admin login/password. Treat it only as a bootstrap credential:

- use a strong unique password,
- never put it in Git,
- do not put it in ADF for this POC,
- prefer Microsoft Entra authentication for normal work.

### SQL firewall for the beginner lab

To let Azure Integration Runtime reach Azure SQL, enable the server firewall option commonly labeled:

```text
Allow Azure services and resources to access this server
```

Also add your current client IP so your SQL client can connect.

This base lab uses public endpoints for learning simplicity. The hardened enterprise variant is Private Link + managed private endpoints.

**Verify:** the database status is Online and you can see your server firewall rules.

---

## 16. Configure a Microsoft Entra admin for Azure SQL

Open the **SQL logical server** (not only the database) → Microsoft Entra ID / Microsoft Entra admin → set an Entra user or group you control as the server Entra admin.

Save.

You need this so you can create a contained database user for the ADF Managed Identity.

**Verify:** the logical server shows the configured Microsoft Entra administrator.

---

## 17. Create Key Vault

Portal → **Key vaults** → **Create**

```text
Resource group: rg-azde-poc01-dev
Name: kv-azde-poc01-<suffix>
Region: same lab region
Permission model: Azure role-based access control (RBAC), if available/appropriate
Soft delete: keep default protection
Purge protection: use your account/lab policy; understand it can delay complete recreation of the same name
```

The main ADF path intentionally does **not** need a SQL password or Storage key. Key Vault is included so you understand where secrets would go when a connector cannot use identity-based auth.

Do not store fake secrets just to make the pipeline depend on Key Vault.

---

## 18. Optional: Create Log Analytics Workspace

Portal → **Log Analytics workspaces** → Create:

```text
Name: law-azde-poc01-dev
Resource group: rg-azde-poc01-dev
```

This is optional because diagnostic ingestion can add cost. You can complete core POC monitoring in ADF Monitor.

See `docs/monitoring.md`.

---

# PART C — Build the SQL layer

## 19. Connect to Azure SQL using Microsoft Entra authentication

Use SSMS/Azure Data Studio or another supported SQL client.

Server:

```text
sql-azde-poc01-<suffix>.database.windows.net
```

Database:

```text
sqldb-azde-poc01-dev
```

Authentication: choose a Microsoft Entra authentication method supported by your client and sign in as the Entra admin configured in Step 16.

---

## 20. Run SQL script 001 — tables

Open and execute:

```text
sql/001_create_tables.sql
```

This creates:

- `dbo.orders_stg`
- `dbo.orders`
- `dbo.orders_rejects`
- `dbo.etl_file_log`
- `dbo.etl_watermark`

**Verify:** in your SQL client, refresh Tables and confirm all five objects exist.

---

## 21. Run SQL script 002 — merge stored procedure

Execute:

```text
sql/002_merge_orders.sql
```

It creates:

```text
dbo.usp_merge_orders
```

The procedure:

- validates business rules,
- writes semantic bad rows to `dbo.orders_rejects`,
- `MERGE`s valid rows by `order_id`,
- records the source file as `SUCCEEDED`,
- updates the watermark in the same transaction,
- clears this run's staging rows.

**Verify:** Stored Procedures → `dbo.usp_merge_orders` exists.

---

## 22. Create the Azure SQL user for the ADF Managed Identity

Open:

```text
sql/003_create_adf_user.sql
```

Replace:

```text
<ADF_NAME>
```

with your actual Data Factory resource name, for example:

```text
adf-azde-poc01-ia26
```

Then execute the script while connected to **sqldb-azde-poc01-dev** as the Microsoft Entra admin.

This uses:

```sql
CREATE USER [your-adf-name] FROM EXTERNAL PROVIDER;
```

and grants only the POC permissions.

**Verify:**

```sql
SELECT name, type_desc
FROM sys.database_principals
WHERE name = '<YOUR_ADF_NAME>';
```

You should see the ADF identity as an external user.

---

# PART D — Upload sample data to ADLS

## 23. Upload with the provided Python script

Ensure Azure CLI login is still valid:

```powershell
az account show -o table
```

Run:

```powershell
python python/upload_to_adls.py `
  --storage-account <YOUR_STORAGE_ACCOUNT> `
  --local-file data/generated/orders_001.csv `
  --container landing `
  --remote-path orders/2026/08/28/orders_001.csv
```

You can use today's actual date instead of the sample date, but keep the same folder pattern:

```text
orders/YYYY/MM/DD/orders_001.csv
```

The script uses `DefaultAzureCredential`, so after `az login` it can use your Azure CLI identity. It does not need a storage key in the repository.

**Verify in Portal:**

Storage Account → Containers → `landing` → browse to:

```text
orders/2026/08/28/orders_001.csv
```

Confirm the file is present and non-empty.

If you get HTTP 403, see `docs/troubleshooting.md` and re-check your **data-plane** role assignment.

---

# PART E — Build ADF objects

The easiest beginner path is to build the objects in the ADF UI using `adf/README.md`. Sanitized JSON examples are included for learning/GitHub evidence.

## 24. Open ADF Studio

Data Factory resource → **Launch studio**.

ADF Studio main areas:

- **Author** = pipelines, datasets, data flows
- **Manage** = linked services, integration runtimes
- **Monitor** = pipeline/activity runs

---

## 25. Create ADLS linked service using ADF Managed Identity

ADF Studio → Manage → Linked services → New → **Azure Data Lake Storage Gen2**

Name:

```text
LS_ADLS_GEN2_MI
```

Authentication:

```text
System-assigned managed identity
```

Storage account / URL: select your ADLS Gen2 account.

Test connection and Create.

The corresponding sanitized example is:

```text
adf/linkedServices/LS_ADLS_GEN2_MI.json
```

**Verify:** Test connection succeeds.

---

## 26. Create Azure SQL linked service using ADF Managed Identity

ADF Studio → Manage → Linked services → New → **Azure SQL Database**

Name:

```text
LS_AZURE_SQL_MI
```

Use the recommended connector version if the UI asks.

Configure:

```text
Server: <your SQL server>.database.windows.net
Database: sqldb-azde-poc01-dev
Authentication: System-assigned managed identity
Encryption: enabled/mandatory current secure default
Trust server certificate: false
```

Test connection and Create.

If this fails:

1. confirm SQL server Microsoft Entra admin exists,
2. confirm `CREATE USER [ADF_NAME] FROM EXTERNAL PROVIDER` was run in the **target database**,
3. confirm SQL firewall allows ADF Azure Integration Runtime for this beginner lab.

**Verify:** Test connection succeeds.

---

## 27. Create parameterized datasets

Create these three datasets by following `adf/README.md`:

```text
DS_ADLS_OrdersCsv
DS_ADLS_Binary
DS_SQL_Table
```

Important parameters:

```text
p_container
p_folder
p_file
p_target_table
```

The CSV dataset must have `First row as header = true` and comma delimiter.

---

## 28. Create the pipeline

Create:

```text
PL_INGEST_ORDERS_BATCH
```

Pipeline parameters:

```text
p_container     default landing
p_folder        e.g. orders/2026/08/28
p_file          e.g. orders_001.csv
p_target_table  default orders_stg
```

Build the activities as described in `adf/README.md`:

```text
Get_Metadata_File
  ↓
If_File_Exists
  └─ True:
       Lookup_Already_Processed
         ↓
       If_Not_Processed
         └─ True:
              Copy_CSV_To_Staging
              ↓
              SP_Validate_Merge
              ↓
              Copy_Landing_To_Archive
              ↓
              Delete_Landing_File
```

The processing branch also includes failure handling to copy the source raw file to quarantine.

### Copy Activity behavior

`Copy_CSV_To_Staging`:

- reads the CSV from landing,
- adds `source_file` and `pipeline_run_id` audit columns,
- maps into `dbo.orders_stg`,
- enables skip incompatible rows,
- redirects incompatible-row details to the ADLS `quarantine` path.

This is what handles the `NOT_A_PRICE` test row.

### Stored Procedure behavior

`SP_Validate_Merge` calls:

```text
dbo.usp_merge_orders
```

Parameters:

```text
@pipeline_name = @pipeline().Pipeline
@source_file   = full logical source path
@run_id        = @pipeline().RunId
```

This is what rejects `quantity=-2` as a business-rule failure and merges only valid rows.

---

## 29. Validate, publish, and run the ADF pipeline

Click **Validate all**.

Fix any validation issue before publishing.

Click **Publish all**.

Then **Add trigger → Trigger now** with values matching the uploaded file:

```text
p_container     = landing
p_folder        = orders/2026/08/28
p_file          = orders_001.csv
p_target_table  = orders_stg
```

Open **Monitor** and watch the pipeline run.

---

# PART F — Required verification tests

These tests are mandatory for declaring the POC complete.

## TEST 1 — First run loads expected rows

After the first successful run, execute:

```sql
SELECT COUNT(*) AS curated_count FROM dbo.orders;
SELECT COUNT(*) AS staging_count FROM dbo.orders_stg;
SELECT COUNT(*) AS sql_reject_count FROM dbo.orders_rejects;
SELECT * FROM dbo.etl_file_log ORDER BY processed_ts DESC;
SELECT * FROM dbo.etl_watermark;
```

For the default generated 30-row file, expect:

```text
curated_count   = 28
staging_count   = 0 after stored procedure cleanup
sql_reject_count = 1   (negative quantity row)
etl_file_log status = SUCCEEDED
watermark exists and is recent
```

Also inspect `quarantine` in ADLS. The ADF incompatible-row redirect should contain evidence related to the non-numeric `unit_price` row.

**Pass condition:** 28 curated rows and the run is Succeeded.

---

## TEST 2 — Raw file was archived

Check ADLS:

```text
archive/orders/2026/08/28/orders_001.csv
```

Expected:

- file exists in `archive`,
- file no longer exists in `landing` after successful archive + delete,
- raw content remains preserved for audit.

**Pass condition:** archive exists and landing source is removed only after success.

---

## TEST 3 — Re-upload the same file; no duplicates

Re-upload the exact same local file to the same landing path:

```powershell
python python/upload_to_adls.py `
  --storage-account <YOUR_STORAGE_ACCOUNT> `
  --local-file data/generated/orders_001.csv `
  --container landing `
  --remote-path orders/2026/08/28/orders_001.csv `
  --overwrite
```

Run the pipeline again with the same parameters.

The processed-file lookup should detect the successful `source_file` and skip the ingestion branch.

Verify:

```sql
SELECT COUNT(*) AS curated_count FROM dbo.orders;
SELECT COUNT(*) AS processed_file_rows
FROM dbo.etl_file_log
WHERE source_file = 'landing/orders/2026/08/28/orders_001.csv';
```

Expected:

```text
curated_count = still 28
processed_file_rows = 1
```

**Pass condition:** no duplicate business rows.

This demonstrates both **file-level idempotency** and, independently, the target table's `MERGE` business-key protection.

---

## TEST 4 — Bad rows are rejected/quarantined

Check SQL business rejects:

```sql
SELECT *
FROM dbo.orders_rejects
ORDER BY reject_ts DESC;
```

Expect one row with a reason containing:

```text
quantity must be greater than 0
```

Check the ADLS `quarantine` path for the Copy Activity incompatible-row redirect caused by:

```text
unit_price = NOT_A_PRICE
```

**Pass condition:** neither deliberately bad record appears in `dbo.orders`.

---

## TEST 5 — Watermark changes only on success

First capture current value:

```sql
SELECT * FROM dbo.etl_watermark;
```

Now run a controlled failure test. The cleanest beginner test is the RBAC test in TEST 6 below.

After the failed pipeline run, query again:

```sql
SELECT * FROM dbo.etl_watermark;
```

The timestamp must not be advanced by the failed run because the watermark update lives in the successful merge transaction.

**Pass condition:** failed pipeline run does not advance `last_success_ts`.

---

## TEST 6 — Remove storage permission → controlled failure → restore → retry succeeds

> Do this only after you have already completed the successful tests above.

Storage Account → IAM → locate the ADF Managed Identity's `Storage Blob Data Contributor` role assignment → remove that role assignment.

Re-upload a **newly named** test file, for example `orders_002.csv`, and run the pipeline for it.

Expected:

- ADF cannot access ADLS,
- pipeline fails with an authorization/permission error,
- `dbo.etl_watermark` does not advance for that failed run,
- no file is falsely logged as `SUCCEEDED`.

Restore the same ADF role assignment:

```text
Storage Blob Data Contributor
```

Retry the pipeline.

Expected after permission is effective:

- ADLS linked-service access works again,
- pipeline succeeds,
- file is processed/archive behavior resumes.

**Pass condition:** permission removal creates a clear controlled failure and permission restoration allows a successful retry.

---

## TEST 7 — Monitor ADF execution metrics

ADF Studio → Monitor → Pipeline runs → select your run → Activity runs.

Capture or record:

- pipeline status,
- activity status,
- rows read,
- rows copied/written,
- duration,
- integration runtime used,
- any skipped/incompatible row counts or logs,
- failure reason for the RBAC test.

**Pass condition:** you can explain from the Monitor view what happened in each activity.

---

# PART G — Python code included in this repository

## 30. `python/generate_orders.py`

Creates a deterministic synthetic retail-order CSV and deliberately inserts two bad rows.

Example:

```powershell
python python/generate_orders.py --rows 50 --output data/generated/orders_002.csv --seed 42
```

## 31. `python/inspect_orders.py`

Performs a local sanity check and predicts which rows are type-invalid or business-invalid.

```powershell
python python/inspect_orders.py data/generated/orders_002.csv
```

## 32. `python/upload_to_adls.py`

Uploads with Microsoft Entra credentials through Azure Identity:

```powershell
python python/upload_to_adls.py --help
```

No account key is required in source code.

---

# PART H — Terraform mini-lab

The Terraform code is under:

```text
infra/terraform/
```

It can provision the core resources and ADF storage RBAC. Read:

```text
infra/terraform/README.md
```

Recommended learning order:

1. finish the portal version first,
2. understand every resource,
3. delete the lab Resource Group,
4. recreate the infrastructure using Terraform,
5. compare the Terraform plan with the resources you built manually.

Never commit:

```text
terraform.tfvars
terraform.tfstate
terraform.tfstate.*
```

The `.gitignore` already excludes them.

---

# PART I — Bicep comparison

A small Storage-only comparison is included:

```text
infra/bicep/storage_only.bicep
```

The goal is syntax comparison, not replacing Terraform as the main IaC experience for this POC.

---

# PART J — GitHub safety checklist

Before `git add .`, read:

```text
docs/security_and_github.md
```

Run:

```powershell
git status
```

Then inspect any candidate file that could contain secrets.

Never commit:

- SQL admin passwords
- Storage account keys
- SAS tokens
- service principal client secrets
- real `.env`
- `terraform.tfvars`
- Terraform state
- private keys/certificates
- screenshots containing account IDs, email addresses, subscription IDs, private endpoints, tokens, or secret values

The ADF JSON in this repository uses placeholders and Managed Identity, not real credentials.

---

# PART K — Useful verification scripts

Validate Azure resource names/tags after setting variables in PowerShell:

```powershell
.\scripts\verify_resources.ps1 `
  -ResourceGroup rg-azde-poc01-dev `
  -StorageAccount <YOUR_STORAGE_ACCOUNT> `
  -DataFactory <YOUR_ADF_NAME> `
  -SqlServer <YOUR_SQL_SERVER>
```

This script only reads metadata.

---

# PART L — Cleanup

When you have captured sanitized evidence and committed the safe code, delete the entire Resource Group to stop ongoing charges.

Read:

```text
docs/cleanup.md
```

The supplied PowerShell cleanup script has an explicit confirmation switch:

```powershell
.\scripts\cleanup_resource_group.ps1 -ResourceGroup rg-azde-poc01-dev -ConfirmDelete
```

Always check the Resource Group name before running a delete command.

---

# Completion checklist

You may call this POC complete only when all are true:

- [ ] Resource Group and cost budget created
- [ ] ADLS Gen2 has hierarchical namespace enabled
- [ ] `landing`, `archive`, `quarantine` containers created
- [ ] Data Factory Managed Identity identified
- [ ] ADF has required ADLS RBAC
- [ ] Your developer identity can upload with Entra authentication
- [ ] Azure SQL Database created
- [ ] Microsoft Entra admin configured on SQL logical server
- [ ] SQL tables/procedure created
- [ ] ADF contained database user created
- [ ] ADLS and SQL ADF linked-service tests pass
- [ ] Parameterized datasets created
- [ ] Pipeline validates and publishes
- [ ] First run succeeds
- [ ] Curated count is expected (28 for default 30-row sample)
- [ ] One business-invalid row exists in `orders_rejects`
- [ ] One type-incompatible row has quarantine/redirect evidence
- [ ] Raw input is archived
- [ ] Re-uploading the same file does not duplicate rows
- [ ] Watermark advances only on successful merge
- [ ] RBAC removal causes controlled failure
- [ ] RBAC restoration allows retry to succeed
- [ ] ADF Monitor evidence reviewed
- [ ] No secrets are committed
- [ ] Resource Group deleted after evidence capture

---

# Interview-ready explanation

After you complete the lab, you should be able to say:

> I built a secure parameterized batch ingestion pipeline on Azure. Daily CSV files land in ADLS Gen2 and ADF uses its system-assigned Managed Identity to read them. A file-control table prevents already processed files from being reloaded. Copy Activity loads compatible data to Azure SQL staging and redirects incompatible rows, while a stored procedure applies business validation and idempotent MERGE logic into the curated orders table. The same transaction records the successful file and updates the watermark. Successful raw files are archived, failures are isolated, and runs are verified in ADF Monitor. I kept credentials out of source control and added Terraform/Bicep practice plus cleanup and cost guardrails.

Do not put the CV bullets from the source specification on your CV until you have actually completed and verified the POC.

---

## References used to keep the implementation aligned with current Microsoft guidance

- Microsoft Learn — ADF managed identity: https://learn.microsoft.com/azure/data-factory/data-factory-service-identity
- Microsoft Learn — ADLS Gen2 connector: https://learn.microsoft.com/azure/data-factory/connector-azure-data-lake-storage
- Microsoft Learn — Azure SQL Database connector: https://learn.microsoft.com/azure/data-factory/connector-azure-sql-database
- Microsoft Learn — Copy Activity: https://learn.microsoft.com/azure/data-factory/copy-activity-overview
- Microsoft Learn — Copy fault tolerance: https://learn.microsoft.com/azure/data-factory/copy-activity-fault-tolerance
- Microsoft Learn — Get Metadata activity: https://learn.microsoft.com/azure/data-factory/control-flow-get-metadata-activity
- Microsoft Learn — Delete Activity: https://learn.microsoft.com/azure/data-factory/delete-activity
- Microsoft Learn — Blob data RBAC: https://learn.microsoft.com/azure/storage/blobs/assign-azure-role-data-access

-----------------------------------------------------------------------------------------------------------------
after complete pocs delete azure resources to manage cost

# 1. List all resource groups in your account
az group list --output table

# 2. Delete the entire resource group (non-blocking)
az group delete --name rg-azde-poc-dev --yes --no-wait

# 3. Check if the deletion is completed (returns 'true' while deleting, 'false' when finished)
az group exists --name rg-azde-poc-dev