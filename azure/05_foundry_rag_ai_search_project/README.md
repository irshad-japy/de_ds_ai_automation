# POC-05 — Enterprise RAG with Microsoft Foundry + Azure AI Search

A beginner-friendly proof of concept that builds a small Retrieval-Augmented Generation (RAG) application over synthetic business documents.

The project demonstrates:

- Microsoft Foundry model deployments
- Azure AI Search vector search
- Azure AI Search hybrid search (keyword + vector)
- Chunking and metadata
- Embeddings
- Grounded prompts with source citations
- Retrieval evaluation
- Failure-case testing
- FastAPI local API
- Optional Microsoft Entra ID / managed identity style authentication
- Optional Application Insights telemetry

> This project intentionally uses synthetic documents only. Do not upload employer/customer/confidential documents to this public POC repository.

---

## 1. What you will build

```text
Synthetic business documents
        |
        v
Python chunking + metadata
        |
        v
Embedding model deployed in Microsoft Foundry
        |
        v
Azure AI Search index
(text fields + vector field)
        |
        +-------------------+
        |                   |
        v                   v
 Vector retrieval      Keyword retrieval
        |                   |
        +--------+----------+
                 |
                 v
          Hybrid retrieval
                 |
                 v
      Foundry chat model
                 |
                 v
       Answer + citations
```

---

## 2. Recommended beginner resource names

Use your own globally unique suffix where required.

| Resource | Example |
|---|---|
| Resource group | `rg-poc05-foundry-rag` |
| Foundry project | `poc05-rag-project` |
| Foundry resource | portal-generated or `poc05-foundry-<unique>` |
| Azure AI Search | `poc05-rag-search-<unique>` |
| Search index | `poc05-rag-index` |
| Chat deployment | `rag-chat` |
| Embedding deployment | `rag-embedding` |
| Application Insights | `appi-poc05-rag` (optional) |
| Key Vault | `kv-poc05-rag-<unique>` (optional) |

For the simplest first run, deploy an Azure-hosted chat model and an embedding model available to your subscription. A small chat model such as `gpt-4o-mini` is suitable when available. For embeddings, `text-embedding-3-small` is a good POC choice when available. If your region/quota does not offer those models, use available equivalents and update `.env` accordingly.

---

# PART A — Azure setup

## 3. Prerequisites on Windows

Install:

1. Python 3.11 or 3.12
2. Git
3. Azure CLI
4. VS Code (recommended)

Verify:

```powershell
python --version
git --version
az version
```

If `az` is not recognized after installing Azure CLI:

1. Close all Command Prompt / PowerShell windows.
2. Open a new terminal.
3. Run `az version` again.
4. If still missing, restart Windows and retry.

Sign in:

```powershell
az login
az account show
```

If you have multiple subscriptions:

```powershell
az account list -o table
az account set --subscription "YOUR_SUBSCRIPTION_NAME_OR_ID"
az account show
```

### Verification checkpoint

You should see your subscription details and no authentication error.

---

## 4. Create a Resource Group

### Azure portal

1. Open Azure Portal.
2. Search **Resource groups**.
3. Select **Create**.
4. Select your subscription.
5. Resource group name: `rg-poc05-foundry-rag`.
6. Select a region where the Foundry models you want are available.
7. Select **Review + create** → **Create**.

### Optional Azure CLI

```powershell
az group create --name rg-poc05-foundry-rag --location eastus
```

Replace `eastus` if you choose another supported region.

### Verification

```powershell
az group show --name rg-poc05-foundry-rag --query properties.provisioningState -o tsv
```

Expected:

```text
Succeeded
```

---

## 5. Create Microsoft Foundry project/resource

Use the Microsoft Foundry portal at `https://ai.azure.com`.

1. Sign in with the Azure account connected to your subscription.
2. Make sure you are using **New Foundry** if the UI offers a toggle.
3. Select the current project name in the upper-left area.
4. Select **Create new project**.
5. Project name: `poc05-rag-project`.
6. Open **Advanced options** if shown.
7. Select resource group `rg-poc05-foundry-rag`.
8. Select your chosen location.
9. Create the project.
10. Wait until resource creation finishes.

