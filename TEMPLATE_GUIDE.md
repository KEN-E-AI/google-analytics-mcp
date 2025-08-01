# Creating a New MCP Server from This Template

This guide walks you through creating a new multi-tenant MCP server using this repository as a template. We'll use a Salesforce MCP server as an example.

## Prerequisites

- Python 3.9-3.13
- Docker
- Google Cloud SDK (`gcloud`)
- A Google Cloud project with billing enabled

## Step 1: Clone and Initialize

```bash
# Clone this template
git clone https://github.com/your-org/google-analytics-mcp.git mcp-salesforce
cd mcp-salesforce

# Remove git history
rm -rf .git
git init

# Run the initialization script
./init-new-mcp.sh salesforce
```

## Step 2: Update Core Files

### 2.1 Update `pyproject.toml`

Replace Google Analytics dependencies with your service's SDK:

```toml
[project]
name = "salesforce-mcp"
version = "0.1.0"
requires-python = ">=3.9, <3.14"
license = "Apache-2.0"
dependencies = [
    "simple-salesforce>=1.12.0",  # Replace GA dependencies
    "google-auth~=2.40",          # Keep if using Google Cloud
    "mcp[cli]>=1.2.0",           # Keep MCP
    "httpx>=0.28.1",             # Keep for HTTP
    "fastapi",                   # Keep for server
    "uvicorn[standard]"          # Keep for server
]

[project.scripts]
salesforce-mcp = "salesforce_mcp.server:run_server"
```

### 2.2 Update Directory Structure

```bash
# Rename the main package
mv analytics_mcp salesforce_mcp

# Update imports in all Python files
find . -name "*.py" -exec sed -i '' 's/analytics_mcp/salesforce_mcp/g' {} +
find . -name "*.py" -exec sed -i '' 's/Google Analytics/Salesforce/g' {} +
```

### 2.3 Create Your Multi-Tenant Tools

Replace `salesforce_mcp/tools/multitenant.py`:

```python
"""Multi-tenant tools for Salesforce."""

import base64
import json
import logging
from typing import Any, Dict, List

from simple_salesforce import Salesforce

from salesforce_mcp.coordinator import mcp

logger = logging.getLogger(__name__)


def _decode_credentials(tenant_credentials: str) -> Dict[str, str]:
    """Decode and validate tenant Salesforce credentials."""
    try:
        cred_json = base64.b64decode(tenant_credentials).decode('utf-8')
        creds = json.loads(cred_json)
        
        # Validate required fields
        required = ['username', 'password', 'security_token', 'domain']
        for field in required:
            if field not in creds:
                raise ValueError(f"Missing required field: {field}")
        
        return creds
    except Exception as e:
        logger.error(f"Failed to decode credentials: {e}")
        raise ValueError("Invalid credentials format")


def _create_client(creds: Dict[str, str]) -> Salesforce:
    """Create Salesforce client with tenant credentials."""
    return Salesforce(
        username=creds['username'],
        password=creds['password'],
        security_token=creds['security_token'],
        domain=creds.get('domain', 'login')
    )


@mcp.tool()
async def query_salesforce_mt(
    tenant_id: str,
    tenant_credentials: str,
    soql_query: str
) -> List[Dict[str, Any]]:
    """Execute a SOQL query with tenant credentials.
    
    Args:
        tenant_id: Unique identifier for the tenant
        tenant_credentials: Base64-encoded JSON with Salesforce credentials
        soql_query: SOQL query to execute
    """
    creds = _decode_credentials(tenant_credentials)
    sf = _create_client(creds)
    
    result = sf.query(soql_query)
    return result['records']


@mcp.tool()
async def get_account_mt(
    tenant_id: str,
    tenant_credentials: str,
    account_id: str
) -> Dict[str, Any]:
    """Get Salesforce account details with tenant credentials.
    
    Args:
        tenant_id: Unique identifier for the tenant
        tenant_credentials: Base64-encoded JSON with Salesforce credentials
        account_id: Salesforce account ID
    """
    creds = _decode_credentials(tenant_credentials)
    sf = _create_client(creds)
    
    account = sf.Account.get(account_id)
    return dict(account)


@mcp.tool()
async def create_lead_mt(
    tenant_id: str,
    tenant_credentials: str,
    first_name: str,
    last_name: str,
    company: str,
    email: str = None
) -> Dict[str, Any]:
    """Create a new lead with tenant credentials.
    
    Args:
        tenant_id: Unique identifier for the tenant
        tenant_credentials: Base64-encoded JSON with Salesforce credentials
        first_name: Lead's first name
        last_name: Lead's last name
        company: Lead's company
        email: Lead's email (optional)
    """
    creds = _decode_credentials(tenant_credentials)
    sf = _create_client(creds)
    
    lead_data = {
        'FirstName': first_name,
        'LastName': last_name,
        'Company': company
    }
    if email:
        lead_data['Email'] = email
    
    result = sf.Lead.create(lead_data)
    return result
```

