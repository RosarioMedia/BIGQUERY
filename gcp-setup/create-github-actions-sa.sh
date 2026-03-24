#!/bin/bash
# One-time setup: create the GitHub Actions service account with all
# permissions needed to deploy Cloud Functions, Cloud Run Jobs, and BigQuery DDL.
#
# Run this ONCE from Cloud Shell or any machine authenticated as a project owner.
# After running, download the JSON key and add it to GitHub Secrets.

set -e

PROJECT_ID="hitech-484412"
SA_NAME="github-actions-sa"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
RUNTIME_SA="stripe-sync-sa@${PROJECT_ID}.iam.gserviceaccount.com"
KEY_FILE="github-actions-key.json"

echo "=========================================="
echo "Creating GitHub Actions Service Account"
echo "Project : $PROJECT_ID"
echo "SA Email: $SA_EMAIL"
echo "=========================================="
echo ""

# ── Create the service account ────────────────────────────────────────────────
echo "Creating service account..."
gcloud iam service-accounts create "$SA_NAME" \
  --display-name="GitHub Actions CI/CD" \
  --project="$PROJECT_ID"
echo "  Done."
echo ""

# ── Assign IAM roles ──────────────────────────────────────────────────────────
echo "Assigning IAM roles..."

# Deploy Cloud Functions (Gen2)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/cloudfunctions.developer"
echo "  ✓ roles/cloudfunctions.developer"

# Submit Cloud Build jobs (Docker build for Cloud Run Job)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/cloudbuild.builds.editor"
echo "  ✓ roles/cloudbuild.builds.editor"

# Push images to Artifact Registry
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/artifactregistry.writer"
echo "  ✓ roles/artifactregistry.writer"

# Create / update Cloud Run Jobs
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/run.developer"
echo "  ✓ roles/run.developer"

# Create BigQuery datasets and run DDL queries
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/bigquery.dataEditor"
echo "  ✓ roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/bigquery.jobUser"
echo "  ✓ roles/bigquery.jobUser"

# Allow github-actions-sa to act AS the runtime SA (stripe-sync-sa)
# Required for --service-account flag in gcloud functions deploy and run jobs create/update
gcloud iam service-accounts add-iam-policy-binding "$RUNTIME_SA" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/iam.serviceAccountUser" \
  --project="$PROJECT_ID"
echo "  ✓ roles/iam.serviceAccountUser on $RUNTIME_SA"

echo ""
echo "All IAM roles assigned."
echo ""

# ── Download JSON key ─────────────────────────────────────────────────────────
echo "Downloading service account key to $KEY_FILE..."
gcloud iam service-accounts keys create "$KEY_FILE" \
  --iam-account="$SA_EMAIL"
echo ""
echo "=========================================="
echo "Done! Key saved to: $KEY_FILE"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Open GitHub → repo → Settings → Secrets and variables → Actions"
echo "  2. Add the following secrets:"
echo ""
echo "     GCP_SA_KEY         → paste the full contents of $KEY_FILE"
echo "     GCP_PROJECT_ID     → hitech-484412"
echo "     STRIPE_FUNCTION_URL → (see below)"
echo ""
echo "  3. Get STRIPE_FUNCTION_URL:"
echo "     gcloud functions describe stripe-bigquery-sync \\"
echo "       --region=us-central1 \\"
echo "       --gen2 \\"
echo "       --project=$PROJECT_ID \\"
echo "       --format='value(serviceConfig.uri)'"
echo ""
echo "  4. After adding all 3 secrets, push any change to cloud-function/ or sql/"
echo "     on the main branch to trigger the first automated deploy."
echo ""
echo "  IMPORTANT: Delete $KEY_FILE from your local machine after uploading to GitHub."
echo "             Never commit this file — it is listed in .gitignore."
echo ""