The portal creates/uses a Foundry resource under the project. Keep the Foundry resource and project in the same resource group for this POC when possible.

### Verification

Inside the Foundry project:

- project opens successfully;
- resource status is healthy;
- you can open the Models area.

---

## 6. Deploy the chat model

In Microsoft Foundry:

1. Select **Discover** → **Models**.
2. Search for a small chat model available in your subscription/region.
3. Open the model card.
4. Select **Deploy**.
5. Use **Default settings** for a beginner POC unless you need custom quota settings.
6. Set deployment name to something easy, for example:

```text
rag-chat
```

7. Deploy.
8. Wait for provisioning state **Succeeded**.
9. Open the playground and send a tiny test question such as `Say hello in one sentence.`

### Verification

You must receive a model response in the playground.

> Important: application code calls the **deployment name**, not necessarily the underlying model name.

---

## 7. Deploy the embedding model

Repeat the model deployment flow for an embedding model.

Recommended when available:

```text
text-embedding-3-small
```

Use deployment name:

```text
rag-embedding
```

If you use `text-embedding-3-small` with its default output size, set:

```text
EMBEDDING_DIMENSIONS=1536
```

If you use a different embedding model or explicitly choose another dimensions value, change `EMBEDDING_DIMENSIONS` to match the actual vector size.

### Verification

Confirm the embedding deployment status is **Succeeded**.

---

## 8. Copy Foundry endpoint and key (beginner mode)

For the first run, this project supports API-key authentication because it is easier to understand. Keys are stored only in local `.env`, which is ignored by Git.

From your Foundry/Azure AI resource, find the model inference endpoint and key. Your OpenAI-compatible base URL should normally end in:

```text
/openai/v1/
```

Example shape:

```text
https://YOUR-RESOURCE-NAME.openai.azure.com/openai/v1/
```

or, depending on the Foundry resource/model deployment type:

```text
https://YOUR-RESOURCE-NAME.services.ai.azure.com/openai/v1/
```

Do not guess the hostname. Copy the endpoint exposed by your resource/deployment.

You will store it later as:

```text
FOUNDRY_OPENAI_BASE_URL=...
FOUNDRY_API_KEY=...
```

---

## 9. Create Azure AI Search

### Azure portal

1. Open Azure Portal.
2. Select **Create a resource**.
3. Search **Azure AI Search**.
4. Select **Create**.
5. Subscription: your Azure subscription.
6. Resource group: `rg-poc05-foundry-rag`.
7. Service name: choose a globally unique lowercase name, for example `poc05-rag-search-irshad01`.
8. Region: preferably the same region as the Foundry resources.
9. Pricing tier: choose **Free** if available for your subscription and region.
10. Compute type: leave the normal/default option for this POC.
11. Create the service.

### Verification

Open the search service → **Overview**.

Copy the endpoint, which looks like:

```text
https://YOUR-SEARCH-NAME.search.windows.net
```

For the easiest first run, open **Settings → Keys** and copy the primary admin key.

Later you can switch the service to role-based access and Microsoft Entra ID; see `docs/security_and_keyless_auth.md`.

---

# PART B — Run the Python project

## 10. Project structure

