# POC-03 — Real-Time Data Platform with Event Hubs, Fabric and Synapse

Beginner-friendly Azure + Microsoft Fabric proof of concept.

## 1. What you will build

```text
Python synthetic shipment producer
        |
        v
Azure Event Hubs
        |
        +--> Azure Databricks Structured Streaming
        |        |
        |        +--> Bronze Delta (raw)
        |        +--> Silver Delta (watermark + dedup)
        |        +--> Gold Parquet summary
        |
        +--> Microsoft Fabric Eventstream
                 |
                 +--> Eventhouse / KQL database
                        |
                        +--> KQL queries / Real-Time dashboard

Gold Parquet
   |
   +--> Azure Synapse serverless SQL
   +--> Fabric OneLake/Lakehouse shortcut or tiny load
            |
            +--> Fabric transformation
            +--> Semantic model/report

Optional governance/operations:
   Microsoft Purview
   Azure Monitor / Log Analytics
```

This matches the original POC objective: practice Event Hubs, Databricks streaming,
Delta/ADLS, Fabric Real-Time Intelligence, OneLake/Lakehouse, Synapse serverless,
semantic modeling, governance, and monitoring.

---

# 2. Learning objectives

By the end, you should be able to explain:

- what Azure Event Hubs does;
- why partition keys matter;
- how a producer sends JSON events;
- how Structured Streaming reads Event Hubs;
- checkpoint vs watermark;
- duplicate handling;
- late-event handling;
- restart behavior;
- Bronze/Silver/Gold concepts;
- Eventstream vs Eventhouse/KQL;
- OneLake shortcut vs data copy;
- why Synapse serverless is useful for ad-hoc lake queries;
- why reading fewer columns reduces unnecessary scanning;
- how semantic measures are created;
- how to monitor freshness and streaming health;
- where Purview fits.

---

# 3. Cost guardrails

Keep this POC tiny.

- Use one small Event Hub.
- Send only ~100-500 events.
- Use minimal Databricks compute and auto-termination.
- Stop Databricks immediately when not using it.
- Use Fabric Trial/capacity only if available.
- Use Synapse **serverless SQL only** for tiny files.
- Do not create a Synapse dedicated SQL pool.
- Keep Purview/Log Analytics optional if cost/account availability is unclear.
- Delete POC-only resources after capturing evidence.

---

# 4. Project structure

```text
POC_03_REALTIME_FABRIC_SYNAPSE/
├── .env.example
├── .gitignore
├── README.md
├── requirements.txt
│
├── producer/
│   ├── send_events.py
│   └── receive_events.py
│
├── databricks/
│   ├── stream_to_delta.py
│   ├── inspect_and_validate.py
│   └── export_gold_parquet.py
│
├── fabric/
│   └── setup_notes.md
│
├── kql/
│   ├── create_shipment_table.kql
│   └── shipment_queries.kql
│
├── synapse/
│   └── serverless_queries.sql
│
├── semantic_model/
│   └── measures.dax
│
├── governance/
│   └── purview_notes.md
│
├── monitoring/
│   └── monitoring_checklist.md
│
├── docs/
│   ├── azure_portal_setup.md
│   ├── troubleshooting.md
│   └── cleanup.md
│
└── evidence/
    └── README.md
```

---

# 5. Prerequisites

Required:

- Azure subscription
- Python 3.9+
- pip
- browser access to Azure portal
- permission to create:
  - Resource Group
  - Storage Account / ADLS Gen2
  - Event Hubs
  - Azure Databricks
  - Synapse workspace
- Microsoft Fabric workspace with supported capacity or Trial for Fabric steps

Recommended:

- VS Code
- Git
- Azure CLI (optional for this manual-first version)

---

# 6. Event schema

The base event is:

```json
{
  "event_id": "evt-001",
  "order_id": 1001,
  "event_type": "SHIPPED",
  "event_ts": "2026-08-28T10:00:00Z",
  "region": "IN-SOUTH"
}
```

The Python producer adds a few useful fields:

```json
{
  "revenue": 1299.50,
  "fulfillment_minutes": 120,
  "producer_seq": 1
}
```

