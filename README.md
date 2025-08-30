# ShadowLight Studios — AI Data Engineer Demo

End to end **ingestion → modeling → analyst access** using **n8n** + **Postgres**.  
Includes an optional **Agent Demo** (`GET /ask?q=...`) that maps a natural-language question to the same KPI query.

> This repository demonstrates approach and clarity, not a production system.

---

## What’s included

- **Ingestion workflow (n8n):** CSV → `staging_ads` → merge into `ads_spend` with metadata and de-duplication.
- **SQL models:** table DDLs, merge step, and KPI query (CAC & ROAS) with **last 30 days vs prior 30 days**.
- **Analyst access:** two tiny HTTP endpoints exposed by n8n
  - `GET /metrics?start=YYYY-MM-DD&end=YYYY-MM-DD`
  - `GET /ask?q=Compare CAC and ROAS for last 30 days vs prior 30 days` (Bonus “Agent Demo”)
- **Screenshots** of table data and API output.
- **README** with setup and rationale.

---

## Repository layout

```
workflows/ShadowLightStudiosTest.json   # n8n workflow export
sql/
  01_create_tables.sql                   # DDL for staging_ads, ads_spend, load_log
  02_merge_ads_spend.sql                 # merge from staging -> ads_spend (types, metadata, dedupe)
  03_metrics_kpis.sql                    # CAC/ROAS + deltas (30d vs prior 30d)
docker/
  docker-compose.yml                     # optional local stack (Postgres + n8n)
data/
  ads_spend.csv                          # sample dataset (optional)
screenshots/
  ads_spend_sample.png
  api_metrics_response.png
  api_ask_response.png
README.md
```

> Paths/routing in the workflow assume the CSV is accessible **inside the n8n container** as `/data/ads_spend.csv`.

---

## KPIs modeled

- **CAC** = `spend / conversions`
- **ROAS** = `(revenue / spend)` with **assumed** `revenue = conversions * 100`
- Comparison periods:
  - **Current:** `[start, end]` inclusive
  - **Prior:** the **immediately preceding window of equal length**
- We return **absolute values** and **deltas** (absolute & percentage).
- When denominators are zero (e.g., `conversions = 0` for CAC, or `spend = 0` for ROAS), the metric is **NULL** to avoid misleading numbers.

---

## Quick start (local)

### Prerequisites
- Docker & Docker Compose
- Ports available: `5432` (Postgres), `5678` (n8n)
- Your CSV file (e.g., `data/ads_spend.csv`)

### 1) Start the local stack (optional)
```bash
cd docker
docker compose up -d
```
**Mounting the CSV**  
- If your `docker-compose.yml` is in `docker/` **and** your CSV is in `docker/data/`, mount with:
```yaml
# docker/docker-compose.yml (service: n8n)
volumes:
  - n8n_data:/home/node/.n8n
  - ./data:/data:ro
```
- If your CSV is **outside** the `docker/` folder (e.g., repo-level `data/`), mount with:
```yaml
volumes:
  - n8n_data:/home/node/.n8n
  - ../data:/data:ro   # note the .. because compose file lives in /docker
```
Inside the n8n container the file must be reachable as **`/data/ads_spend.csv`**.

### 2) Create tables
You can either run `sql/01_create_tables.sql` via `psql` or use the **“Create Tables”** node in the n8n workflow.

**Example with psql (adjust user/db as needed):**
```bash
# if your Postgres container is named "pg" and initialized with user "devuser" and db "devtest":
docker exec -it pg psql -U devuser -d devtest -f /sql/01_create_tables.sql   || psql -h localhost -U devuser -d devtest -f sql/01_create_tables.sql
```

### 3) Import the workflow into n8n
1. Open **http://localhost:5678/**
2. **Workflows → Import from file** → select `workflows/ShadowLightStudiosTest.json`
3. Update the **Postgres credential** (host `pg`, db/user/password for your environment)
4. In the **Read File** node, set the path to **`/data/ads_spend.csv`**

### 4) Run ingestion (Branch A — Manual Trigger)
- Reads CSV → inserts into `staging_ads`
- **Merge** into `ads_spend` with:
  - typed columns (casts)
  - metadata: `load_date = NOW()`, `source_file_name` = input filename
  - de-duplication via natural key + `ON CONFLICT DO NOTHING`
