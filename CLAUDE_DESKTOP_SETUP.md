# Testing Google Analytics MCP Server with Claude Desktop

## Overview

You can test your deployed MCP server with Claude Desktop before integrating it with ADK. This guide shows you how to configure Claude Desktop to use your Cloud Run-deployed server.

## Prerequisites

1. Claude Desktop installed on your computer
2. Your MCP server deployed to Cloud Run (✅ Already done: https://google-analytics-mcp-4quwenkusq-uc.a.run.app)
3. A Google Cloud service account with Google Analytics access

## Configuration Steps

### 1. Locate Claude Desktop Settings

Find your Claude Desktop configuration file:
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
- **Linux**: `~/.config/Claude/claude_desktop_config.json`

### 2. Add MCP Server Configuration

Edit the configuration file to add your MCP server:

```json
{
  "mcpServers": {
    "google-analytics-mcp": {
      "command": "curl",
      "args": [
        "-X", "POST",
        "-H", "Content-Type: application/json",
        "-d", "@-",
        "https://google-analytics-mcp-4quwenkusq-uc.a.run.app/"
      ],
      "env": {}
    }
  }
}
```

However, since Claude Desktop expects stdio communication and your server uses HTTP, you'll need a bridge. Let me create one:

### 3. Create a Local Bridge Script

Create a file called `mcp-http-bridge.py`:

```python
#!/usr/bin/env python3
"""Bridge between stdio (Claude Desktop) and HTTP MCP server."""

import sys
import json
import requests
import logging

# Configure logging
logging.basicConfig(
    filename='mcp-bridge.log',
    level=logging.DEBUG,
    format='%(asctime)s - %(message)s'
)

MCP_SERVER_URL = "https://google-analytics-mcp-4quwenkusq-uc.a.run.app/"

def main():
    """Read JSON-RPC from stdin, forward to HTTP server, return response."""
    while True:
        try:
            # Read line from stdin
            line = sys.stdin.readline()
            if not line:
                break
                
            # Parse JSON-RPC request
            request = json.loads(line.strip())
            logging.debug(f"Received: {request}")
            
            # Forward to HTTP server
            response = requests.post(MCP_SERVER_URL, json=request)
            response_data = response.json()
            logging.debug(f"Response: {response_data}")
            
            # Write response to stdout
            sys.stdout.write(json.dumps(response_data) + '\n')
            sys.stdout.flush()
            
        except Exception as e:
            logging.error(f"Error: {e}")
            error_response = {
                "jsonrpc": "2.0",
                "error": {
                    "code": -32603,
                    "message": str(e)
                },
                "id": request.get("id") if 'request' in locals() else None
            }
            sys.stdout.write(json.dumps(error_response) + '\n')
            sys.stdout.flush()

if __name__ == "__main__":
    main()
```

### 4. Update Claude Desktop Configuration

Now configure Claude Desktop to use the bridge:

```json
{
  "mcpServers": {
    "google-analytics-mcp": {
      "command": "python3",
      "args": ["/path/to/mcp-http-bridge.py"],
      "env": {}
    }
  }
}
```

## Testing Your Setup

### 1. Restart Claude Desktop
After updating the configuration, restart Claude Desktop.

### 2. Test Basic Connection
In Claude Desktop, type:
```
What MCP tools are available?
```

Claude should list the Google Analytics tools.

### 3. Test Multi-Tenant Tool

First, prepare your credentials:

```python
# In a Python script or terminal
import json
import base64

# Your service account JSON
service_account = {
    "type": "service_account",
    "project_id": "your-project",
    "private_key_id": "...",
    "private_key": "...",
    "client_email": "...",
    # ... rest of your service account JSON
}

# Encode it
encoded = base64.b64encode(json.dumps(service_account).encode()).decode()
print(f"Your encoded credentials:\n{encoded}")
```

Then in Claude Desktop:
```
Use the get_account_summaries_mt tool with:
- tenant_id: "test-tenant"
- tenant_credentials: "[paste your encoded credentials here]"
```

### 4. Test a Report

```
Use the run_report_mt tool to get data for the last 7 days for property 123456789 with:
- tenant_id: "test-tenant" 
- tenant_credentials: "[your encoded credentials]"
- property_id: "properties/123456789"
- date_ranges: [{"start_date": "7daysAgo", "end_date": "today"}]
- dimensions: ["country", "deviceCategory"]
- metrics: ["activeUsers", "sessions"]
```

## Alternative: Direct HTTP Testing

If you don't want to use the bridge, you can test directly with curl:

```bash
# Encode your service account
CREDS=$(base64 < your-service-account.json | tr -d '\n')

# Test the multi-tenant tool
curl -X POST https://google-analytics-mcp-4quwenkusq-uc.a.run.app/ \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "get_account_summaries_mt",
    "params": {
      "tenant_id": "test-tenant",
      "tenant_credentials": "'$CREDS'"
    },
    "id": 1
  }' | jq
```

## Troubleshooting

### 1. Connection Issues
- Check the bridge log file: `mcp-bridge.log`
- Verify the server URL is accessible
- Ensure your service account JSON is properly base64 encoded

### 2. Authentication Errors
- Verify your service account has Google Analytics Viewer access
- Check that the service account email is added to your GA property
- Ensure the JSON is valid before encoding

### 3. Tool Not Found
- The tool name must match exactly (e.g., `run_report_mt` not `run_report`)
- Check available tools at https://google-analytics-mcp-4quwenkusq-uc.a.run.app/

## Benefits of Testing with Claude Desktop

1. **Interactive Testing**: Test tools conversationally
2. **Real-time Feedback**: See results immediately
3. **Natural Language**: Describe what you want instead of writing code
4. **Debugging**: Claude can help interpret errors and suggest fixes

## Next Steps

Once you've verified the MCP server works with Claude Desktop:

1. Note which tools work best for your use cases
2. Document any custom parameters needed
3. Plan your ADK agent's conversation flow
4. Implement the same patterns in your ADK code

This testing approach lets you validate your multi-tenant implementation before writing any ADK code!