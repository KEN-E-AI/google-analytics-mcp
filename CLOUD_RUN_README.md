# Cloud Run Deployment for Google Analytics MCP Server

This directory contains all the necessary files to deploy the Google Analytics MCP server to Google Cloud Run for integration with ADK (Agent Development Kit).

## Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/googleanalytics/google-analytics-mcp.git
   cd google-analytics-mcp
   ```

2. **Deploy to Cloud Run**
   ```bash
   ./deploy.sh YOUR_PROJECT_ID us-central1
   ```

3. **Grant Google Analytics Access**
   - Go to [Google Analytics](https://analytics.google.com)
   - Navigate to Admin → Account/Property → Access Management
   - Add the service account email shown in the deployment output
   - Grant 'Viewer' role

4. **Test the deployment**
   ```bash
   curl https://YOUR_SERVICE_URL/health
   ```

## Files Overview

- **`Dockerfile`**: Containerizes the MCP server for Cloud Run
- **`deploy.sh`**: Automated deployment script
- **`cloudbuild.yaml`**: CI/CD configuration for Cloud Build
- **`analytics_mcp/http_server.py`**: HTTP/SSE transport wrapper
- **`.dockerignore`**: Excludes unnecessary files from the container

## Manual Deployment Steps

If you prefer manual deployment:

1. **Build the Docker image**
   ```bash
   docker build -t gcr.io/YOUR_PROJECT_ID/google-analytics-mcp .
   ```

2. **Push to Container Registry**
   ```bash
   docker push gcr.io/YOUR_PROJECT_ID/google-analytics-mcp
   ```

3. **Deploy to Cloud Run**
   ```bash
   gcloud run deploy google-analytics-mcp \
     --image gcr.io/YOUR_PROJECT_ID/google-analytics-mcp \
     --platform managed \
     --region us-central1 \
     --allow-unauthenticated
   ```

## Authentication Options

### 1. Public Access (Development)
Deploy with `--allow-unauthenticated` flag. Simple but less secure.

### 2. Token Authentication
Set `MCP_AUTH_TOKEN` environment variable in Cloud Run and pass token in requests:
```bash
gcloud run services update google-analytics-mcp \
  --set-env-vars MCP_AUTH_TOKEN=your-secret-token
```

### 3. Cloud IAM (Recommended for Production)
Remove `--allow-unauthenticated` and use service account authentication.

## Environment Variables

- `PORT`: Automatically set by Cloud Run
- `MCP_AUTH_TOKEN`: Optional authentication token
- `GOOGLE_CLOUD_PROJECT`: Your GCP project ID
- `ALLOWED_ORIGINS`: CORS allowed origins (default: "*")

## ADK Integration

After deployment, integrate with ADK:

```python
from adk import Agent
from adk.tools.mcp import MCPTool

agent = Agent(
    name="analytics-agent",
    tools=[
        MCPTool(server_url="https://YOUR_CLOUD_RUN_URL")
    ]
)
```

See `ADK_INTEGRATION_GUIDE.md` for detailed integration examples.

## Monitoring

- **Logs**: Available in Cloud Console → Cloud Run → Logs
- **Metrics**: CPU, memory, and request metrics in Cloud Console
- **Health Check**: `GET /health` endpoint

## Troubleshooting

1. **Container fails to start**
   - Check Cloud Run logs for Python errors
   - Verify all dependencies are installed

2. **Authentication errors**
   - Ensure service account has Analytics API permissions
   - Check if ADC is properly configured

3. **Timeout errors**
   - Increase Cloud Run timeout (max 60 minutes)
   - Check if Analytics queries are too complex

## Cost Optimization

- Set minimum instances to 0 for scale-to-zero
- Use appropriate memory allocation (512MB is usually sufficient)
- Monitor usage and adjust max instances

## Security Best Practices

1. Use Cloud IAM for production
2. Rotate auth tokens regularly
3. Monitor access logs
4. Restrict CORS origins in production
5. Keep container images updated

## Support

For issues specific to Cloud Run deployment, please open an issue with the "cloud-run" label.