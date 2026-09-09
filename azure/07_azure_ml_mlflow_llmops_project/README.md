# POC-07 — Azure Machine Learning + MLflow + LLMOps/MLOps

Beginner-friendly implementation of the source POC: train and compare two models that predict whether a **synthetic shipment will be delayed**, track experiments in MLflow/Azure Machine Learning, register the selected model, produce `risk_score`, and optionally deploy it to an Azure ML batch endpoint.

## What you will learn

- What an Azure Machine Learning workspace is and where it stores artifacts.
- How local Python training can log runs to Azure ML through MLflow.
- How to prevent obvious feature leakage.
- How to compare logistic regression vs a tree-based model.
- How to register a selected model with dataset/code/metric lineage.
- How to score locally and then validate a temporary Azure batch endpoint.
- What to monitor: latency, errors, prediction distribution, drift, freshness.
- How Git/YAML CI can reproduce the workflow.

## Cost-first architecture

```text
Synthetic CSV (local)
      |
      +--> Azure ML Data Asset --> workspace Azure Storage
      |
Local Python 3.12 training
      |
      +--> MLflow tracking --> Azure ML experiment/runs
                   |
        compare two candidate models
                   |
        register selected MLflow model
                   |
          +--------+---------+
          |                  |
    local scoring       optional batch endpoint
    (free/fast)        (temporary AML compute)
          |                  |
        risk_score       batch predictions
```

The default learning path trains **locally** to avoid compute cost. **Poetry + Python 3.12** is the primary local environment; `requirements.txt` is kept only as a fallback. The optional batch compute uses `min_instances=0`, `max_instances=1`; delete the endpoint and compute immediately after validation.

---

# 1. Project structure

```text
POC_07_AZURE_ML_MLFLOW_LLMOPS_PROJECT/
├── README.md
├── POETRY_QUICK_START.md          # fastest Windows Poetry setup/run guide
├── .env.example
├── .gitignore
├── pyproject.toml                 # PRIMARY Poetry dependencies
├── poetry.toml                   # keep Poetry venv inside project as .venv
├── requirements.txt              # optional pip fallback only
├── POC_07_AZURE_ML_MLFLOW_LLMOPS_ORIGINAL.md
├── ml/
│   ├── common.py
│   ├── azure_utils.py
│   ├── generate_data.py
│   ├── verify_config.py
│   ├── register_data.py
│   ├── train.py
│   ├── compare_runs.py
│   ├── register_model.py
│   ├── score.py
│   ├── verify_poc.py
│   └── requirements.txt              # optional pip fallback only
├── azure/
│   └── batch/
│       ├── deploy_batch.py
│       ├── invoke_batch.py
│       ├── cleanup_batch.py
│       ├── endpoint.yml
│       └── deployment.yml
├── data/
│   ├── train/
│   └── scoring/
├── outputs/
├── docs/
│   ├── azure_portal_setup.md
│   ├── runbook.md
│   ├── poetry_setup.md
│   ├── experiment_results.md
│   ├── model_card.md
│   ├── data_leakage_check.md
│   ├── monitoring.md
│   ├── ci_cd_concepts.md
│   ├── interview_questions.md
│   ├── troubleshooting.md
│   └── cleanup.md
├── scripts/
│   ├── setup_poetry_windows.bat
│   ├── run_local_poetry_windows.bat
│   ├── run_azure_tracking_poetry_windows.bat
│   ├── run_local_windows.bat
│   └── run_azure_tracking_windows.bat
├── tests/
│   ├── test_generate_data.py
│   └── test_feature_contract.py
└── .github/workflows/ci.yml
```

---

# 2. Before Azure: create the Poetry environment and run locally first

This project now uses **Poetry as the primary Python environment/dependency manager**. You do **not** need to manually run `py -m venv` or `pip install -r requirements.txt`.

The included `poetry.toml` sets `virtualenvs.in-project = true`, so Poetry creates the environment at:

```text
POC_07_AZURE_ML_MLFLOW_LLMOPS_PROJECT\.venv
```

## Step 2.1 — Use the one-click Python toolchain bootstrap

This project includes a ready-made project setup script under `python_toolchain_one_click`.

### Windows

```bat
cd C:\path\to\POC_07_AZURE_ML_MLFLOW_LLMOPS_PROJECT
cd .\python_toolchain_one_click\windows
setup_venv_poery.bat
```

### macOS / Linux

```bash
cd ./python_toolchain_one_click/unix
bash ./setup_venv_poery.sh
```

The script configures Poetry to use a project-local virtual environment, targets Python 3.12, installs all dependencies from `pyproject.toml`, and runs the local verification checks. This is the recommended setup path and replaces the manual `python -m venv` flow.

