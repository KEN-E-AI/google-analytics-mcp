#!/usr/bin/env python3

"""
Example: Using Google Analytics MCP Server with ADK in a Multi-Tenant Application

This example demonstrates how to integrate the deployed MCP server with ADK
for multi-tenant analytics access.
"""

import base64
import json
import os
from typing import Dict, Any

# This would be your ADK import
# from adk import Agent
# from adk.tools.mcp import MCPClient

# For this example, we'll show the pattern
class MockMCPClient:
    """Mock MCP client for demonstration"""
    def __init__(self, server_url: str):
        self.server_url = server_url
    
    async def call_tool(self, tool_name: str, **kwargs):
        print(f"Calling {tool_name} with {kwargs}")
        return {"status": "mock_response"}


class TenantAnalyticsService:
    """Service for managing multi-tenant Google Analytics access"""
    
    def __init__(self, mcp_server_url: str):
        self.mcp_client = MockMCPClient(mcp_server_url)
        # In production, use a secure credential store
        self.credential_store = {}
    
    def register_tenant(self, tenant_id: str, service_account_json: Dict[str, Any]):
        """Register a tenant with their Google Analytics credentials"""
        # In production, encrypt before storing
        self.credential_store[tenant_id] = base64.b64encode(
            json.dumps(service_account_json).encode()
        ).decode()
    
    def _get_tenant_credentials(self, tenant_id: str) -> str:
        """Retrieve tenant credentials (base64 encoded)"""
        if tenant_id not in self.credential_store:
            raise ValueError(f"Tenant {tenant_id} not registered")
        return self.credential_store[tenant_id]
    
    async def get_tenant_properties(self, tenant_id: str):
        """Get all Google Analytics properties accessible by the tenant"""
        credentials = self._get_tenant_credentials(tenant_id)
        
        result = await self.mcp_client.call_tool(
            "get_account_summaries_mt",
            tenant_id=tenant_id,
            tenant_credentials=credentials
        )
        
        # Extract property list from account summaries
        properties = []
        for account in result.get("account_summaries", []):
            for prop in account.get("property_summaries", []):
                properties.append({
                    "property_id": prop["property"],
                    "display_name": prop["display_name"],
                    "account": account["display_name"]
                })
        
        return properties
    
    async def run_tenant_report(
        self,
        tenant_id: str,
        property_id: str,
        date_range: str = "last_30_days"
    ):
        """Run a basic report for a tenant"""
        credentials = self._get_tenant_credentials(tenant_id)
        
        # Convert date range to API format
        date_ranges = []
        if date_range == "last_30_days":
            date_ranges = [{
                "start_date": "30daysAgo",
                "end_date": "today"
            }]
        
        return await self.mcp_client.call_tool(
            "run_report_mt",
            tenant_id=tenant_id,
            tenant_credentials=credentials,
            property_id=property_id,
            date_ranges=date_ranges,
            dimensions=["date", "country"],
            metrics=["activeUsers", "sessions", "screenPageViews"]
        )
    
    async def get_realtime_users(self, tenant_id: str, property_id: str):
        """Get realtime active users for a tenant's property"""
        credentials = self._get_tenant_credentials(tenant_id)
        
        return await self.mcp_client.call_tool(
            "run_realtime_report_mt",
            tenant_id=tenant_id,
            tenant_credentials=credentials,
            property_id=property_id,
            metrics=["activeUsers"],
            dimensions=["country", "deviceCategory"]
        )


# Example usage with ADK
async def create_multitenant_agent(mcp_server_url: str):
    """Create an ADK agent configured for multi-tenant analytics"""
    
    # In real ADK usage:
    # from adk import Agent
    # from adk.tools.mcp import MCPTool
    
    # agent = Agent(
    #     name="multitenant-analytics-assistant",
    #     model="gemini-1.5-flash",
    #     system_prompt="""You are an analytics assistant that helps users 
    #     understand their Google Analytics data. Each user query includes 
    #     their tenant_id for proper data isolation.""",
    #     tools=[
    #         MCPTool(
    #             server_url=mcp_server_url,
    #             name="analytics"
    #         )
    #     ]
    # )
    # return agent
    
    # For demo purposes:
    return TenantAnalyticsService(mcp_server_url)


# Example: Handling a tenant request
async def handle_tenant_analytics_request(
    tenant_id: str,
    query: str,
    analytics_service: TenantAnalyticsService
):
    """Process an analytics query for a specific tenant"""
    
    # Example queries that could come from users
    if "properties" in query.lower():
        return await analytics_service.get_tenant_properties(tenant_id)
    
    elif "realtime" in query.lower():
        # In production, extract property_id from query or context
        property_id = "properties/123456789"
        return await analytics_service.get_realtime_users(tenant_id, property_id)
    
    else:
        # Default to a standard report
        property_id = "properties/123456789"
        return await analytics_service.run_tenant_report(tenant_id, property_id)


def main():
    """Example workflow"""
    
    # 1. Deploy MCP server to Cloud Run
    mcp_server_url = "https://analytics-mcp-xxxxx-uc.a.run.app"
    
    # 2. Initialize service
    analytics_service = TenantAnalyticsService(mcp_server_url)
    
    # 3. Register tenants with their credentials
    # Each tenant provides their own service account
    tenant1_sa = {
        "type": "service_account",
        "project_id": "tenant1-project",
        "private_key_id": "key123",
        "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
        "client_email": "analytics@tenant1-project.iam.gserviceaccount.com",
        # ... rest of service account JSON
    }
    
    analytics_service.register_tenant("tenant-001", tenant1_sa)
    
    # 4. Now tenants can query their own data
    # The service ensures complete isolation
    
    print("""
    Multi-tenant setup complete!
    
    Each tenant:
    1. Provides their own Google Analytics service account
    2. Can only access their own Analytics properties
    3. Has complete data isolation
    
    No shared credentials or cross-tenant access possible!
    """)


if __name__ == "__main__":
    main()