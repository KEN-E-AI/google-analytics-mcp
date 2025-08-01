#!/bin/bash

# Google Analytics MCP Server - Cloud Run Deployment Script (Fixed)
# 
# Usage: ./deploy-fixed.sh [PROJECT_ID] [REGION]
# Example: ./deploy-fixed.sh my-project us-central1

set -euo pipefail

# Configuration
PROJECT_ID=${1:-$(gcloud config get-value project)}
REGION=${2:-"us-central1"}
SERVICE_NAME="google-analytics-mcp"
SERVICE_ACCOUNT_NAME="mcp-analytics-server"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Google Analytics MCP Server - Cloud Run Deployment${NC}"
echo "Project ID: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo "Service: ${SERVICE_NAME}"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed${NC}"
    exit 1
fi

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Set the project
echo -e "${YELLOW}Setting project to ${PROJECT_ID}...${NC}"
gcloud config set project ${PROJECT_ID}

# Enable required APIs
echo -e "${YELLOW}Enabling required APIs...${NC}"
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    containerregistry.googleapis.com \
    iam.googleapis.com

# Create service account if it doesn't exist
SA_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
if ! gcloud iam service-accounts describe ${SA_EMAIL} &> /dev/null; then
    echo -e "${YELLOW}Creating service account...${NC}"
    gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME} \
        --display-name="MCP Analytics Server" \
        --description="Service account for Google Analytics MCP server on Cloud Run"
    
    # Grant logging permission for Cloud Run
    echo -e "${YELLOW}Granting Cloud Logging permission...${NC}"
    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${SA_EMAIL}" \
        --role="roles/logging.logWriter"
else
    echo -e "${GREEN}Service account already exists${NC}"
fi

# Build and push Docker image
echo -e "${YELLOW}Building Docker image for linux/amd64 platform...${NC}"
# Use the simpler Dockerfile if the main one fails
if [ -f "Dockerfile.simple" ]; then
    echo -e "${YELLOW}Using simplified Dockerfile...${NC}"
    docker buildx build --platform linux/amd64 -f Dockerfile.simple -t ${IMAGE_NAME} --load .
else
    docker buildx build --platform linux/amd64 -t ${IMAGE_NAME} --load .
fi

echo -e "${YELLOW}Configuring Docker for GCR...${NC}"
gcloud auth configure-docker

echo -e "${YELLOW}Pushing image to Container Registry...${NC}"
docker push ${IMAGE_NAME}

# Deploy to Cloud Run
echo -e "${YELLOW}Deploying to Cloud Run...${NC}"
gcloud run deploy ${SERVICE_NAME} \
    --image ${IMAGE_NAME} \
    --platform managed \
    --region ${REGION} \
    --service-account ${SA_EMAIL} \
    --set-env-vars "GOOGLE_CLOUD_PROJECT=${PROJECT_ID}" \
    --memory 512Mi \
    --cpu 1 \
    --timeout 3600 \
    --max-instances 10 \
    --min-instances 0 \
    --concurrency 100 \
    --allow-unauthenticated

# Get the service URL
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
    --platform managed \
    --region ${REGION} \
    --format 'value(status.url)')

echo ""
echo -e "${GREEN}Deployment complete!${NC}"
echo -e "Service URL: ${SERVICE_URL}"
echo ""
echo -e "${YELLOW}IMPORTANT: Grant Google Analytics Access${NC}"
echo "1. Go to Google Analytics (https://analytics.google.com)"
echo "2. Navigate to Admin → Account or Property → Access Management"
echo "3. Add this service account as a user: ${SA_EMAIL}"
echo "4. Grant 'Viewer' role"
echo ""
echo "To test the deployment after granting Analytics access:"
echo "  curl ${SERVICE_URL}/health"
echo ""
echo "To use with ADK:"
echo "  MCPClient(url='${SERVICE_URL}')"
echo ""
echo "To add authentication:"
echo "  1. Remove --allow-unauthenticated flag and redeploy"
echo "  2. Or set MCP_AUTH_TOKEN environment variable in Cloud Run"