# Manual Deployment Steps (No Local Docker Required)

If you don't have Docker running locally, you can deploy using Cloud Build:

## 1. Set up your project
```bash
export PROJECT_ID="your-project-id"
export REGION="us-central1"
gcloud config set project ${PROJECT_ID}
```

## 2. Enable required APIs
```bash
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    containerregistry.googleapis.com \
    iam.googleapis.com
```

## 3. Create service account
```bash
gcloud iam service-accounts create mcp-analytics-server \
    --display-name="MCP Analytics Server" \
    --description="Service account for Google Analytics MCP server"

# Grant logging permission
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:mcp-analytics-server@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/logging.logWriter"
```

## 4. Build using Cloud Build (no local Docker needed!)
```bash
# From the repository root directory
gcloud builds submit . \
    --tag gcr.io/${PROJECT_ID}/google-analytics-mcp \
    --timeout=20m
```

## 5. Deploy to Cloud Run
```bash
gcloud run deploy google-analytics-mcp \
    --image gcr.io/${PROJECT_ID}/google-analytics-mcp \
    --platform managed \
    --region ${REGION} \
    --service-account mcp-analytics-server@${PROJECT_ID}.iam.gserviceaccount.com \
    --set-env-vars "GOOGLE_CLOUD_PROJECT=${PROJECT_ID}" \
    --memory 512Mi \
    --cpu 1 \
    --timeout 3600 \
    --max-instances 10 \
    --min-instances 0 \
    --concurrency 100 \
    --allow-unauthenticated
```

## 6. Get your service URL
```bash
gcloud run services describe google-analytics-mcp \
    --platform managed \
    --region ${REGION} \
    --format 'value(status.url)'
```

## That's it! No local Docker required.

The Cloud Build service will:
- Read your Dockerfile
- Build the container image in the cloud
- Push it to Container Registry
- Deploy it to Cloud Run

## Testing your deployment

Once deployed, test with:
```bash
curl https://YOUR-SERVICE-URL/health
```

For multi-tenant testing, you'll need a service account JSON file:
```bash
# Encode your service account JSON
CREDS=$(base64 < your-service-account.json)

# Test the multi-tenant endpoint
curl -X POST https://YOUR-SERVICE-URL/ \
  -H "Content-Type: application/json" \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"get_account_summaries_mt\",
    \"params\": {
      \"tenant_id\": \"test-tenant\",
      \"tenant_credentials\": \"${CREDS}\"
    },
    \"id\": 1
  }"
```