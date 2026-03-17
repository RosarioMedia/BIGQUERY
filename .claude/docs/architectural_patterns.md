# Architectural Patterns

Patterns that appear across multiple files in this codebase.

## 1. Three-Layer Client Abstraction

All external I/O is isolated into dedicated client classes. The orchestrator (`main.py:sync_handler`) never calls APIs or BigQuery directly — it only calls client methods.

| Client | File | External System |
|--------|------|----------------|
| `StripeClient` | `cloud-function/stripe_client.py:14` | Stripe REST API |
| `AutoCareClient` | `cloud-function/autocare_client.py:38` | AutoCare REST API |
| `BigQueryClient` | `cloud-function/bigquery_client.py:15` | Google BigQuery |
| `ReceiverClient` | `cloud-function/receiver_client.py:71` | GHL webhook (via Replit) |

Clients are instantiated once at handler startup and passed around — they are not singletons or globals.

## 2. Raw → Processed → Unified → BI Data Layers

Every data source follows the same four-layer pattern:

1. **Raw layer** (`*_raw` datasets) — full JSON strings, append-only, immutable audit trail
2. **Processed layer** (`*_processed` datasets) — flattened, typed columns, upserted on PK
3. **Unified layer** (`unified.*`) — materialized cross-source join (Stripe ↔ AutoCare via `customer_id = billing_id`)
4. **BI layer** (`bi.*`) — fully denormalized, one row per customer, no arrays/structs

SQL definitions: [sql/create_raw_tables.sql](../../sql/create_raw_tables.sql), [sql/create_processed_tables.sql](../../sql/create_processed_tables.sql), [sql/create_unified_customer_view.sql](../../sql/create_unified_customer_view.sql), [sql/create_bi_customer_360_snapshot.sql](../../sql/create_bi_customer_360_snapshot.sql).

## 3. Incremental Sync via Metadata Table

Stripe syncs are incremental. The pattern used in `main.py` and `bigquery_client.py`:

1. Query `stripe_metadata.sync_history` for `last_sync_timestamp` for the entity
2. Pass `created[gt]=<unix_timestamp>` to the Stripe API
3. On success, write a new row to `sync_history` with the new timestamp

First run uses timestamp `0` (epoch), fetching all historical records. See `cloud-function/stripe_client.py` for the `created[gt]` filter and `cloud-function/bigquery_client.py` for `update_sync_metadata()`.

## 4. Batch BigQuery Inserts (500-row chunks)

BigQuery inserts in `bigquery_client.py` split rows into batches of 500 to control memory:

```
rows → chunks of 500 → client.insert_rows_json() per chunk
```

This pattern appears in every `insert_*` and `upsert_*` method. Do not increase batch size without profiling memory on the Cloud Function instance.

## 5. Retry with Exponential-Style Backoff (AutoCare)

`autocare_client.py` wraps all paginated requests in a retry loop:

- Max retries: 3
- Sleep between retries: 3 seconds (fixed, not exponential)
- Caught exceptions: `ChunkedEncodingError`, `ConnectionError`, `Timeout`, `SSLError`
- On exhausted retries: raises and lets caller handle

This pattern is used for both tier fetching and the streaming marketing data pages.

## 6. Env-Var-First Credential Resolution

Both `autocare_client.py` and `receiver_client.py` resolve credentials with this precedence:

```python
value = os.environ.get("VAR_NAME") or secret_manager_client.access("secret-name")
```

Env vars always win. This lets developers test locally with `.env` without touching Secret Manager. Production deployments set no env vars — Secret Manager is the source of truth.

## 7. Dual Entry Points (Function vs. Job)

The same core logic has two entry points for different runtime constraints:

- **`cloud-function/main.py:sync_handler`** — HTTP-triggered, 9-minute timeout. Runs Stripe + (optionally) AutoCare.
- **`cloud-function/job.py:main`** — Cloud Run Job container, 11+ hour timeout. Runs full AutoCare streaming sync (~700k records), then triggers the Cloud Function with `{"skip_autocare": true}` to complete the Stripe sync without re-running AutoCare.

This split avoids Cloud Function timeout limits for the long-running AutoCare stream.

## 8. CTE-Based SQL for Materialization

Both the unified view and the BI snapshot use CTEs (not subqueries or temp tables). The pattern in `sql/create_unified_customer_view.sql` and `sql/create_bi_customer_360_snapshot.sql`:

```sql
WITH stripe_base AS (...),
     autocare_base AS (...),
     joined AS (... FROM stripe_base LEFT JOIN autocare_base ...)
SELECT ... FROM joined
```

When modifying these queries, maintain the CTE structure — it aids readability and BigQuery's query planner handles them efficiently.

## 9. BigQuery Table Conventions

- **Partition:** `DATE(created)` on time-series tables; `DATE(customer_since)` on the BI snapshot
- **Cluster:** PK column first, then `email` where applicable
- **Raw tables:** `id`, `json_data STRING`, `ingested_at TIMESTAMP`
- **Processed tables:** typed scalar columns + `ingested_at TIMESTAMP` for lineage
- **Upsert pattern:** `MERGE` on PK, `WHEN MATCHED THEN UPDATE`, `WHEN NOT MATCHED THEN INSERT`
