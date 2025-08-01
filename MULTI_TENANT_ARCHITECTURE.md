# Multi-Tenant Architecture for Google Analytics MCP Server

## Overview

This document outlines strategies for deploying the Google Analytics MCP server in a multi-tenant environment while ensuring proper data isolation between tenants.

## Architecture Options

### Option 1: Shared Service with User Authentication (Recommended)

**How it works:**
- Single MCP server deployment
- Tenants provide their own Google credentials
- MCP server acts as a pass-through, using tenant-provided credentials

**Implementation:**
```python
# Modified MCP tool to accept credentials
@mcp.tool()
async def run_report_with_auth(
    property_id: str,
    credentials_json: str,  # Tenant provides their own credentials
    date_ranges: List[Dict[str, str]],
    dimensions: List[str],
    metrics: List[str]
):
    # Create client with tenant's credentials
    credentials = service_account.Credentials.from_service_account_info(
        json.loads(credentials_json),
        scopes=['https://www.googleapis.com/auth/analytics.readonly']
    )
    client = data_v1beta.BetaAnalyticsDataAsyncClient(credentials=credentials)
    # ... rest of implementation
```

**Pros:**
- Complete data isolation
- No service account management overhead
- Tenants control their own access
- Single deployment to maintain

**Cons:**
- Tenants must manage their own Google Cloud credentials
- Credentials passed through your system (encryption required)

### Option 2: Service Account per Tenant

**How it works:**
- Create a separate service account for each tenant
- Store mapping of tenant → service account
- MCP server selects appropriate service account based on tenant ID

**Implementation:**
```python
# Tenant-aware credential management
class TenantCredentialManager:
    def __init__(self):
        self.tenant_accounts = {
            "tenant1": "analytics-tenant1@project.iam.gserviceaccount.com",
            "tenant2": "analytics-tenant2@project.iam.gserviceaccount.com",
        }
    
    def get_credentials(self, tenant_id: str):
        sa_email = self.tenant_accounts.get(tenant_id)
        if not sa_email:
            raise ValueError(f"No service account for tenant {tenant_id}")
        
        # Use workload identity or key file
        return self._load_credentials(sa_email)

# Modified tool
@mcp.tool()
async def run_report_multi_tenant(
    tenant_id: str,
    property_id: str,
    # ... other parameters
):
    credentials = credential_manager.get_credentials(tenant_id)
    client = data_v1beta.BetaAnalyticsDataAsyncClient(credentials=credentials)
    # ... rest of implementation
```

**Pros:**
- Clear separation between tenants
- Centralized credential management
- Audit trail per service account

**Cons:**
- Service account proliferation
- Manual process to grant each SA access to Analytics
- Google Cloud quotas on service accounts (100 per project by default)

### Option 3: OAuth2 Flow with User Consent (Most Secure)

**How it works:**
- Implement OAuth2 flow for each tenant
- Users authorize your application to access their Analytics
- Store refresh tokens securely per tenant

**Implementation:**
```python
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import Flow

class OAuth2Manager:
    def __init__(self, client_config):
        self.client_config = client_config
        self.token_storage = SecureTokenStorage()  # Your secure storage
    
    def get_auth_url(self, tenant_id: str) -> str:
        flow = Flow.from_client_config(
            self.client_config,
            scopes=['https://www.googleapis.com/auth/analytics.readonly'],
            redirect_uri=f'https://your-app.com/oauth/callback/{tenant_id}'
        )
        auth_url, _ = flow.authorization_url(prompt='consent')
        return auth_url
    
    async def handle_callback(self, tenant_id: str, auth_code: str):
        flow = Flow.from_client_config(self.client_config, ...)
        flow.fetch_token(code=auth_code)
        
        # Store encrypted refresh token
        await self.token_storage.store(tenant_id, flow.credentials)
    
    async def get_credentials(self, tenant_id: str) -> Credentials:
        creds = await self.token_storage.get(tenant_id)
        if creds.expired:
            creds.refresh(Request())
            await self.token_storage.store(tenant_id, creds)
        return creds
```

**Pros:**
- Most secure - users explicitly grant access
- No service account management
- Follows Google's recommended practices
- Can be revoked by users

**Cons:**
- More complex implementation
- Requires UI for OAuth flow
- Token refresh management

### Option 4: Separate MCP Deployment per Tenant

**How it works:**
- Deploy separate Cloud Run service for each tenant
- Each deployment has its own service account
- Complete infrastructure isolation

**Deployment:**
```bash
# Deploy for each tenant
for TENANT in tenant1 tenant2 tenant3; do
  gcloud run deploy analytics-mcp-${TENANT} \
    --service-account analytics-${TENANT}@project.iam \
    --set-env-vars ALLOWED_PROPERTY_IDS=${TENANT_PROPERTY_IDS}
done
```

**Pros:**
- Complete isolation
- Can scale/configure per tenant
- Clear security boundaries

**Cons:**
- Higher operational overhead
- More expensive (multiple Cloud Run services)
- Complex routing required

## Recommended Architecture for ADK Integration

For ADK-based multi-tenant applications, I recommend **Option 1 (Shared Service with User Authentication)** with these enhancements:

