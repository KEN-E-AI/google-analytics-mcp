# Google Analytics MCP Server - ADK Integration Guide

This guide provides specific instructions for integrating the Google Analytics MCP server (deployed at https://google-analytics-mcp-4quwenkusq-uc.a.run.app) with Google's Agent Development Kit (ADK).

## Server Details

- **Deployed URL**: https://google-analytics-mcp-4quwenkusq-uc.a.run.app
- **Transport**: HTTP/JSON-RPC
- **Authentication**: Currently deployed with `--allow-unauthenticated` (public access)
- **Architecture**: Multi-tenant with credential injection

## Prerequisites

1. ADK installed: `pip install google-adk`
2. Google Analytics service account credentials for your tenants
3. Access to Google Analytics properties

## Basic Integration

### 1. Simple Public Integration

Since the server is deployed with public access, you can integrate directly:

```python
from adk import Agent
from adk.tools.mcp import MCPTool
import base64
import json

# Prepare your Google Analytics credentials
with open('your-service-account.json', 'r') as f:
    service_account = json.load(f)

credentials_base64 = base64.b64encode(
    json.dumps(service_account).encode()
).decode()

# Create agent with the Google Analytics MCP server
agent = Agent(
    name="ga-analytics-assistant",
    model="gemini-1.5-flash",
    system_prompt="""You are a Google Analytics expert assistant. 
    Always use tenant_id 'default' and the provided credentials for all analytics queries.
    The credentials are: """ + credentials_base64,
    tools=[
        MCPTool(
            server_url="https://google-analytics-mcp-4quwenkusq-uc.a.run.app",
            name="google_analytics"
        )
    ]
)

# Use the agent
response = await agent.run(
    "List all my Google Analytics accounts and properties"
)
```

### 2. Multi-Tenant Integration

For applications serving multiple customers:

```python
from adk import Agent
from adk.tools.mcp import MCPTool
import base64
import json

class MultiTenantAnalyticsAgent:
    def __init__(self):
        self.agent = Agent(
            name="multi-tenant-analytics",
            model="gemini-1.5-flash",
            tools=[
                MCPTool(
                    server_url="https://google-analytics-mcp-4quwenkusq-uc.a.run.app",
                    name="analytics"
                )
            ]
        )
        self.tenant_credentials = {}
    
    def register_tenant(self, tenant_id: str, service_account_path: str):
        """Register a tenant with their Google Analytics credentials."""
        with open(service_account_path, 'r') as f:
            creds = json.load(f)
        
        self.tenant_credentials[tenant_id] = base64.b64encode(
            json.dumps(creds).encode()
        ).decode()
    
    async def query_for_tenant(self, tenant_id: str, query: str):
        """Execute an analytics query for a specific tenant."""
        if tenant_id not in self.tenant_credentials:
            raise ValueError(f"Unknown tenant: {tenant_id}")
        
        prompt = f"""
        Using the Google Analytics MCP tools with:
        - tenant_id: {tenant_id}
        - tenant_credentials: {self.tenant_credentials[tenant_id]}
        
        Query: {query}
        
        Always include these parameters when calling any _mt (multi-tenant) tools.
        """
        
        return await self.agent.run(prompt)

# Usage
analytics = MultiTenantAnalyticsAgent()
analytics.register_tenant("customer-123", "customer-123-ga-creds.json")
analytics.register_tenant("customer-456", "customer-456-ga-creds.json")

# Query for specific tenant
result = await analytics.query_for_tenant(
    "customer-123",
    "Show me the top 10 pages by pageviews for the last 7 days"
)
```

## Available Tools

The Google Analytics MCP server provides these multi-tenant tools:

### 1. `get_account_summaries_mt`
Lists all Google Analytics accounts and properties accessible by the tenant's credentials.

```python
# Example prompt
prompt = """
Use get_account_summaries_mt with:
- tenant_id: "customer-123"
- tenant_credentials: "{base64_credentials}"

List all available Google Analytics properties.
"""
```

### 2. `get_property_details_mt`
Gets detailed information about a specific Google Analytics property.

```python
# Example prompt
prompt = """
Use get_property_details_mt with:
- tenant_id: "customer-123"
- tenant_credentials: "{base64_credentials}"
- property_id: "properties/123456789"

Show me the property configuration and data streams.
"""
```

### 3. `run_report_mt`
Runs custom analytics reports with dimensions and metrics.

```python
# Example prompt
prompt = """
Use run_report_mt with:
- tenant_id: "customer-123"
- tenant_credentials: "{base64_credentials}"
- property_id: "properties/123456789"
- date_ranges: [{"start_date": "7daysAgo", "end_date": "today"}]
- dimensions: ["country", "deviceCategory", "pagePath"]
- metrics: ["activeUsers", "sessions", "screenPageViews"]

Generate a report showing traffic by country and device type.
"""
```

### 4. `run_realtime_report_mt`
Gets real-time analytics data (last 30 minutes).

```python
# Example prompt
prompt = """
Use run_realtime_report_mt with:
- tenant_id: "customer-123"
- tenant_credentials: "{base64_credentials}"
- property_id: "properties/123456789"
- dimensions: ["unifiedScreenName"]
- metrics: ["activeUsers"]

Show me what pages users are viewing right now.
"""
```

## Complete Working Example

```python
import asyncio
import base64
import json
from adk import Agent
from adk.tools.mcp import MCPTool

class GoogleAnalyticsAgent:
    def __init__(self, service_account_path: str):
        # Load and encode credentials
        with open(service_account_path, 'r') as f:
            creds = json.load(f)
        
        self.credentials = base64.b64encode(
            json.dumps(creds).encode()
        ).decode()
        
        # Initialize ADK agent
        self.agent = Agent(
            name="ga-reporter",
            model="gemini-1.5-flash",
            system_prompt=f"""You are a Google Analytics expert. 
            For all analytics queries, use these credentials:
            - tenant_id: "default"
            - tenant_credentials: "{self.credentials}"
            
            Always use the multi-tenant (_mt) versions of tools.""",
            tools=[
                MCPTool(
                    server_url="https://google-analytics-mcp-4quwenkusq-uc.a.run.app",
                    name="analytics",
                    timeout=30  # 30 seconds for complex reports
                )
            ]
        )
    
    async def list_properties(self):
        """List all accessible Google Analytics properties."""
        return await self.agent.run(
            "List all my Google Analytics accounts and properties using get_account_summaries_mt"
        )
    
    async def weekly_report(self, property_id: str):
        """Generate a weekly performance report."""
        return await self.agent.run(f"""
            For property {property_id}, create a weekly report using run_report_mt with:
            1. Date range: last 7 days vs previous 7 days
            2. Show top 10 pages by pageviews
            3. Show traffic sources (organic, direct, referral, social)
            4. Show user metrics (new vs returning users)
            5. Include device category breakdown
        """)
    
    async def realtime_dashboard(self, property_id: str):
        """Get current active users and their activities."""
        return await self.agent.run(f"""
            For property {property_id}, using run_realtime_report_mt show:
            1. Current active users count
            2. Top 5 pages being viewed right now
            3. Traffic sources of current users
            4. Geographic distribution of active users
        """)
    
    async def custom_report(self, property_id: str, query: str):
        """Run a custom analytics query."""
        return await self.agent.run(f"""
            For property {property_id}: {query}
            
            Use the appropriate _mt tools to fulfill this request.
        """)

# Usage example
async def main():
    # Initialize with your service account
    ga_agent = GoogleAnalyticsAgent("path/to/your-service-account.json")
    
    # List all properties
    properties = await ga_agent.list_properties()
    print("Available Properties:", properties)
    
    # Generate weekly report for a specific property
    report = await ga_agent.weekly_report("properties/123456789")
    print("Weekly Report:", report)
    
    # Check real-time data
    realtime = await ga_agent.realtime_dashboard("properties/123456789")
    print("Real-time Activity:", realtime)
    
    # Custom query
    custom = await ga_agent.custom_report(
        "properties/123456789",
        "What are the conversion rates for different marketing campaigns?"
    )
    print("Custom Analysis:", custom)

# Run the example
if __name__ == "__main__":
    asyncio.run(main())
```

## Production Considerations

### 1. Credential Security

```python
import os
from google.cloud import secretmanager

class SecureAnalyticsAgent:
    def __init__(self, tenant_id: str):
        # Load credentials from Secret Manager
        client = secretmanager.SecretManagerServiceClient()
        secret_name = f"projects/{os.environ['GCP_PROJECT']}/secrets/ga-creds-{tenant_id}/versions/latest"
        response = client.access_secret_version(request={"name": secret_name})
        creds_json = response.payload.data.decode("UTF-8")
        
        self.credentials = base64.b64encode(creds_json.encode()).decode()
        self.tenant_id = tenant_id
```

### 2. Error Handling

```python
try:
    response = await agent.run(query)
except Exception as e:
    if "403" in str(e):
        print("Permission denied - check if service account has GA access")
    elif "404" in str(e):
        print("Property not found - verify the property ID")
    else:
        print(f"Error: {e}")
```

### 3. Rate Limiting

The Cloud Run service automatically scales but consider implementing client-side rate limiting:

```python
from asyncio import Semaphore

class RateLimitedAgent:
    def __init__(self, max_concurrent_requests=5):
        self.semaphore = Semaphore(max_concurrent_requests)
        # ... initialize agent
    
    async def query(self, prompt: str):
        async with self.semaphore:
            return await self.agent.run(prompt)
```

## Monitoring and Debugging

### 1. View Cloud Run Logs

```bash
gcloud run services logs read google-analytics-mcp \
  --project=YOUR_PROJECT_ID \
  --region=us-central1 \
  --limit=50
```

### 2. Test Endpoint Directly

```bash
# Test health
curl https://google-analytics-mcp-4quwenkusq-uc.a.run.app/health

# Test tool directly
curl -X POST https://google-analytics-mcp-4quwenkusq-uc.a.run.app/ \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "get_account_summaries_mt",
    "params": {
      "tenant_id": "test",
      "tenant_credentials": "YOUR_BASE64_CREDENTIALS"
    },
    "id": 1
  }'
```

### 3. Enable Debug Logging in ADK

```python
import logging
logging.basicConfig(level=logging.DEBUG)

# This will show all MCP communication
```

## Common Issues and Solutions

1. **"Permission denied" errors**
   - Ensure service account has "Viewer" access in Google Analytics
   - Check if the property ID is correct
   - Verify credentials are properly base64 encoded

2. **"Invalid credentials format" errors**
   - Credentials must be base64-encoded JSON
   - Include the entire service account JSON, not just the key

3. **Timeout errors**
   - Increase timeout in MCPTool configuration
   - Consider breaking large date ranges into smaller chunks

4. **Empty results**
   - Verify the date range contains data
   - Check if the metrics/dimensions are valid for GA4

## Next Steps

1. Start with `list_properties()` to verify connectivity
2. Test with simple reports before complex queries
3. Implement proper error handling and retries
4. Monitor Cloud Run metrics for performance
5. Consider implementing caching for frequently accessed data

## Support Resources

- **This MCP Server**: https://github.com/KEN-E-AI/google-analytics-mcp
- **Google Analytics API**: https://developers.google.com/analytics/devguides/reporting/data/v1
- **ADK Documentation**: https://cloud.google.com/agent-builder/docs
- **Cloud Run**: https://cloud.google.com/run/docs