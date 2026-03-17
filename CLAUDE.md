# Scrape-Stripe

## Project Overview

Production ETL pipeline that syncs Stripe payment data and AutoCare API membership data to Google BigQuery daily. Runs serverlessly via Cloud Functions + Cloud Run Jobs, with incremental loading, full audit trail, and a BI-ready unified customer view.

## Tech Stack

- **Language:** Python 3.12
- **Compute:** GCP Cloud Functions (Gen2, HTTP trigger) + Cloud Run Jobs (container)
- **Data Warehouse:** Google BigQuery
- **Secrets:** Google Secret Manager
- **Orchestration:** Cloud Scheduler (cron)
- **Key Libraries:** `functions-framework`, `google-cloud-bigquery`, `google-cloud-secret-manager`, `requests`, `flask`

## Key Directories

| Path | Purpose |
|------|---------|
| `cloud-function/` | Deployable Cloud Function package (main application code) |
| `gcp-setup/` | Bash scripts to provision all GCP infrastructure |
| `sql/` | BigQuery table DDL and BI query definitions |
| `docs/` | Detailed docs for AutoCare and BI schemas |

### Core Modules (`cloud-function/`)

| File | Role |
|------|------|
| `main.py` | HTTP entry point — `sync_handler()` orchestrates all sync steps |
| `stripe_client.py` | Stripe API client with incremental fetch |
| `autocare_client.py` | AutoCare API client (JWT auth, pagination, retry) |
| `bigquery_client.py` | All BigQuery operations (insert, upsert, materialize) |
| `receiver_client.py` | Webhook sender to GHL via Replit endpoint |
| `job.py` | Cloud Run Job entrypoint for long-running AutoCare sync |

## Data Layer Architecture

```
stripe_raw.*          — full JSON backups (audit trail)
stripe_processed.*    — flattened, queryable tables
autocare_raw.*        — raw AutoCare API responses
autocare_processed.*  — flattened AutoCare tables
stripe_metadata.*     — incremental sync tracking
unified.customers     — materialized join of Stripe + AutoCare
bi.*                  — denormalized 360° snapshot for BI tools
```

## Essential Commands

### Local Testing

```bash
# Test API connectivity before deploying
python test_stripe_api.py
python test_autocare_api.py

# Cross-match data between Stripe and AutoCare
python cross_match.py
```

### GCP Deployment

```bash
# One-shot full setup (APIs, secrets, tables, deploy, scheduler)
cd gcp-setup && ./full-setup.sh

# Individual steps
./setup.sh              # Enable APIs, create service account
./setup-secrets.sh      # Store credentials in Secret Manager
./create-tables.sh      # Create all BigQuery datasets + tables
./deploy-function.sh    # Deploy Cloud Function
./deploy-job.sh         # Deploy Cloud Run Job
./setup-scheduler.sh    # Configure daily trigger (0 6 * * *)
```

### Manual Triggers

```bash
# Trigger Cloud Function directly
curl -X POST <FUNCTION_URL> -H "Content-Type: application/json" \
  -d '{"entities": ["customers", "subscriptions"]}'

# Trigger via Cloud Scheduler
gcloud scheduler jobs run stripe-bigquery-daily-sync --location=us-central1

# Run long AutoCare sync as Cloud Run Job
gcloud run jobs execute autocare-sync-job --region=us-central1

# Skip AutoCare (Stripe only)
curl -X POST <FUNCTION_URL> -d '{"skip_autocare": true}'
```

### View Logs

```bash
gcloud functions logs read stripe-bigquery-sync --region=us-central1 --limit=50
```

## Environment Variables

Local testing uses `.env` (excluded from git). Cloud deployment reads from Secret Manager:

| Variable | Secret Name | Used By |
|----------|-------------|---------|
| `STRIPE_SECRET_KEY` | `stripe-api-key` | `stripe_client.py` |
| `AUTOCARE_EMAIL` | `autocare-api-email` | `autocare_client.py` |
| `AUTOCARE_PASSWORD` | `autocare-api-password` | `autocare_client.py` |
| `REPLIT_WEBHOOK_URL` | `replit-webhook-url` | `receiver_client.py` |
| `REPLIT_WEBHOOK_SECRET` | `replit-webhook-secret` | `receiver_client.py` |

Env vars take precedence over Secret Manager (allows local overrides for testing).

## Additional Documentation

Consult these files when working on specific areas:

- [.claude/docs/architectural_patterns.md](.claude/docs/architectural_patterns.md) — Recurring design patterns, BigQuery conventions, error handling strategy, and sync logic
- [docs/AUTOCARE_BIGQUERY.md](docs/AUTOCARE_BIGQUERY.md) — AutoCare data structure, sync logic, and table schemas
- [docs/BI_CUSTOMER_360.md](docs/BI_CUSTOMER_360.md) — BI snapshot table schema and refresh logic
- [GCP_DEPLOY_GUIDE.md](GCP_DEPLOY_GUIDE.md) — Step-by-step deployment reference
- [sql/example_queries.sql](sql/example_queries.sql) — Sample analytics queries and data freshness checks