### 1. Credential Injection Pattern

```python
# In your ADK agent
class TenantAwareAnalyticsAgent:
    def __init__(self, tenant_id: str, mcp_url: str):
        self.tenant_id = tenant_id
        self.mcp_client = MCPClient(mcp_url)
        
    async def query_analytics(self, query: str):
        # Get tenant's credentials from secure storage
        creds = await self.get_tenant_credentials(self.tenant_id)
        
        # Pass credentials with each request
        return await self.mcp_client.call_tool(
            "run_report",
            property_id=self.get_tenant_property_id(),
            credentials=creds,  # Encrypted in transit
            # ... other params
        )
```

### 2. Security Middleware

```python
# Add to MCP server
from fastapi import Security, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

security = HTTPBearer()

async def verify_tenant_token(
    credentials: HTTPAuthorizationCredentials = Security(security)
) -> str:
    """Verify JWT token and extract tenant_id"""
    try:
        payload = jwt.decode(credentials.credentials, PUBLIC_KEY)
        return payload["tenant_id"]
    except:
        raise HTTPException(status_code=401)

# Apply to endpoints
@app.post("/mcp/{tenant_id}/request")
async def handle_tenant_request(
    tenant_id: str,
    verified_tenant: str = Depends(verify_tenant_token)
):
    if tenant_id != verified_tenant:
        raise HTTPException(status_code=403)
    # Process request...
```

### 3. Deployment Configuration

```yaml
# Cloud Run configuration for multi-tenant
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: analytics-mcp-multitenant
spec:
  template:
    metadata:
      annotations:
        # Enable Cloud Armor for DDoS protection
        run.googleapis.com/cpu-throttling: "true"
    spec:
      containers:
      - image: gcr.io/project/analytics-mcp:latest
        env:
        - name: ENABLE_MULTI_TENANT
          value: "true"
        - name: REQUIRE_TENANT_AUTH
          value: "true"
        - name: CREDENTIAL_ENCRYPTION_KEY
          valueFrom:
            secretKeyRef:
              name: encryption-key
              key: key
```

## Security Best Practices

1. **Credential Handling**
   - Always encrypt credentials in transit and at rest
   - Use Google Secret Manager for storing sensitive data
   - Implement credential rotation

2. **Access Control**
   - Validate tenant ID in every request
   - Implement rate limiting per tenant
   - Log all access for audit purposes

3. **Data Isolation**
   - Never cache data across tenants
   - Validate property IDs belong to tenant
   - Implement query result filtering

4. **Network Security**
   - Use VPC Service Controls
   - Implement Cloud Armor rules
   - Enable Cloud Run authentication

## Implementation Checklist

- [ ] Choose architecture pattern based on requirements
- [ ] Implement tenant authentication/authorization
- [ ] Set up credential management system
- [ ] Add tenant validation to all MCP tools
- [ ] Implement audit logging
- [ ] Set up monitoring and alerting
- [ ] Document tenant onboarding process
- [ ] Test cross-tenant isolation
- [ ] Implement rate limiting
- [ ] Set up automated security scanning

## Example: Minimal Multi-Tenant Implementation

```python
# analytics_mcp/tools/multitenant.py
from typing import Dict, Any
import json
from google.oauth2 import service_account
from analytics_mcp.coordinator import mcp

# Tenant credential cache (use Redis/Memcache in production)
_credential_cache: Dict[str, Any] = {}

@mcp.tool()
async def run_report_multitenant(
    tenant_id: str,
    tenant_credentials: str,  # Base64 encoded service account JSON
    property_id: str,
    date_ranges: List[Dict[str, str]],
    dimensions: List[str],
    metrics: List[str]
) -> Dict[str, Any]:
    """Run a report with tenant-specific credentials."""
    
    # Decode and validate credentials
    try:
        cred_data = json.loads(base64.b64decode(tenant_credentials))
        credentials = service_account.Credentials.from_service_account_info(
            cred_data,
            scopes=['https://www.googleapis.com/auth/analytics.readonly']
        )
    except Exception as e:
        raise ValueError(f"Invalid credentials: {e}")
    
    # Validate property access (optional but recommended)
    # This could check against a whitelist of allowed properties per tenant
    
    # Create tenant-specific client
    client = data_v1beta.BetaAnalyticsDataAsyncClient(
        credentials=credentials,
        client_info=ClientInfo(user_agent=f"mcp-tenant-{tenant_id}")
    )
    
    # Execute report with tenant's credentials
    request = data_v1beta.RunReportRequest(
        property=construct_property_rn(property_id),
        dimensions=[data_v1beta.Dimension(name=d) for d in dimensions],
        metrics=[data_v1beta.Metric(name=m) for m in metrics],
        date_ranges=[data_v1beta.DateRange(**dr) for dr in date_ranges]
    )
    
    response = await client.run_report(request)
    return proto_to_dict(response)
```

## Conclusion

For most use cases, I recommend the **Shared Service with User Authentication** approach because it:
- Provides strong security through credential isolation
- Scales efficiently 
- Minimizes operational overhead
- Aligns with Google's security best practices

The key is ensuring that tenant credentials are never mixed and that each request is properly authenticated and authorized.