Expected:

```text
Poetry environment created successfully.
Python 3.12.x
```

## Step 2.2 — Verify the Poetry environment

```bat
poetry env info
poetry env info --path
poetry run python --version
```

Because `poetry.toml` is included, the path should point to this project's `.venv` folder. On the first successful `poetry install`, Poetry will also create `poetry.lock`; keep that lock file for reproducible future installs.

## Step 2.3 — Install all POC dependencies from `pyproject.toml`

If you used the one-click script, dependencies are already installed. Otherwise, use:

```bat
poetry install
```

`pyproject.toml` contains the dependencies for:
- `mlflow`: experiment tracking/model packaging;
- `azureml-mlflow`: Azure ML integration for MLflow tracking;
- `azure-ai-ml`: Azure ML Python SDK v2;
- `azure-identity`: Azure authentication;
- `scikit-learn`: logistic regression/random forest and preprocessing;
- `pandas`/`numpy`: synthetic tabular data;
- `python-dotenv`: `.env` loading;
- `pytest`: automated verification tests.

Verify the Python and important packages inside Poetry:

```bat
poetry run python --version
poetry run python -c "import mlflow, sklearn, pandas; print('Poetry environment OK')"
```

### Easiest way to run commands — no activation required

Use `poetry run` before every Python command:

```bat
poetry run python -m ml.generate_data
```

This is the **recommended approach** because it works even when the virtual environment is not activated.

### Optional: activate the Poetry virtual environment

Because this project uses an in-project `.venv`, Windows CMD can activate it with:

```bat
call .venv\Scripts\activate.bat
```

PowerShell:

```powershell
.\.venv\Scripts\Activate.ps1
```

After activation, you can use plain commands such as `python -m ml.generate_data`. To leave the environment:

```bat
deactivate
```

> Modern Poetry also provides `poetry env activate`, but it prints the shell-specific activation command. For this Windows POC, `.venv\Scripts\activate.bat` or `poetry run ...` is simpler.

### One-command Poetry setup helper

You can perform Steps 2.1–2.3 with:

```bat
scripts\setup_poetry_windows.bat
```

## Step 2.4 — Generate deterministic synthetic data

```bat
poetry run python -m ml.generate_data
```

Expected:
```text
[OK] Training data: ...data\train\shipments.csv (2000 rows)
[OK] Scoring data:  ...data\scoring\shipments_scoring.csv (40 rows)
```

The source feature contract is preserved exactly:
- `origin_region`
- `destination_region`
- `carrier`
- `distance_km`
- `order_hour`
- `weekday`
- `priority`
- `historical_delay_rate`

Label: `is_delayed`.

## Step 2.5 — Train and track locally with MLflow

```bat
poetry run python -m ml.train --tracking local
```

The script trains:
1. logistic regression baseline;
2. random forest tree-based model.

For **each** run it logs parameters, validation metrics, the MLflow model, feature list, dataset SHA-256, and code version. It selects the candidate with highest validation ROC AUC (F1 tie-breaker).

Expected final lines include:
```text
[OK] logistic_regression: ...
[OK] random_forest: ...
[SELECTED] ...
[OK] Selection manifest: ...outputs\selected_model.json
```

## Step 2.6 — Compare models

```bat
poetry run python -m ml.compare_runs
```

Verify both rows are shown and the selected model is stated.

## Step 2.7 — Score new rows

```bat
poetry run python -m ml.score --tracking local
```

Verify:
```text
outputs\predictions.csv
outputs\scoring_metrics.json
```

`risk_score` is the probability of delayed class 1. This score can later be consumed by an AI agent, but the agent must describe it as a prediction/risk estimate rather than causal certainty.

## Step 2.8 — Run automated validation and tests

```bat
poetry run python -m ml.verify_poc --tracking local
poetry run pytest -q
```

Expected: `RESULT: PASS` and tests pass.

Shortcut:
```bat
scripts\run_local_poetry_windows.bat
```

---

# 3. Create Azure resources manually in Azure Portal

Detailed screenshots/menu wording guidance is in `docs\azure_portal_setup.md`.

## Step 3.1 — Resource group
Create `rg-poc07-mlops` (or your own name).

**Why:** a resource group is the lifecycle boundary for related Azure resources. For a POC it makes cleanup easy.

## Step 3.2 — Azure Machine Learning workspace
Azure Portal -> **Create a resource** -> search **Machine Learning** -> create an **Azure Machine Learning workspace**.

Suggested values:
- Resource group: `rg-poc07-mlops`
- Workspace: `mlw-poc07-mlops-<unique-suffix>`
- Region: one available to your subscription
- Networking/security: defaults for a disposable learning POC unless your organization mandates private networking