These extra fields allow the semantic model to demonstrate revenue and fulfillment KPIs.

---

## 7. Use the one-click project setup before the Azure steps

This POC includes a ready-to-use Python toolchain bootstrap in the `python_toolchain_one_click` folder.

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

The script sets Poetry to create the environment inside the project folder, selects Python 3.12, installs dependencies, and runs the local validation flow. Follow this setup path instead of manually creating a virtual environment with `python -m venv .venv`.

---

## PHASE 1 — Create Azure resources manually

Follow:

**`docs/azure_portal_setup.md`**

Create:

1. Resource Group
2. ADLS Gen2 Storage Account + `realtime` filesystem
3. Event Hubs namespace
4. `shipment-events` Event Hub

Do not create Databricks/Synapse yet if you want the easiest debugging path.

---

## PHASE 2 — Prove Event Hubs works locally

### Windows Command Prompt

Run the project bootstrap first so the environment is created correctly:

```bat
cd .\python_toolchain_one_click\windows
setup_venv_poery.bat
copy .env.example .env
```

The script manages the Poetry environment, selects Python 3.12, and installs dependencies. After that, open `.env` and set:

```text
EVENT_HUB_CONNECTION_STRING=<your real connection string>
EVENT_HUB_NAME=shipment-events
```

### Send 20 events

```bat
python producer\send_events.py --count 20 --delay 0.2
```

Expected:
- every send prints a JSON event summary;
- final summary shows attempts/duplicates/late events.

### Receive 10 events

```bat
python producer\receive_events.py --max-events 10 --starting-position -1
```

Expected:
- JSON payloads appear;
- partition, offset, and sequence number appear.

### Azure verification

Azure portal:

Event Hubs -> `shipment-events` -> Monitoring -> Metrics

Check **Incoming Messages**.

**PASS condition:** local sender + receiver work and Azure metric shows incoming events.

---

# 8. Databricks streaming path

Now create/configure Databricks using `docs/azure_portal_setup.md`.

The streaming code is:

`databricks/stream_to_delta.py`

It performs:

```text
Event Hubs Kafka endpoint
  -> raw JSON
  -> Bronze Delta
  -> parse schema
  -> event_ts timestamp
  -> 10-minute watermark
  -> event_id dedup
  -> Silver Delta
```

## Why checkpointing?

A checkpoint records stream progress/state, including source offsets and streaming
state required to recover.

Simple explanation:

> Checkpoint = "Where did my streaming job reach, and what state must it restore?"

## Why watermark?

A watermark tells Spark how late event-time data may arrive before state can be
cleaned up.

Simple explanation:

> Watermark = "How long should I wait for late events?"

They are not the same thing.

## Send the real test batch

While Databricks stream is running:

```bat
python producer\send_events.py --count 200 --delay 0.15 --duplicate-every 25 --late-every 40
```

The producer intentionally injects:
- duplicate `event_id` values;
- events ~20 minutes old.

This lets you demonstrate dedup and late-event behavior.

## Validate Silver

Run:

`databricks/inspect_and_validate.py`

Expected:
- Silver count > 0;
- row count == distinct `event_id`;
- assertion passes.

**PASS condition:** Silver contains no duplicate event IDs.

---

# 9. Restart/recovery test

This is one of the most important interview-ready tests.

1. Record current Silver row count.
2. Stop the Structured Streaming notebook/query.
3. Send 20 more events:

```bat
python producer\send_events.py --count 20 --delay 0.15
```

4. Restart `stream_to_delta.py` using the SAME checkpoint paths.
5. Wait until new events process.
6. Run `inspect_and_validate.py` again.

Expected:
- processing resumes;
- previous data is not blindly reprocessed as brand new because checkpointed offsets/state are reused;
- Silver stays deduplicated.

**Do not delete the checkpoint before this test.**

---

# 10. Build Gold for serving

Run:

`databricks/export_gold_parquet.py`

It creates a tiny per-region aggregate containing:

- total orders;
- revenue;
- delayed shipments;
- average fulfillment minutes;
- last event timestamp.