### 2.4 Update `simple_server.py`

Update the imports and service information:

```python
# Update imports
from salesforce_mcp.coordinator import mcp
from salesforce_mcp.tools import multitenant  # Your tools

# Update service info in root endpoint
@app.get("/")
async def root():
    return {
        "service": "Salesforce MCP Server",
        "status": "running",
        "tools": [
            "query_salesforce_mt",
            "get_account_mt",
            "create_lead_mt"
        ]
    }
```

## Step 3: Update Documentation

### 3.1 Update README.md

- Change title to "Salesforce MCP Server (Multi-Tenant)"
- Update tool descriptions
- Update API examples
- Keep deployment instructions (they're generic)

### 3.2 Update CLAUDE.md

- Update service name references
- Document your specific tools
- Keep the multi-tenant pattern documentation

## Step 4: Testing

### 4.1 Local Testing

```bash
# Install dependencies
pip install -e .

# Run locally
python simple_server.py

# Test in another terminal
curl http://localhost:8080/health
```

### 4.2 Test with Real Credentials

```python
import base64
import json
import requests

# Prepare Salesforce credentials
sf_creds = {
    "username": "user@example.com",
    "password": "password",
    "security_token": "token",
    "domain": "test"  # or "login" for production
}

encoded = base64.b64encode(json.dumps(sf_creds).encode()).decode()

# Test query
response = requests.post('http://localhost:8080/', json={
    "jsonrpc": "2.0",
    "method": "query_salesforce_mt",
    "params": {
        "tenant_id": "test-tenant",
        "tenant_credentials": encoded,
        "soql_query": "SELECT Id, Name FROM Account LIMIT 5"
    },
    "id": 1
})

print(response.json())
```

## Step 5: Deploy to Cloud Run

```bash
# Use the same deployment script
./quick-deploy.sh YOUR_PROJECT_ID us-central1
```

Your Salesforce MCP server is now deployed!

## Step 6: Update ADK Integration

```python
from adk import Agent
from adk.tools.mcp import MCPClient

# Add to your service registry
MCP_SERVICES = {
    "analytics": "https://mcp-google-analytics-xxx.run.app",
    "salesforce": "https://mcp-salesforce-xxx.run.app",  # Your new service
    # ... other services
}
```

## Common Patterns for Different Services

### Database Services (PostgreSQL, MySQL, MongoDB)
- Credentials: connection string or host/port/user/pass
- Tools: query, insert, update, delete
- Consider connection pooling for performance

### Payment Services (Stripe, PayPal)
- Credentials: API keys
- Tools: create_payment, refund, get_transaction
- Include webhook handling for events

### Communication Services (Slack, Email, SMS)
- Credentials: API tokens or OAuth
- Tools: send_message, list_channels, search
- Handle rate limiting

### File Storage (S3, GCS, Dropbox)
- Credentials: service account or API keys
- Tools: upload, download, list, delete
- Stream large files

## Best Practices

1. **Credential Validation**: Always validate credentials format
2. **Error Handling**: Return clear error messages
3. **Logging**: Log requests (without credentials!)
4. **Rate Limiting**: Respect API limits
5. **Testing**: Include unit tests for credential decoding
6. **Documentation**: Document required credential format

## Troubleshooting

### "Method not found" errors
- Ensure tools are imported in `simple_server.py`
- Check tool names match exactly

### Credential errors
- Verify base64 encoding
- Check all required fields are present
- Test credentials work outside MCP first

### Deployment issues
- Check Dockerfile has all dependencies
- Verify Cloud Run has sufficient memory
- Check logs in Cloud Console

## Next Steps

1. Add more tools as needed
2. Set up monitoring
3. Create service-specific examples
4. Add to your MCP service registry
5. Test with ADK agents

Remember: Each MCP server should focus on one service/API to maintain clarity and ease of maintenance.