Azure ML creates/uses dependent services such as Azure Storage, Key Vault and Application Insights. The workspace default storage provides datastores such as `workspaceblobstore`.

### Important ADLS clarification
Azure ML's **default** workspace storage account is not an ADLS Gen2 hierarchical-namespace account. ADLS Gen2 can be attached separately as an additional datastore if you want extra practice, but it is not required to complete this POC.

## Step 3.3 — Open Azure ML studio
From the Azure ML workspace, click **Launch studio**.

You will later use:
- **Data** to see the synthetic data asset;
- **Jobs/Experiments** to compare MLflow runs;
- **Models** to see model versions;
- **Endpoints -> Batch endpoints** for optional deployment.

---

# 4. Configure local Python to talk to your workspace

## Step 4.1 — Create `.env`

```bat
copy .env.example .env
notepad .env
```

Fill at minimum:
```text
AZURE_SUBSCRIPTION_ID=<your-subscription-id>
AZURE_RESOURCE_GROUP=rg-poc07-mlops
AZUREML_WORKSPACE_NAME=<your-workspace-name>
AZURE_AUTH_MODE=cli
```

No Azure password/client secret is stored in this file.

## Step 4.2 — Verify workspace connection

```bat
poetry run python -m ml.verify_config

> Authentication troubleshooting: see `docs/authentication_fix.md`.
```

A browser window can open. Sign in with the Azure account that has workspace access.

Expected:
```text
[OK] Connected to Azure ML workspace: ...
[OK] Location: ...
[OK] MLflow tracking URI discovered: azureml://...
```

**If `az` is not recognized:** that is fine. The primary Python path uses browser authentication and does not require Azure CLI.

---

# 5. Register the training data in Azure ML

Make sure data exists:

```bat
poetry run python -m ml.generate_data
```

Then:

```bat
poetry run python -m ml.register_data
```

What happens:
1. SHA-256 fingerprint is computed.
2. The first 12 characters become the data asset version.
3. Azure ML uploads the local CSV to workspace-managed Azure Storage.
4. A named/versioned Azure ML data asset is created.

Verify in Azure ML studio -> **Data** -> find `shipment-delay-synthetic`.

---

# 6. Track the real POC experiment in Azure ML using MLflow

```bat
poetry run python -m ml.train --tracking azure
```

The code still runs on your laptop. Only experiment metadata/model artifacts are sent to Azure ML. This is the key low-cost design requested by the source POC.

## Verify in Azure ML studio
1. Open Azure ML studio.
2. Open **Jobs** / experiment view.
3. Find experiment `poc07-shipment-delay`.
4. Verify at least two runs exist:
   - logistic regression;
   - random forest.
5. Open each run and inspect parameters/metrics/artifacts.
6. Compare `roc_auc`, `f1`, `precision`, `recall`, `accuracy`, `log_loss`.

Also verify locally:
```bat
poetry run python -m ml.compare_runs
```

---

# 7. Register the selected model

**Important:** use the Azure-tracked manifest created in Step 6.

```bat
poetry run python -m ml.register_model --tracking azure
```

This registers only the selected MLflow model and adds version metadata/tags for:
- selected candidate;
- validation ROC AUC/F1;
- training dataset SHA-256;
- code version;
- limitation statement.

Verify in Azure ML studio -> **Models** -> `shipment-delay-model` -> version details.

MLflow tracking answers “what happened in each experiment run?” The model registry answers “which named/versioned model asset do we manage/deploy?”

---

# 8. First working scoring path — local scoring from the Azure-tracked model

```bat
poetry run python -m ml.score --tracking azure
```

This downloads/loads the selected model via MLflow, scores the 40-row input file, and writes:
```text
outputs\predictions.csv
outputs\scoring_metrics.json
```

Verify every `risk_score` is between 0 and 1.

Then run:
```bat
poetry run python -m ml.verify_poc --tracking azure --check-registry
```

At this point the core requirements are satisfied except optional managed serving.

---

# 9. Optional but recommended: temporary Azure ML batch endpoint

This is the cloud deployment path selected for the POC because batch inference is closer to many data-engineering workloads and avoids keeping a low-latency endpoint continuously provisioned.

## Step 9.1 — Make endpoint name unique
Edit `.env`:
```text
AZUREML_BATCH_ENDPOINT_NAME=shipment-delay-batch-<your-unique-suffix>
```

Keep:
```text
AZUREML_BATCH_COMPUTE_NAME=cpu-poc07
AZUREML_BATCH_VM_SIZE=Standard_DS2_v2
AZUREML_BATCH_DEPLOYMENT_NAME=blue
```

