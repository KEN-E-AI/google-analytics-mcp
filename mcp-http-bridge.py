#!/usr/bin/env python3
"""Bridge between stdio (Claude Desktop) and HTTP MCP server."""

import sys
import json
import requests
import logging
import os

# Configure logging
log_file = os.path.expanduser('~/mcp-bridge.log')
logging.basicConfig(
    filename=log_file,
    level=logging.DEBUG,
    format='%(asctime)s - %(message)s'
)

# Your deployed MCP server URL
MCP_SERVER_URL = "https://google-analytics-mcp-4quwenkusq-uc.a.run.app/"

def handle_list_tools():
    """Handle the tools/list request."""
    response = requests.get(MCP_SERVER_URL)
    if response.status_code == 200:
        data = response.json()
        tools = []
        for tool_name in data.get("tools", []):
            tools.append({
                "name": tool_name,
                "description": f"Google Analytics tool: {tool_name}",
                "inputSchema": {
                    "type": "object",
                    "properties": {},
                    "required": []
                }
            })
        return {
            "tools": tools
        }
    return {"tools": []}

def main():
    """Read JSON-RPC from stdin, forward to HTTP server, return response."""
    logging.info("MCP HTTP Bridge started")
    
    while True:
        try:
            # Read line from stdin
            line = sys.stdin.readline()
            if not line:
                break
                
            # Parse JSON-RPC request
            request = json.loads(line.strip())
            logging.debug(f"Received: {request}")
            
            # Handle special methods
            method = request.get("method", "")
            
            if method == "initialize":
                # Respond to initialization
                response_data = {
                    "jsonrpc": "2.0",
                    "result": {
                        "protocolVersion": "0.1.0",
                        "capabilities": {
                            "tools": {}
                        }
                    },
                    "id": request.get("id")
                }
            elif method == "tools/list":
                # List available tools
                result = handle_list_tools()
                response_data = {
                    "jsonrpc": "2.0",
                    "result": result,
                    "id": request.get("id")
                }
            elif method == "tools/call":
                # Forward tool calls to HTTP server
                tool_name = request.get("params", {}).get("name")
                tool_args = request.get("params", {}).get("arguments", {})
                
                # Create HTTP request
                http_request = {
                    "jsonrpc": "2.0",
                    "method": tool_name,
                    "params": tool_args,
                    "id": request.get("id")
                }
                
                # Forward to server
                response = requests.post(MCP_SERVER_URL, json=http_request)
                response_data = response.json()
                
                # Wrap the result for MCP protocol
                if "result" in response_data:
                    response_data = {
                        "jsonrpc": "2.0",
                        "result": {
                            "content": [
                                {
                                    "type": "text",
                                    "text": json.dumps(response_data["result"], indent=2)
                                }
                            ]
                        },
                        "id": request.get("id")
                    }
                
            else:
                # Unknown method
                response_data = {
                    "jsonrpc": "2.0",
                    "error": {
                        "code": -32601,
                        "message": f"Unknown method: {method}"
                    },
                    "id": request.get("id")
                }
            
            logging.debug(f"Response: {response_data}")
            
            # Write response to stdout
            sys.stdout.write(json.dumps(response_data) + '\n')
            sys.stdout.flush()
            
        except Exception as e:
            logging.error(f"Error: {e}", exc_info=True)
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