```text
POC_05_FOUNDRY_RAG_AI_SEARCH_PROJECT/
├── README.md
├── .env.example
├── .gitignore
├── requirements.txt
├── data/
│   └── synthetic_docs/
│       ├── return_policy.md
│       ├── shipping_sla.md
│       ├── warranty_policy.md
│       ├── support_policy.md
│       ├── product_catalog.md
│       ├── data_dictionary_orders.md
│       ├── architecture_notes.md
│       ├── security_policy.md
│       ├── old_shipping_policy_conflict.md
│       ├── current_shipping_policy_conflict.md
│       ├── prompt_injection_test.md
│       └── privacy_policy.md
├── rag/
│   ├── __init__.py
│   ├── config.py
│   ├── clients.py
│   ├── documents.py
│   ├── chunking.py
│   ├── index_schema.py
│   ├── ingest.py
│   ├── retrieve.py
│   ├── rag_engine.py
│   ├── ask.py
│   └── app.py
├── eval/
│   ├── __init__.py
│   ├── questions.json
│   ├── run_eval.py
│   ├── failure_tests.py
│   └── results_template.md
├── scripts/
│   ├── verify_config.py
│   ├── smoke_test.py
│   └── delete_index.py
├── tests/
│   ├── test_chunking.py
│   └── test_documents.py
└── docs/
    ├── architecture.md
    ├── azure_portal_setup.md
    ├── security_and_keyless_auth.md
    ├── retrieval_experiments.md
    ├── troubleshooting.md
    ├── interview_qa.md
    └── original_poc_spec.md
```

---

## 11. Use the one-click Python toolchain setup

This project includes a ready-made bootstrap under `python_toolchain_one_click`.

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

The script configures Poetry, creates the project-local environment, selects Python 3.12, installs the dependencies, and runs the project verification checks. This is the recommended setup path for this POC and replaces the manual `python -m venv` flow.

---

## 12. Create `.env`

Copy the template:

```powershell
Copy-Item .env.example .env
```

Open `.env` and fill the values.

Example:

```dotenv
SEARCH_AUTH_MODE=key
AZURE_SEARCH_ENDPOINT=https://YOUR-SEARCH-SERVICE.search.windows.net
AZURE_SEARCH_ADMIN_KEY=YOUR_SEARCH_ADMIN_KEY
AZURE_SEARCH_INDEX_NAME=poc05-rag-index

FOUNDRY_AUTH_MODE=key
FOUNDRY_OPENAI_BASE_URL=https://YOUR-FOUNDRY-RESOURCE.openai.azure.com/openai/v1/
FOUNDRY_API_KEY=YOUR_FOUNDRY_KEY
FOUNDRY_CHAT_DEPLOYMENT=rag-chat
FOUNDRY_EMBEDDING_DEPLOYMENT=rag-embedding
EMBEDDING_DIMENSIONS=1536

CHUNK_SIZE_TOKENS=300
CHUNK_OVERLAP_TOKENS=50
TOP_K=5
MAX_OUTPUT_TOKENS=500

APPLICATIONINSIGHTS_CONNECTION_STRING=
```

Never commit `.env`.

---

## 14. Verify configuration before touching Azure

```powershell
python scripts/verify_config.py
```

Expected style of output:

```text
[OK] AZURE_SEARCH_ENDPOINT configured
[OK] Azure AI Search auth configured
[OK] FOUNDRY_OPENAI_BASE_URL configured
[OK] Foundry auth configured
[OK] Embedding dimensions: 1536
Configuration validation passed.
```

This verifies local configuration only; it does not prove the credentials have Azure permissions.

---

## 15. Run local unit tests

```powershell
python -m pytest -q
```

Expected: tests pass for the document parser and chunker without calling Azure.

---

## 16. Create the Azure AI Search index and ingest documents

Run:

```powershell
python -m rag.ingest
```

What the script does:

1. Reads synthetic Markdown files.
2. Reads metadata from YAML front matter.
3. Splits each document into overlapping chunks.
4. Calls your Foundry embedding deployment for each chunk.
5. Creates/updates the Azure AI Search index.
6. Uploads all chunks.
7. Prints success/failure counts.

Expected output resembles:

```text
Loaded 12 source documents.
Created 12+ chunks.
Embedding 12+ chunks...
Creating/updating index 'poc05-rag-index'...
Uploading chunks...
Indexed chunks: 12/12 succeeded.
```

The exact chunk count depends on tokenization and chunk settings.

### Azure-side verification

Azure Portal → your Azure AI Search service → **Search management → Indexes**.