Expected ADLS path:

```text
realtime/gold/shipment_summary/
```

**PASS condition:** Parquet file(s) exist.

---

# 11. Microsoft Fabric Real-Time Intelligence

Follow:

`fabric/setup_notes.md`

Build:

1. Fabric workspace
2. Eventhouse / KQL database
3. `ShipmentEvents` table
4. Eventstream
5. Azure Event Hubs source
6. Eventhouse destination
7. Publish
8. KQL queries
9. small Real-Time dashboard

KQL assets:

```text
kql/create_shipment_table.kql
kql/shipment_queries.kql
```

After Eventstream is published, send another batch:

```bat
python producer\send_events.py --count 100 --delay 0.2
```

Run:

```kusto
ShipmentEvents
| take 10
```

Then:

```kusto
ShipmentEvents
| summarize events=count() by bin(event_ts, 5m), event_type
```

And:

```kusto
ShipmentEvents
| where event_type == "DELAYED"
| summarize delayed=count() by region
```

**PASS condition:** KQL returns expected grouped counts.

---

# 12. OneLake / Lakehouse path

Inside Fabric:

1. Create `poc03_lakehouse`.
2. Create an ADLS shortcut to curated/Gold data where practical.
3. If shortcut is not supported by your exact tenant/auth setup, load only the tiny
   Gold dataset and document why the shortcut was not completed.
4. Use a Fabric Notebook/Dataflow Gen2/Pipeline to create a curated table.

**PASS condition:** Fabric can read the curated dataset.

Why shortcut?

> A shortcut exposes data in OneLake without forcing another physical copy when the
> supported source and security configuration allow it.

---

# 13. Synapse serverless SQL

Create Synapse workspace only for serverless SQL.

Do NOT create a dedicated SQL pool.

Open:

`synapse/serverless_queries.sql`

Replace:

`<storage-account>`

Run the `OPENROWSET` Parquet query in the built-in serverless pool.

Expected:
- Gold rows returned;
- aggregate totals returned.

## Cost test

Compare:
- `SELECT *`
- explicit selected columns

Look at query details/data processed.

For this tiny POC the numerical difference may be small, but the production lesson is:

> serverless lake queries should scan only the data/columns required.

**PASS condition:** Synapse serverless queries Gold successfully.

---

# 14. Semantic model

Use:

`semantic_model/measures.dax`

Create measures:

- Total Orders
- Revenue
- Delayed Shipments
- Average Fulfillment Time

Build a tiny report with four cards.

Compare values against Gold.

**PASS condition:** report values match the curated source.

---

# 15. Monitoring

Follow:

`monitoring/monitoring_checklist.md`

Capture:

- Event Hub incoming messages;
- streaming status;
- checkpoint location;
- Eventstream/Eventhouse health;
- latest-event timestamp;
- one transform/pipeline failure and recovery.

**PASS condition:** at least one failure path is intentionally captured and then fixed.

---

# 16. Purview / governance

Follow:

`governance/purview_notes.md`

If practical:
- register tiny relevant scope;
- scan tiny scope;
- inspect classification/lineage.

If not practical:
- document the enterprise design;
- clearly mark Purview as **not deployed**.

Never claim an optional service was implemented if you only documented it.

---

# 17. Full validation checklist

## Event Hubs
- [ ] Python producer sends events
- [ ] local receiver can read events
- [ ] Incoming Messages metric increases

## Databricks
- [ ] Bronze Delta created
- [ ] Silver Delta created
- [ ] Silver rows > 0
- [ ] Silver `count == distinct(event_id)`
- [ ] checkpoint path created
- [ ] restart test performed
- [ ] duplicate test performed
- [ ] late-event test performed

## Gold
- [ ] Gold Parquet exists
- [ ] totals look reasonable

## Fabric
- [ ] workspace created
- [ ] Eventhouse/KQL DB created
- [ ] Eventstream connected to Event Hubs
- [ ] Eventstream published
- [ ] `ShipmentEvents | take 10` returns data
- [ ] grouped KQL works
- [ ] Real-Time dashboard or equivalent evidence created
- [ ] Lakehouse created
- [ ] shortcut demonstrated where practical

