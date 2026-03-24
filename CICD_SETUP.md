# CI/CD Setup Guide

GitHub Actions pipeline that auto-deploys the Cloud Function and BigQuery DDL when you push to `main`.

**GCP Project:** `hitech-484412`

---

## How it works

| What changed in the push | What gets deployed |
|---|---|
| Anything in `cloud-function/` | Cloud Function (`stripe-bigquery-sync`) |
| Anything in `sql/` | BigQuery DDL (all `sql/*.sql` files, idempotent) |
| Only `docs/`, `*.md`, `gcp-setup/` | Nothing — pipeline skips all jobs |

The Cloud Run Job (`cloud-function/job.py`) is **not deployed by CI/CD** — it exists in the codebase as a fallback for long-running AutoCare syncs but is not currently in use. It is kept commented-out in `deploy.yml` for easy re-activation if needed.

---

## Step 1 — Create the GitHub Actions GCP service account

Run this **once** from [Google Cloud Shell](https://shell.cloud.google.com) or any terminal authenticated as a project owner on `hitech-484412`.

```bash
# Clone the repo in Cloud Shell (if not already there)
git clone https://github.com/YOUR_ORG/YOUR_REPO.git
cd YOUR_REPO

# Make the script executable and run it
chmod +x gcp-setup/create-github-actions-sa.sh
./gcp-setup/create-github-actions-sa.sh
```

This script will:
- Create service account `github-actions-sa@hitech-484412.iam.gserviceaccount.com`
- Assign these IAM roles:
  - `roles/cloudfunctions.developer` — deploy Cloud Functions
  - `roles/cloudbuild.builds.editor` — submit Docker builds (kept for future Cloud Run Job use)
  - `roles/artifactregistry.writer` — push images to Artifact Registry (kept for future use)
  - `roles/run.developer` — create/update Cloud Run Jobs (kept for future use)
  - `roles/bigquery.dataEditor` — create datasets and tables
  - `roles/bigquery.jobUser` — run BigQuery DDL queries
  - `roles/iam.serviceAccountUser` on `stripe-sync-sa` — required to set `--service-account` during deploy
- Download `github-actions-key.json` to the current directory

---

## Step 2 — Add GitHub Secrets

Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.

Add this **1 secret**:

| Secret name | Value | Where to get it |
|---|---|---|
| `GCP_SA_KEY` | Full JSON contents of `github-actions-key.json` | Output of Step 1 |

Note: `GCP_PROJECT_ID` is NOT needed as a secret — `hitech-484412` is hardcoded directly in `deploy.yml`.

**How to add `GCP_SA_KEY`:**
1. Open `github-actions-key.json` in a text editor
2. Select all (Ctrl+A) and copy the entire contents
3. Paste as the secret value in GitHub

**After adding the secret, delete the key file from your local machine:**

```bash
rm github-actions-key.json
```

The file is already in `.gitignore` but delete it to avoid accidental exposure.

---

## Step 3 — First deploy

The pipeline triggers automatically on any push to `main`. To trigger it immediately:

```bash
# Push any real change to cloud-function/ or sql/, or use an empty commit:
git commit --allow-empty -m "chore: trigger CI/CD first deploy"
git push origin main
```

Watch the run at: `https://github.com/YOUR_ORG/YOUR_REPO/actions`

---

## What the pipeline deploys (details)

### Cloud Function (`deploy-function` job)

- Source: `cloud-function/` directory
- Runtime: `python311`, 2 GB memory, 540s timeout
- Entry point: `sync_handler`
- Runtime service account: `stripe-sync-sa@hitech-484412.iam.gserviceaccount.com`
- Only env var baked in at deploy time: `GOOGLE_CLOUD_PROJECT=hitech-484412`
- All secrets (Stripe key, AutoCare creds, webhook secret) are read from **Secret Manager at runtime** — they are NOT baked in as env vars

### BigQuery DDL (`deploy-tables` job)

Runs these SQL files in order (all use `CREATE ... IF NOT EXISTS` — safe to re-run):

1. `sql/create_metadata_tables.sql`
2. `sql/create_raw_tables.sql`
3. `sql/create_processed_tables.sql`
4. `sql/create_autocare_raw_tables.sql`
5. `sql/create_autocare_processed_tables.sql`
6. `sql/create_autocare_metadata_tables.sql`
7. `sql/drop_autocare_staging_tables.sql`
8. `sql/create_promoapp_tables.sql`

**Not run by CI:** `sql/create_unified_customer_view.sql` — this file contains a `PROJECT_ID` placeholder that must be substituted manually. Run it once:

```bash
sed 's/PROJECT_ID/hitech-484412/g' sql/create_unified_customer_view.sql | \
  bq query --use_legacy_sql=false --project_id=hitech-484412
```

---

## Troubleshooting

**Job fails with "permission denied" on `gcloud functions deploy`**
→ The `github-actions-sa` needs `roles/iam.serviceAccountUser` on `stripe-sync-sa`. Re-run `create-github-actions-sa.sh`.

**`deploy-tables` runs but `deploy-function` does not (or vice versa)**
→ Expected — path filtering means only the jobs relevant to the changed files run.

**Want to enable the Cloud Run Job in CI/CD?**
→ See the commented-out `deploy-job` section at the bottom of `.github/workflows/deploy.yml` and follow the inline instructions there.
