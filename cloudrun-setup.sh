#!/usr/bin/env bash
# One-time Google Cloud setup for deploying Lure, Recall and Squiggle to Cloud Run from GitHub
# Actions. Run it in Cloud Shell with your project selected (gcloud config set project ID).
#
# It creates:
#   * an Artifact Registry repository "apps" in us-east1, keeping only each image's 3 newest versions
#   * a service account "github-deployer" that may deploy to Cloud Run and push images
#   * a workload identity pool that trusts GitHub Actions runs from evannwilsonn's repositories,
#     so the pipelines log in without any stored key
# and prints the three values to add as GitHub Actions variables in each repository.
set -euo pipefail

OWNER=evannwilsonn
REPOS="lure recall squiggle"
REGION=us-east1
PROJECT=$(gcloud config get-value project 2>/dev/null)
[ -n "$PROJECT" ] || { echo "Select a project first: gcloud config set project YOUR_PROJECT_ID"; exit 1; }
NUMBER=$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')
SA="github-deployer@$PROJECT.iam.gserviceaccount.com"

echo "Enabling services…"
gcloud services enable run.googleapis.com artifactregistry.googleapis.com iamcredentials.googleapis.com sts.googleapis.com

echo "Image registry…"
gcloud artifacts repositories describe apps --location="$REGION" >/dev/null 2>&1 ||
  gcloud artifacts repositories create apps --repository-format=docker --location="$REGION" \
    --description="Images deployed by the GitHub pipelines"
cat > /tmp/cleanup.json <<'JSON'
[
  {"name": "keep-newest", "action": {"type": "Keep"}, "mostRecentVersions": {"keepCount": 3}},
  {"name": "delete-older", "action": {"type": "Delete"}, "condition": {"olderThan": "1d"}}
]
JSON
gcloud artifacts repositories set-cleanup-policies apps --location="$REGION" --policy=/tmp/cleanup.json --no-dry-run

echo "Deployer account…"
gcloud iam service-accounts describe "$SA" >/dev/null 2>&1 ||
  gcloud iam service-accounts create github-deployer --display-name="GitHub Actions deployer"
for role in roles/run.admin roles/artifactregistry.writer roles/iam.serviceAccountUser; do
  gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$SA" --role="$role" --condition=None --quiet >/dev/null
done

echo "Keyless login from GitHub…"
gcloud iam workload-identity-pools describe github --location=global >/dev/null 2>&1 ||
  gcloud iam workload-identity-pools create github --location=global --display-name="GitHub Actions"
gcloud iam workload-identity-pools providers describe github --location=global --workload-identity-pool=github >/dev/null 2>&1 ||
  gcloud iam workload-identity-pools providers create-oidc github --location=global --workload-identity-pool=github \
    --display-name="GitHub" --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
    --attribute-condition="assertion.repository_owner == '$OWNER'"
POOL="projects/$NUMBER/locations/global/workloadIdentityPools/github"
for repo in $REPOS; do
  gcloud iam service-accounts add-iam-policy-binding "$SA" --role=roles/iam.workloadIdentityUser \
    --member="principalSet://iam.googleapis.com/$POOL/attribute.repository/$OWNER/$repo" --quiet >/dev/null
done

cat <<EOF

Done. Add these three as GitHub Actions *variables* (not secrets) in each of: $REPOS

  GCP_PROJECT       $PROJECT
  GCP_WIF_PROVIDER  $POOL/providers/github
  GCP_DEPLOYER      $SA
EOF
