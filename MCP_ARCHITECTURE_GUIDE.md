# MCP Server Architecture Guide for Multi-Server Applications

## Recommended Architecture: Separate Repositories

For applications using 20-30 MCP servers, use separate repositories for each server.

### Why Separate Repositories?

1. **Independent Deployment Cycles**
   - Each MCP server can be updated without affecting others
   - No risk of breaking unrelated servers during deployment
   - Teams can work on different servers simultaneously

2. **Clear Ownership & Permissions**
   - Different teams can own different MCP servers
   - Granular access control per service
   - Clear responsibility boundaries

3. **Scalability**
   - Easy to add new MCP servers without cluttering existing ones
   - Each server can have its own CI/CD pipeline
   - Independent scaling based on usage

4. **Maintainability**
   - Focused codebase for each service
   - Easier to understand and debug
   - Service-specific documentation

## Recommended Repository Structure

### 1. Naming Convention
```
mcp-[service-name]
```

Examples:
- `mcp-google-analytics`
- `mcp-salesforce`
- `mcp-stripe-payments`
- `mcp-github-repos`
- `mcp-slack-messaging`

### 2. Standard Repository Structure
Each MCP server repository should follow this structure:

```
mcp-[service-name]/
├── README.md                 # Service-specific documentation
├── CLAUDE.md                # Claude-specific guidance
├── Dockerfile               # Containerization
├── cloudbuild.yaml         # CI/CD configuration
├── deploy.sh               # Deployment script
├── pyproject.toml          # Python dependencies
├── [service]_mcp/          # Source code
│   ├── __init__.py
│   ├── coordinator.py      # MCP instance
│   ├── server.py          # Entry point
│   └── tools/             # Tool implementations
│       ├── __init__.py
│       └── *.py           # Tool modules
├── tests/                  # Unit tests
└── examples/              # Usage examples
```

### 3. Shared Infrastructure Repository
Create one repository for shared resources:

```
mcp-infrastructure/
├── terraform/             # Infrastructure as Code
│   ├── modules/
│   │   ├── mcp-service/  # Reusable Cloud Run module
│   │   └── monitoring/   # Shared monitoring
│   └── environments/
│       ├── dev/
│       └── prod/
├── scripts/
│   ├── deploy-template.sh
│   └── create-new-mcp.sh
├── templates/
│   ├── Dockerfile.template
│   ├── server.py.template
│   └── cloudbuild.yaml.template
└── docs/
    ├── deployment-guide.md
    └── mcp-standards.md
```

## Deployment Strategy

### 1. Standardized Cloud Run Deployment

Each MCP server gets its own Cloud Run service:
```
https://mcp-google-analytics-xxxxx.a.run.app
https://mcp-salesforce-xxxxx.a.run.app
https://mcp-stripe-payments-xxxxx.a.run.app
```

### 2. Service Discovery

Create a service registry for your ADK application:

```python
# mcp_registry.py
MCP_SERVICES = {
    "analytics": {
        "url": "https://mcp-google-analytics-xxxxx.a.run.app",
        "description": "Google Analytics data access",
        "multi_tenant": True
    },
    "salesforce": {
        "url": "https://mcp-salesforce-xxxxx.a.run.app",
        "description": "Salesforce CRM integration",
        "multi_tenant": True
    },
    "stripe": {
        "url": "https://mcp-stripe-payments-xxxxx.a.run.app",
        "description": "Stripe payment processing",
        "multi_tenant": True
    },
    # ... add more as needed
}
```

### 3. ADK Integration Pattern

```python
from adk import Agent
from adk.tools.mcp import MCPClient
from mcp_registry import MCP_SERVICES

class MultiServiceAgent:
    def __init__(self, enabled_services: List[str]):
        self.mcp_clients = {}
        
        # Initialize only the needed MCP clients
        for service in enabled_services:
            if service in MCP_SERVICES:
                config = MCP_SERVICES[service]
                self.mcp_clients[service] = MCPClient(
                    server_url=config["url"],
                    name=service
                )
        
        # Create agent with all MCP tools
        self.agent = Agent(
            name="multi-service-assistant",
            tools=list(self.mcp_clients.values())
        )
```

## Repository Management

### 1. Create New MCP Server Script

```bash
#!/bin/bash
# create-new-mcp.sh

SERVICE_NAME=$1
TEMPLATE_REPO="https://github.com/your-org/mcp-template"

# Clone template
git clone $TEMPLATE_REPO mcp-$SERVICE_NAME

# Update configurations
cd mcp-$SERVICE_NAME
find . -type f -exec sed -i "s/TEMPLATE_SERVICE/$SERVICE_NAME/g" {} +

# Initialize new repo
rm -rf .git
git init
git add .
git commit -m "Initial commit for mcp-$SERVICE_NAME"

echo "Created new MCP server: mcp-$SERVICE_NAME"
```

### 2. Standardized CI/CD

Each repository uses the same Cloud Build configuration:

```yaml
# cloudbuild.yaml (template)
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/mcp-${_SERVICE_NAME}', '.']
  
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/mcp-${_SERVICE_NAME}']
  
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: gcloud
    args:
      - 'run'
      - 'deploy'
      - 'mcp-${_SERVICE_NAME}'
      - '--image=gcr.io/$PROJECT_ID/mcp-${_SERVICE_NAME}'
      - '--region=${_REGION}'
      - '--platform=managed'

substitutions:
  _SERVICE_NAME: '${REPO_NAME#mcp-}'  # Extract from repo name
  _REGION: 'us-central1'
```

## Monitoring & Observability

### 1. Centralized Logging
All MCP servers send logs to the same Cloud Logging project:
```python
import google.cloud.logging

# In each MCP server
logging_client = google.cloud.logging.Client()
logging_client.setup_logging()
```

### 2. Unified Dashboards
Create Cloud Monitoring dashboards that show all MCP services:
- Request rates per service
- Error rates per service
- Latency percentiles
- Active tenants per service

### 3. Health Check Aggregator
```python
# health_checker.py
async def check_all_services():
    results = {}
    for service, config in MCP_SERVICES.items():
        try:
            response = await httpx.get(f"{config['url']}/health")
            results[service] = response.json()
        except:
            results[service] = {"status": "unhealthy"}
    return results
```

## Example: Adding a New MCP Server

1. **Create Repository**
   ```bash
   ./create-new-mcp.sh stripe-payments
   ```

2. **Implement Tools**
   ```python
   # mcp-stripe-payments/stripe_mcp/tools/payments.py
   @mcp.tool()
   async def create_payment_intent_mt(
       tenant_id: str,
       tenant_credentials: str,
       amount: int,
       currency: str = "usd"
   ):
       # Implementation
   ```

3. **Deploy**
   ```bash
   cd mcp-stripe-payments
   ./deploy.sh $PROJECT_ID us-central1
   ```

4. **Register**
   ```python
   # Update mcp_registry.py
   MCP_SERVICES["stripe"] = {
       "url": "https://mcp-stripe-payments-xxxxx.a.run.app",
       "description": "Stripe payment processing",
       "multi_tenant": True
   }
   ```

## Benefits of This Approach

1. **Isolation**: Problems in one MCP server don't affect others
2. **Flexibility**: Each service can use different languages/frameworks
3. **Team Autonomy**: Different teams can own different services
4. **Cost Tracking**: Cloud Run bills per service
5. **Security**: Separate service accounts per MCP server
6. **Versioning**: Independent version management

## Migration Path

If you later need to consolidate:
1. Services can be combined into larger services
2. Multiple MCP servers can share a Cloud Run instance
3. Common code can be extracted to shared libraries

But starting with separation gives you maximum flexibility.