- Writes a row to `load_log`
- Returns row counts to prove persistence across reruns

### 5) Exercise the endpoints (Analyst Access)

**A) `/metrics` — explicit date range**
```
GET /webhook-test/metrics?start=YYYY-MM-DD&end=YYYY-MM-DD
```
Example:
```bash
curl "http://localhost:5678/webhook-test/metrics?start=2025-01-01&end=2025-01-31"
```
Response shape:
```json
{
  "period": { "start": "2025-01-01", "end": "2025-01-31",
              "prior_start": "2024-12-02", "prior_end": "2024-12-31" },
  "kpis": {
    "cac":  { "curr": 30.40, "prior": 32.36, "delta_abs": -1.96, "delta_pct": -0.0606 },
    "roas": { "curr": 3.29,  "prior": 3.10,  "delta_abs": 0.19,  "delta_pct":  0.0613 }
  },
  "context": {
    "spend":       { "curr": 285365.44, "prior": 271000.00 },
    "conversions": { "curr": 9386,      "prior": 8375 }
  },
  "note": null
}
```

**B) `/ask` — Agent Demo (Bonus)**
```
GET /webhook-test/ask?q=Compare CAC and ROAS for last 30 days vs prior 30 days
```
- Supports two phrasings:
  - “**last 30 days**” — anchored on `MAX(date)` in `ads_spend`
  - “**between YYYY-MM-DD and YYYY-MM-DD**”
- Returns the same JSON plus an `answer_text` in English.

> When the workflow is **Active**, use `/webhook/...` (not `/webhook-test/...`).

---

## Data model & constraints

### Tables
- `staging_ads` — raw CSV shape (all TEXT); no constraints
- `ads_spend` — typed + metadata; **unique** natural key  
  `(date, platform, account, campaign, country, device)`
- `load_log` — one row per source file (`source_file_name`, `load_date`)

### Why NULLs for some metrics?
If the **prior window** has zero spend (ROAS) or zero conversions (CAC), the prior metric is undefined → `NULL`.  
This is **intentional** to avoid misleading zeros or infinite values.

---

## Screenshots to include

- `screenshots/ads_spend_sample.png` — recent rows from `ads_spend` showing `load_date` and `source_file_name`. Example command:
```bash
docker exec -it pg psql -U devuser -d devtest -c "SELECT date::date AS date, platform, account, campaign, country, device,
        spend, conversions, load_date, source_file_name
 FROM ads_spend
 ORDER BY date DESC
 LIMIT 15;"
```
- `screenshots/api_metrics_response.png` — output from `/metrics`.
- `screenshots/api_ask_response.png` — output from `/ask` (Agent Demo).

---

## Rationale / key decisions

- **Natural key** de-dupe at the warehouse boundary to prevent duplicates across reruns.
- **Provenance** captured at merge time (`load_date`, `source_file_name`).
- **Safe math:** CAC/ROAS compute with `NULLIF()` to avoid divide-by-zero; return `NULL` where undefined.
- **Agent demo** keeps scope modest (template mapping vs full NL→SQL) while showing intent-to-query.

---

## Troubleshooting

- **CSV path not found in n8n** → check the volume mount and that your node points to **`/data/ads_spend.csv`** inside the container.
- **`service "pg" is not running` with `docker compose exec`** → either use `docker exec -it pg ...` (if you started with `docker run`) or run the command from the folder that holds your `docker-compose.yml`.
- **`role "..." does not exist`** → connect with the actual user your container was initialized with (e.g., `devuser/devtest`) or create the role/DB.
- **No prior data** → deltas may be `NULL`. This is expected and correct.

---

## Deliverables checklist

1. **n8n access**  
   - URL + read-only user **or** `workflows/ShadowLightStudiosTest.json` (exported)
2. **GitHub repo (public)**  
   - ingestion workflow, SQL models, this README
3. **Results**  
   - screenshots of table and API responses
4. **Loom video (≤ 5 min)**  
   - approach, key nodes/decisions, demo of the two endpoints

---

## License & notes

Use for evaluation/demonstration purposes. Replace datasource credentials before sharing publicly.  
Feel free to extend with dbt models, scheduled runs (Cron node), or additional breakdowns (e.g., by platform/country/campaign).