If that VM size is unavailable/quota-blocked in your region, choose another small supported CPU SKU.

## Step 9.2 — Deploy

```bat
poetry run python azure\batch\deploy_batch.py
```

It creates:
- one Azure ML AmlCompute cluster (`min=0`, `max=1`);
- one batch endpoint;
- one deployment of the latest registered MLflow model.

MLflow models can be deployed to Azure ML batch endpoints without you writing a custom scoring script/environment for the standard case.

## Step 9.3 — Invoke

```bat
poetry run python azure\batch\invoke_batch.py
```

The SDK uploads the local scoring folder to the workspace default storage and starts an asynchronous batch job. It streams logs and downloads the `score` output under `outputs\batch_download`.

Verify in Azure ML studio -> **Endpoints -> Batch endpoints** and **Jobs**.

## Step 9.4 — Delete endpoint and compute immediately

```bat
poetry run python azure\batch\cleanup_batch.py
```

Verify the batch endpoint and `cpu-poc07` compute no longer exist.

---

# 10. Leakage review

Read:
```text
docs\data_leakage_check.md
```

The POC deliberately excludes fields known only after the outcome (actual delivery time, delay minutes, refund, complaint, etc.). `historical_delay_rate` is acceptable only if computed from past records available before prediction time.

---

# 11. Monitoring / LLMOps-MLOps concepts

Read `docs\monitoring.md`.

Minimum signals:
- scoring latency;
- scoring/job errors;
- risk-score distribution;
- feature drift;
- input data freshness.

The local scoring script already writes a small metrics JSON. For a real endpoint, Azure Monitor/Application Insights can provide service telemetry; model/data drift still requires deliberate model-monitoring logic and reference data.

---

# 12. Reproducibility proof

A fresh clone can:
1. create Python environment;
2. generate deterministic synthetic data with seed 42;
3. log two model runs;
4. select the same *class* of best result for the same environment/data;
5. score fresh rows;
6. run tests.

Local one-command proof:
```bat
scripts\run_local_poetry_windows.bat
```

Azure one-command tracking/registry proof (after `.env` is filled):
```bat
scripts\run_azure_tracking_poetry_windows.bat
```

---

# 13. Source validation checklist mapped to commands

| Requirement | How to prove it |
|---|---|
| Two experiments/runs logged | `poetry run python -m ml.train --tracking azure` + Azure ML experiment view |
| Metrics can be compared | `poetry run python -m ml.compare_runs` + Azure ML metrics |
| Selected model registered | `poetry run python -m ml.register_model --tracking azure` + Models page |
| One scoring path works | `poetry run python -m ml.score --tracking azure` |
| Endpoint/compute deleted after testing | `poetry run python azure\batch\cleanup_batch.py` |
| Leakage review documented | `docs\data_leakage_check.md` |
| Reproducibility | `scripts\run_local_poetry_windows.bat` + `.github/workflows/ci.yml` |

Final machine check:
```bat
poetry run python -m ml.verify_poc --tracking azure --check-registry
```
Expected: `RESULT: PASS`.

---

# 14. What screenshots to capture for your final beginner PDF

Capture these after successful execution:
1. Azure resource group overview.
2. Azure ML workspace overview.
3. Azure ML **Data** page showing the data asset/version.
4. Experiment showing both candidate runs.
5. Run metrics for logistic regression.
6. Run metrics for random forest.
7. Models page showing selected model/version.
8. Local CMD output of `ml.compare_runs`.
9. Local `outputs\predictions.csv` showing `risk_score`.
10. Batch endpoint/deployment page (if used).
11. Successful batch job output.
12. Endpoint/compute no longer present after cleanup.
13. `ml.verify_poc ...` final PASS.

---

# 15. Interview preparation

See `docs\interview_questions.md` for the six source questions and concise answers.

---

# 16. Troubleshooting

See `docs\troubleshooting.md`. It includes the beginner case where Azure CLI is missing, MLflow version mismatch, batch quota/SKU errors, duplicate endpoint names, schema errors, and model registration issues.

---

# 17. Cleanup

Always read `docs\cleanup.md` before finishing.

At minimum after batch testing:
```bat
poetry run python azure\batch\cleanup_batch.py
```

If this resource group is used **only** for POC-07 and you have saved the evidence you need, delete the resource group from Azure Portal to stop all remaining POC resource costs.

---

# Completion definition

Do not use the CV bullets in the source POC until you can show:
- Azure ML experiment contains both runs;
- metrics comparison exists;
- selected model has a registry version;
- scoring emits a valid `risk_score`;
- leakage review exists;
- temporary endpoint/compute is deleted after validation.