## Synapse
- [ ] built-in serverless pool used
- [ ] no dedicated pool created
- [ ] Gold Parquet queried
- [ ] data scanned/processed inspected

## Semantic model
- [ ] Total Orders
- [ ] Revenue
- [ ] Delayed Shipments
- [ ] Average Fulfillment Time
- [ ] values validated against Gold

## Operations
- [ ] one failure captured
- [ ] failure fixed
- [ ] data freshness checked
- [ ] Databricks compute stopped

## Governance
- [ ] Purview deployed OR honestly documented as design-only

---

# 18. Troubleshooting

See:

`docs/troubleshooting.md`

Most common beginner issues:

1. bad Event Hubs connection string;
2. wrong Event Hub name;
3. Databricks ADLS permissions;
4. secret not found;
5. Spark runtime API mismatch;
6. Eventstream changes not published;
7. KQL table mapping mismatch;
8. Synapse identity cannot read ADLS.

---

# 19. Cleanup

Follow:

`docs/cleanup.md`

The fastest Azure cleanup, if the resource group contains only this POC, is to
delete:

`rg-poc03-realtime-dev`

Also separately remove POC-only Fabric items/workspace because Fabric artifacts
are not necessarily tied to that Azure resource group.

---

# 20. Interview rapid-fire

### 1. What is an Event Hubs partition key?

It determines which partition an event is routed to. Events with the same
partition key are routed consistently, which helps ordering for that key, but a
skewed key can create a hot partition.

### 2. What is a watermark?

An event-time threshold used by Structured Streaming to bound how long state is
kept for late data.

### 3. Checkpoint vs watermark?

Checkpoint = recovery/progress/state persistence.

Watermark = late-event/state-retention rule based on event time.

### 4. Eventhouse/KQL vs Lakehouse?

Eventhouse/KQL is optimized for fast ingestion and real-time/time-series/event
analytics. Lakehouse is optimized for open lake storage, Spark/SQL analytics, and
broader batch/ML/BI patterns.

### 5. When use Synapse serverless?

For on-demand SQL over lake files when you do not want to provision a dedicated
warehouse/pool for the workload.

### 6. OneLake shortcut vs copy?

Shortcut references accessible data without unnecessarily duplicating it.
Copy creates a second physical dataset and its own refresh/storage lifecycle.

### 7. How monitor freshness?

Track the newest business event timestamp and compare it with current time;
combine that with ingestion/processing health metrics.

### 8. How does Purview complement Unity Catalog?

Purview provides broader enterprise data catalog/governance capabilities across
supported sources. Unity Catalog governs Databricks data/AI assets and access
inside the Databricks governance plane. In an enterprise they can be complementary,
subject to available integrations/connectors.

---

# 21. Suggested GitHub evidence

Use `evidence/README.md`.

Never commit:
- Event Hubs connection strings;
- SAS tokens;
- storage keys;
- screenshots showing secrets;
- personal tenant/subscription identifiers you do not want public.

---

# 22. CV bullets — use only after completion

Use only after you actually complete and validate the POC:

- Built a near-real-time Azure data pipeline using Event Hubs, Structured Streaming
  and Delta Lake with checkpointing, watermarks, and deduplication.
- Explored Microsoft Fabric Real-Time Intelligence using Eventstream, Eventhouse,
  and KQL for low-latency event analysis.
- Published curated data through OneLake/Fabric and Synapse serverless patterns with
  semantic modeling and cost-aware querying.
- Added governance and observability evidence covering Purview design, lineage,
  data freshness, and streaming health.

---

# 23. Current Microsoft documentation to cross-check UI changes

Because Azure/Fabric UI labels evolve, cross-check the current Microsoft Learn
documentation while executing manual portal steps, especially for:

- Azure Event Hubs Python SDK
- Fabric Eventstream
- Fabric Eventhouse
- Synapse serverless SQL + Parquet

The project code intentionally uses environment variables/placeholders so it can
be safely committed after you confirm no secrets are present.
