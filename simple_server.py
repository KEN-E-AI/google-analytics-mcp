#!/usr/bin/env python
"""Simple HTTP server wrapper for MCP with SSE transport."""

import os
import sys
import json
from typing import Dict, Any

# Add app to path
sys.path.insert(0, '/app')

# Import FastAPI (lighter than Starlette for our needs)
from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse
import uvicorn

# Import MCP coordinator and tools
from analytics_mcp.coordinator import mcp
from analytics_mcp.tools.admin import info  # noqa: F401
from analytics_mcp.tools.reporting import realtime  # noqa: F401
from analytics_mcp.tools.reporting import core  # noqa: F401
from analytics_mcp.tools import multitenant  # noqa: F401

# Create FastAPI app
app = FastAPI(title="Google Analytics MCP Server")

@app.get("/")
async def root():
    """Root endpoint with service info."""
    return {
        "service": "Google Analytics MCP Server",
        "status": "running",
        "tools": [
            "get_account_summaries",
            "get_account_summaries_mt",
            "run_report", 
            "run_report_mt",
            "run_realtime_report",
            "run_realtime_report_mt",
            "get_property_details",
            "get_property_details_mt"
        ]
    }

@app.get("/health")
async def health():
    """Health check for Cloud Run."""
    return {"status": "healthy"}

@app.post("/")
async def handle_mcp_request(request: Request):
    """Handle MCP JSON-RPC requests."""
    try:
        body = await request.json()
        
        # Extract method and params
        method = body.get("method")
        params = body.get("params", {})
        request_id = body.get("id")
        
        # Get the tool function
        tool_func = mcp._tools.get(method)
        if not tool_func:
            return JSONResponse(
                content={
                    "jsonrpc": "2.0",
                    "error": {
                        "code": -32601,
                        "message": f"Method not found: {method}"
                    },
                    "id": request_id
                },
                status_code=200
            )
        
        # Execute the tool
        try:
            result = await tool_func(**params)
            return {
                "jsonrpc": "2.0",
                "result": result,
                "id": request_id
            }
        except Exception as e:
            return JSONResponse(
                content={
                    "jsonrpc": "2.0",
                    "error": {
                        "code": -32603,
                        "message": str(e)
                    },
                    "id": request_id
                },
                status_code=200
            )
            
    except Exception as e:
        return JSONResponse(
            content={
                "jsonrpc": "2.0",
                "error": {
                    "code": -32700,
                    "message": "Parse error"
                },
                "id": None
            },
            status_code=200
        )

if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    print(f"Starting server on port {port}")
    uvicorn.run(app, host="0.0.0.0", port=port)