You should see:

```text
poc05-rag-index
```

Open it and confirm a non-zero document count.

---

## 17. Run the required baseline vector search

```powershell
python -m rag.retrieve --mode vector --query "What is the return window for damaged items?" --top-k 5
```

Expected behavior:

- `return_policy.md` should appear near the top.
- The result should show `source`, `chunk_id`, `category`, score and content preview.

This proves vector similarity search works.

---

## 18. Run hybrid search

```powershell
python -m rag.retrieve --mode hybrid --query "What is the return window for damaged items?" --top-k 5
```

Hybrid search sends both:

- the original text query for full-text/BM25 retrieval;
- the embedding vector for semantic similarity.

Azure AI Search fuses the result lists using Reciprocal Rank Fusion (RRF).

Compare vector and hybrid output. Record observations in `docs/retrieval_experiments.md`.

---

## 19. Test metadata filtering

```powershell
python -m rag.retrieve --mode hybrid --category policy --query "How quickly should standard orders ship?"
```

Only documents whose category is `policy` should be eligible.

---

## 20. Run the full RAG answer

```powershell
python -m rag.ask --query "What is the return window for damaged items?"
```

Expected answer should be based only on the retrieved documents and end with source identifiers similar to:

```text
Sources:
- return_policy.md#return-policy-0001
```

The prompt explicitly says that text inside retrieved documents is untrusted data and cannot override the system instructions.

---

## 21. Test an unsupported question

```powershell
python -m rag.ask --query "Who won the 2032 World Cup?"
```

Expected behavior:

```text
I don't have enough information.
```

It may include retrieved low-score sources, but it must not confidently invent an answer from outside the corpus.

---

## 22. Run retrieval evaluation

The project includes 10 evaluation questions with expected source documents.

Run:

```powershell
python -m eval.run_eval
```

It writes a timestamped JSON result into:

```text
eval/results/
```

Metrics include:

- `retrieval_hit_at_k`
- `citation_correct`
- `answer_grounded_heuristic`
- `unsupported_answer`
- `latency_ms`

For a small POC, use these metrics for learning. Production RAG evaluation should include higher-quality human/LLM judging and task-specific relevance labels.

---

## 23. Run failure tests

```powershell
python -m eval.failure_tests
```

The cases cover:

1. unsupported question;
2. ambiguous question;
3. conflicting documents;
4. prompt-injection text inside a retrieved document.

Read the printed output and record the behavior in `docs/retrieval_experiments.md`.

---

## 24. Run end-to-end smoke test

```powershell
python scripts/smoke_test.py
```

The script performs:

1. a small vector query;
2. a small hybrid query;
3. one grounded RAG answer.

If all three succeed, your main POC path is working.

---

## 25. Run the FastAPI app

```powershell
uvicorn rag.app:app --reload --host 127.0.0.1 --port 8000
```

Open:

```text
http://127.0.0.1:8000/docs
```

Test `POST /ask` with:

```json
{
  "query": "What is the return window for damaged items?",
  "mode": "hybrid",
  "top_k": 5,
  "category": null
}
```

Test `POST /retrieve` to inspect the raw chunks separately from the LLM answer.

Health endpoint:

```text
GET http://127.0.0.1:8000/health
```

---

# PART C — Observability and security

## 26. Application Insights (optional POC enhancement)

Create an Application Insights resource in the same resource group if you want telemetry.

Copy its connection string into:

```dotenv
APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=...;IngestionEndpoint=...
```

Restart the FastAPI process. The project configures Azure Monitor OpenTelemetry when the connection string is present and logs request duration and failures.

If the variable is blank, the application still works with local console logging.

---

## 27. Switch to Microsoft Entra ID / keyless authentication

After the key-based version works, follow `docs/security_and_keyless_auth.md`.

For Azure AI Search, recommended user roles for this POC are typically:

- Search Service Contributor
- Search Index Data Contributor
- Search Index Data Reader

