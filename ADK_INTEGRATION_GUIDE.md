# ADK Integration Guide for Google Analytics MCP Server

This guide explains how to integrate the deployed Google Analytics MCP server with Google's Agent Development Kit (ADK).

## Prerequisites

1. Google Analytics MCP server deployed to Cloud Run
2. ADK installed and configured
3. Google Cloud project with necessary APIs enabled

## Integration Steps

### 1. Basic Integration (Public Endpoint)

If your MCP server is deployed with `--allow-unauthenticated`:

```python
from adk import Agent
from adk.tools.mcp import MCPTool

# Create agent with MCP integration
agent = Agent(
    name="analytics-assistant",
    model="gemini-1.5-flash",
    tools=[
        MCPTool(
            server_url="https://google-analytics-mcp-xxxxx-uc.a.run.app"
        )
    ]
)

# Use the agent
response = await agent.run("What are my top events in Google Analytics over the last 30 days?")
```

### 2. Authenticated Integration

For production deployments with authentication:

```python
import os
from adk import Agent
from adk.tools.mcp import MCPTool

# Option A: Using environment variable
os.environ["MCP_AUTH_TOKEN"] = "your-secret-token"

agent = Agent(
    name="analytics-assistant",
    model="gemini-1.5-flash",
    tools=[
        MCPTool(
            server_url="https://google-analytics-mcp-xxxxx-uc.a.run.app",
            headers={
                "Authorization": f"Bearer {os.environ['MCP_AUTH_TOKEN']}"
            }
        )
    ]
)

# Option B: Using Cloud IAM authentication
from google.auth.transport.requests import Request
from google.oauth2 import id_token

def get_cloud_run_token(service_url):
    """Get ID token for Cloud Run service."""
    auth_req = Request()
    token = id_token.fetch_id_token(auth_req, service_url)
    return token

agent = Agent(
    name="analytics-assistant",
    model="gemini-1.5-flash",
    tools=[
        MCPTool(
            server_url="https://google-analytics-mcp-xxxxx-uc.a.run.app",
            headers={
                "Authorization": f"Bearer {get_cloud_run_token(service_url)}"
            }
        )
    ]
)
```

### 3. Advanced Configuration

#### Custom timeout for long-running queries
```python
agent = Agent(
    name="analytics-assistant",
    model="gemini-1.5-flash",
    tools=[
        MCPTool(
            server_url="https://google-analytics-mcp-xxxxx-uc.a.run.app",
            timeout=300  # 5 minutes for complex reports
        )
    ]
)
```

#### Multiple MCP servers
```python
agent = Agent(
    name="multi-tool-assistant",
    model="gemini-1.5-flash",
    tools=[
        MCPTool(
            server_url="https://google-analytics-mcp-xxxxx-uc.a.run.app",
            name="analytics"
        ),
        MCPTool(
            server_url="https://another-mcp-server-yyyyy-uc.a.run.app",
            name="database"
        )
    ]
)
```

## Example Usage Patterns

### 1. Analytics Reporting Agent

```python
from adk import Agent
from adk.tools.mcp import MCPTool

class AnalyticsReportingAgent:
    def __init__(self, mcp_url: str):
        self.agent = Agent(
            name="analytics-reporter",
            model="gemini-1.5-pro",
            system_prompt="""You are an expert Google Analytics analyst. 
            Help users understand their website analytics data and provide insights.""",
            tools=[MCPTool(server_url=mcp_url)]
        )
    
    async def generate_weekly_report(self, property_id: str):
        prompt = f"""
        For Google Analytics property {property_id}, generate a weekly report including:
        1. Top 10 pages by pageviews
        2. User acquisition channels
        3. Top events
        4. Week-over-week comparison
        Use data from the last 7 days compared to the previous 7 days.
        """
        return await self.agent.run(prompt)
    
    async def analyze_user_behavior(self, property_id: str, event_name: str):
        prompt = f"""
        Analyze user behavior for the '{event_name}' event in property {property_id}:
        1. How many times was this event triggered in the last 30 days?
        2. What are the common user segments triggering this event?
        3. What is the trend over time?
        """
        return await self.agent.run(prompt)
```

### 2. Real-time Monitoring Agent

```python
class RealtimeMonitoringAgent:
    def __init__(self, mcp_url: str):
        self.agent = Agent(
            name="realtime-monitor",
            model="gemini-1.5-flash",
            tools=[MCPTool(server_url=mcp_url)]
        )
    
    async def check_active_users(self, property_id: str):
        prompt = f"""
        Using the realtime reporting for property {property_id}:
        1. How many users are currently active?
        2. What pages are they viewing?
        3. What are their geographic locations?
        """
        return await self.agent.run(prompt)
```

## Troubleshooting

### Connection Issues

1. **Timeout errors**: Increase the timeout parameter in MCPTool
2. **Authentication failures**: Verify your auth token or IAM permissions
3. **SSL errors**: Ensure you're using https:// not http://

### Debug Mode

Enable debug logging to see MCP communication:

```python
import logging

logging.basicConfig(level=logging.DEBUG)

agent = Agent(
    name="debug-agent",
    model="gemini-1.5-flash",
    tools=[
        MCPTool(
            server_url="https://google-analytics-mcp-xxxxx-uc.a.run.app",
            debug=True
        )
    ]
)
```

## Security Best Practices

1. **Never hardcode credentials**: Use environment variables or secret managers
2. **Use HTTPS only**: Cloud Run provides automatic HTTPS
3. **Implement rate limiting**: Protect against abuse
4. **Monitor usage**: Set up alerts for unusual activity
5. **Rotate tokens regularly**: If using custom authentication

## Performance Optimization

1. **Connection pooling**: Reuse agent instances when possible
2. **Batch requests**: Combine multiple queries when appropriate
3. **Cache results**: For frequently accessed data
4. **Use appropriate concurrency**: Cloud Run can handle multiple simultaneous requests

## Next Steps

1. Deploy the MCP server to Cloud Run using the provided deployment script
2. Create your first ADK agent with MCP integration
3. Test with simple queries before building complex agents
4. Monitor Cloud Run logs for debugging
5. Scale based on usage patterns

## Support

- MCP Protocol Documentation: https://modelcontextprotocol.io
- ADK Documentation: https://google.github.io/adk-docs/
- Cloud Run Documentation: https://cloud.google.com/run/docs