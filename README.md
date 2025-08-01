# Google Analytics MCP Server (Multi-Tenant)

A production-ready [MCP](https://modelcontextprotocol.io) server for Google Analytics with multi-tenant support. This repository serves as a template for creating MCP servers that can be deployed to Cloud Run and integrated with ADK (Agent Development Kit).

## Features

- ✅ **Multi-tenant support** - Each tenant provides their own credentials
- ✅ **Cloud Run ready** - Dockerized and optimized for serverless deployment
- ✅ **ADK compatible** - Works with Google's Agent Development Kit
- ✅ **Secure by design** - No credential storage, complete tenant isolation
- ✅ **Template structure** - Easy to adapt for other services

> **Note**: This server uses HTTP/JSON-RPC transport and is NOT compatible with Claude Desktop, which requires stdio-based MCP servers. It's designed for production use with ADK or direct HTTP integration.

## Available Tools

### Standard Tools (Single-Tenant)
- `get_account_summaries` - List Google Analytics accounts and properties
- `get_property_details` - Get details about a specific property
- `run_report` - Run analytics reports
- `run_realtime_report` - Get real-time analytics data

### Multi-Tenant Tools (Recommended)
- `get_account_summaries_mt` - List accounts with tenant credentials
- `get_property_details_mt` - Get property details with tenant credentials
- `run_report_mt` - Run reports with tenant credentials
- `run_realtime_report_mt` - Get real-time data with tenant credentials

## Quick Start (Cloud Run Deployment)

### Prerequisites
- Google Cloud Project with billing enabled
- Docker installed (or use Cloud Build)
- `gcloud` CLI installed and configured

### Deploy to Cloud Run

```bash
# Clone this repository
git clone https://github.com/your-org/google-analytics-mcp.git
cd google-analytics-mcp

# Deploy using the provided script
./quick-deploy.sh YOUR_PROJECT_ID us-central1
```

The deployment script will:
1. Build a Docker container
2. Push to Google Container Registry
3. Deploy to Cloud Run
4. Provide you with an HTTPS endpoint

### Test Your Deployment

```bash
# Check health
curl https://YOUR-SERVICE-URL/health

# View available tools
curl https://YOUR-SERVICE-URL/
```

## Multi-Tenant Usage

### 1. Prepare Tenant Credentials

Each tenant needs a Google Cloud service account with Google Analytics access:

```bash
# Create service account (one per tenant)
gcloud iam service-accounts create tenant-analytics \
    --display-name="Tenant Analytics Access"

# Download credentials
gcloud iam service-accounts keys create tenant-sa.json \
    --iam-account=tenant-analytics@PROJECT_ID.iam.gserviceaccount.com

# Base64 encode for use
base64 < tenant-sa.json | tr -d '\n' > tenant-sa-encoded.txt
```

### 2. Grant Google Analytics Access

1. Go to [Google Analytics](https://analytics.google.com)
2. Navigate to Admin → Property → Property Access Management
3. Add the service account email
4. Grant "Viewer" role

### 3. Make API Calls

```python
import base64
import json
import requests

# Prepare credentials
with open('tenant-sa.json', 'r') as f:
    creds = base64.b64encode(f.read().encode()).decode()

# Call multi-tenant tool
response = requests.post('https://YOUR-SERVICE-URL/', json={
    "jsonrpc": "2.0",
    "method": "run_report_mt",
    "params": {
        "tenant_id": "customer-123",
        "tenant_credentials": creds,
        "property_id": "properties/123456789",
        "date_ranges": [{"start_date": "7daysAgo", "end_date": "today"}],
        "dimensions": ["country"],
        "metrics": ["activeUsers"]
    },
    "id": 1
})

print(response.json())
```

## ADK Integration

```python
from adk import Agent
from adk.tools.mcp import MCPClient

# Create agent with MCP integration
agent = Agent(
    name="analytics-assistant",
    tools=[
        MCPClient(
            server_url="https://YOUR-SERVICE-URL",
            name="analytics"
        )
    ]
)

# Use in your application
async def handle_analytics_query(tenant_id: str, credentials: str, query: str):
    response = await agent.run(
        f"Using tenant_id '{tenant_id}' and the provided credentials, {query}"
    )
    return response
```

## Local Development

### Setup
```bash
# Install dependencies
pip install -e .

# Or use make
make install
```

### Development Workflow
```bash
# Run tests
make test

# Run with coverage
make test-coverage

# Format and lint code
make format
make lint

# Run all checks
make check

# Run server locally
make run

# Run with Docker
make docker-run

# Clean build artifacts
make clean
```

### Docker Development
```bash
# Build and run with docker-compose
docker-compose up --build

# Run with specific environment
docker-compose --env-file .env.local up
```

## Using as a Template

This repository is designed to be a template for creating new MCP servers. 

### Quick Start
```bash
# Initialize a new MCP server (e.g., for Salesforce)
./init-new-mcp.sh salesforce

# Or use make
make init-new-service SERVICE=salesforce
```

### Template Features
- 🚀 **Automated initialization** - `init-new-mcp.sh` script transforms the template
- 🔧 **Development tools** - Makefile, Docker Compose, GitHub Actions
- 📝 **Documentation templates** - Issue templates, PR template, CHANGELOG
- 🧪 **Testing setup** - pytest configuration and test structure
- 🌐 **CI/CD ready** - GitHub Actions workflows for testing and deployment
- 🔒 **Security first** - .gitignore configured for credentials and keys

See [TEMPLATE_GUIDE.md](TEMPLATE_GUIDE.md) for detailed instructions.

## Contributing

Contributions welcome! See the [Contributing Guide](CONTRIBUTING.md).