For Foundry model access, assign the appropriate Foundry/Azure AI role (for example Azure AI User where required by your deployment path).

Then change `.env`:

```dotenv
SEARCH_AUTH_MODE=entra
FOUNDRY_AUTH_MODE=entra
```

Run:

```powershell
az login
python scripts/verify_config.py
python -m rag.retrieve --mode hybrid --query "What is the return window for damaged items?"
```

Keys can then be removed from `.env`.

---

# PART D — What counts as POC completion?

Use this checklist.

- [ ] Resource group created.
- [ ] Microsoft Foundry project/resource created.
- [ ] Chat model deployment succeeds.
- [ ] Embedding model deployment succeeds.
- [ ] Azure AI Search created.
- [ ] `.env` configured locally and ignored by Git.
- [ ] `python scripts/verify_config.py` passes.
- [ ] local tests pass.
- [ ] ingestion completes with no failed chunks.
- [ ] Azure AI Search index shows non-zero documents.
- [ ] vector query returns relevant source.
- [ ] hybrid query works.
- [ ] vector vs hybrid comparison documented.
- [ ] RAG answer contains source identifiers.
- [ ] unsupported question returns the fallback rather than fabricated facts.
- [ ] 10-question evaluation runs.
- [ ] failure tests run.
- [ ] FastAPI `/ask` works from Swagger.
- [ ] optional: Application Insights receives telemetry.
- [ ] optional: switch local auth to Entra ID.
- [ ] delete unused paid deployments/resources after testing.

---

## 28. Clean up Azure resources

### Delete only the search index

```powershell
python scripts/delete_index.py
```

### Delete the full POC resource group

Only do this when you are finished and you are sure the resource group contains nothing important:

```powershell
az group delete --name rg-poc05-foundry-rag --yes --no-wait
```

This is the easiest cost-control cleanup for an isolated POC resource group.

---

## 29. Common command sequence — copy/paste order

After Azure resources are manually created:

```powershell
cd POC_05_FOUNDRY_RAG_AI_SEARCH_PROJECT
cd .\python_toolchain_one_click\windows
./setup_venv_poery.bat
Copy-Item .env.example .env
# Edit .env now
poetry run python scripts/verify_config.py
poetry run python -m pytest -q
poetry run python -m rag.ingest
poetry run python -m rag.retrieve --mode vector --query "What is the return window for damaged items?"
poetry run python -m rag.retrieve --mode hybrid --query "What is the return window for damaged items?"
poetry run python -m rag.ask --query "What is the return window for damaged items?"
poetry run python -m eval.run_eval
poetry run python -m eval.failure_tests
poetry run python scripts/smoke_test.py
poetry run uvicorn rag.app:app --reload --host 127.0.0.1 --port 8000
```

---

## 30. GitHub safety check

Before pushing:

```powershell
git status
git check-ignore .env
```

`git check-ignore .env` should print `.env`, proving Git will ignore it.

Optional secret scan:

```powershell
git grep -n -I -E "(api[_-]?key|AccountKey=|InstrumentationKey=)" -- . ":(exclude).env.example"
```

Inspect any matches before pushing.

---

## 31. Interview-ready explanation

When asked what you built:

> I built a small enterprise-style RAG POC using Microsoft Foundry model deployments and Azure AI Search. I chunked synthetic documents with metadata, generated embeddings, stored text and vectors in a Search index, compared vector-only and hybrid retrieval, grounded generation strictly on retrieved context, returned citations, evaluated retrieval hit@k and failure cases, and added optional Entra ID and Application Insights patterns.

See `docs/interview_qa.md` for common interview questions.

---

## 32. Troubleshooting

See `docs/troubleshooting.md` for:

- `az is not recognized`
- 401/403 from Foundry
- 401/403 from Azure AI Search
- wrong vector dimensions
- deployment not found
- index schema mismatch
- no relevant retrieval result
- Free tier unavailable
- quota/region errors
- PowerShell activation policy errors
