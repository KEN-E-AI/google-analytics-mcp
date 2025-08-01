# Cloud Run Deployment Plan for Google Analytics MCP Server

## Overview

This plan outlines the steps to deploy the Google Analytics MCP server to Cloud Run for use with Google's Agent Development Kit (ADK). The deployment will enable ADK agents to connect to the MCP server via HTTP/SSE transport.

## Architecture

```
ADK Agent (MCP Client) → HTTP/SSE → Cloud Run (MCP Server) → Google Analytics APIs
```

## Phase 1: Modify Server for HTTP Transport

### 1.1 Create HTTP Server Wrapper
- Create `analytics_mcp/http_server.py` to wrap the FastMCP server with HTTP transport
- Implement endpoints:
  - `POST /` - Main JSON-RPC endpoint
  - `GET /sse` - Server-Sent Events endpoint for notifications
- Add CORS support for ADK access

### 1.2 Environment Configuration
- Add support for `PORT` environment variable (Cloud Run requirement)
- Add optional authentication via environment variables
- Support for service account credentials via Cloud Run's built-in auth

## Phase 2: Containerization

### 2.1 Create Dockerfile
```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY pyproject.toml .
RUN pip install -e .

# Copy application code
COPY analytics_mcp/ ./analytics_mcp/

# Set the command to run the HTTP server
CMD ["python", "-m", "analytics_mcp.http_server"]
```

### 2.2 Create .dockerignore
- Exclude development files, tests, and documentation
- Include only necessary runtime files

## Phase 3: Cloud Run Configuration

### 3.1 Service Configuration
- **Memory**: 512MB (adjust based on usage)
- **CPU**: 1 vCPU
- **Concurrency**: 100 (suitable for MCP connections)
- **Request timeout**: 60 minutes (for long-running analytics queries)
- **Environment variables**:
  - `GOOGLE_CLOUD_PROJECT`: Your GCP project ID
  - `MCP_AUTH_TOKEN`: Optional authentication token

### 3.2 Service Account Setup
- Create dedicated service account: `mcp-analytics-server@PROJECT_ID.iam.gserviceaccount.com`
- Grant Cloud permissions:
  - `roles/logging.logWriter` - Cloud Logging access
  - `roles/monitoring.metricWriter` - Cloud Monitoring access (optional)
- Grant Google Analytics access:
  - Go to Google Analytics (analytics.google.com)
  - Navigate to Admin → Account or Property → Access Management
  - Add the service account email as a user
  - Grant 'Viewer' role at the account or property level

### 3.3 Deploy Script
```bash
#!/bin/bash
PROJECT_ID="your-project-id"
SERVICE_NAME="google-analytics-mcp"
REGION="us-central1"

# Build and push image
docker build -t gcr.io/$PROJECT_ID/$SERVICE_NAME .
docker push gcr.io/$PROJECT_ID/$SERVICE_NAME

# Deploy to Cloud Run
gcloud run deploy $SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$SERVICE_NAME \
  --platform managed \
  --region $REGION \
  --service-account mcp-analytics-server@$PROJECT_ID.iam.gserviceaccount.com \
  --set-env-vars GOOGLE_CLOUD_PROJECT=$PROJECT_ID \
  --memory 512Mi \
  --cpu 1 \
  --timeout 3600 \
  --max-instances 10 \
  --allow-unauthenticated
```

## Phase 4: ADK Integration

### 4.1 ADK Configuration
Configure ADK to use the deployed MCP server:

```python
# In your ADK agent configuration
from adk import Agent
from adk.mcp import MCPClient

agent = Agent(
    name="analytics-agent",
    tools=[
        MCPClient(
            url="https://google-analytics-mcp-xxxxx-uc.a.run.app",
            headers={"Authorization": f"Bearer {MCP_AUTH_TOKEN}"}  # Optional
        )
    ]
)
```

### 4.2 Authentication Options
1. **Public endpoint** (allow-unauthenticated): Simple but less secure
2. **Cloud IAM**: Use ADK's service account with Cloud Run invoker role
3. **Custom token**: Pass authentication token via headers

## Phase 5: Monitoring & Operations

### 5.1 Logging
- Structured logging to Cloud Logging
- Log MCP requests and responses
- Monitor Google Analytics API usage

### 5.2 Health Checks
- Implement `/health` endpoint for Cloud Run health checks
- Monitor MCP server availability

### 5.3 Scaling
- Configure autoscaling based on request volume
- Set appropriate min/max instances

## Implementation Timeline

1. **Week 1**: Implement HTTP transport wrapper and test locally
2. **Week 2**: Create Docker configuration and test container
3. **Week 3**: Deploy to Cloud Run staging environment
4. **Week 4**: Production deployment and ADK integration testing

## Security Considerations

1. **Network Security**:
   - Use HTTPS only
   - Implement request validation
   - Rate limiting for API protection

2. **Authentication**:
   - Validate Origin headers
   - Implement bearer token authentication
   - Use Cloud IAM for service-to-service auth

3. **Data Security**:
   - No data persistence in the MCP server
   - Audit logging for all requests
   - Principle of least privilege for service account

## Testing Strategy

1. **Local Testing**:
   - Test HTTP endpoints with curl/httpie
   - Verify MCP protocol compliance
   - Test with local ADK instance

2. **Integration Testing**:
   - Deploy to staging Cloud Run
   - Test with ADK in development environment
   - Verify Google Analytics API integration

3. **Load Testing**:
   - Test concurrent connections
   - Verify autoscaling behavior
   - Monitor resource usage

## Rollback Plan

1. Keep previous Cloud Run revisions
2. Use traffic splitting for gradual rollout
3. Maintain versioned container images
4. Document rollback procedures

## Next Steps

1. Review and approve this plan
2. Create the HTTP server wrapper implementation
3. Set up GCP project and service accounts
4. Begin implementation following the timeline