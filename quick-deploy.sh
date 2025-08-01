#!/bin/bash

# Quick deployment using Cloud Build (no local Docker needed)
# This avoids all architecture issues by building in the cloud

set -euo pipefail

PROJECT_ID="ken-e-production"
REGION="us-central1"
SERVICE_NAME="google-analytics-mcp"

echo "Quick deployment for ${PROJECT_ID}"
echo ""

# Step 1: Build in the cloud
echo "Building image with Cloud Build..."
gcloud builds submit . --tag gcr.io/${PROJECT_ID}/${SERVICE_NAME} --timeout=20m

# Step 2: Deploy to Cloud Run
echo ""
echo "Deploying to Cloud Run..."
gcloud run deploy ${SERVICE_NAME} \
    --image gcr.io/${PROJECT_ID}/${SERVICE_NAME} \
    --platform managed \
    --region ${REGION} \
    --service-account mcp-analytics-server@${PROJECT_ID}.iam.gserviceaccount.com \
    --memory 512Mi \
    --cpu 1 \
    --timeout 3600 \
    --max-instances 10 \
    --allow-unauthenticated

# Get the service URL
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
    --platform managed \
    --region ${REGION} \
    --format 'value(status.url)')

echo ""
echo "Deployment complete!"
echo "Service URL: ${SERVICE_URL}"
echo ""
echo "Test with: curl ${SERVICE_URL}/health"