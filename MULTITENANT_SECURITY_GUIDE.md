# Multi-Tenant Security Guide

## Overview

This guide covers security best practices for deploying the Google Analytics MCP server in a multi-tenant environment where each tenant provides their own credentials.

## Security Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Tenant A   │     │  Tenant B   │     │  Tenant C   │
│  Creds: SA1 │     │  Creds: SA2 │     │  Creds: SA3 │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       │  HTTPS + Auth     │  HTTPS + Auth     │  HTTPS + Auth
       ▼                   ▼                   ▼
┌────────────────────────────────────────────────────────┐
│                   MCP Server (Cloud Run)                │
│  - No persistent credentials                            │
│  - Credentials used only for request duration          │
│  - Complete isolation between requests                 │
└────────────────────────────────────────────────────────┘
       │                   │                   │
       ▼                   ▼                   ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  GA Account │     │  GA Account │     │  GA Account │
│   Tenant A  │     │   Tenant B  │     │   Tenant C  │
└─────────────┘     └─────────────┘     └─────────────┘
```

## Implementation Security Measures

### 1. Credential Handling

```python
# SECURE: Credentials passed per request, never stored
@mcp.tool()
async def run_report_mt(
    tenant_id: str,
    tenant_credentials: str,  # Base64 encoded, encrypted in transit
    property_id: str,
    # ... other params
):
    # Decode and use immediately
    credentials = _decode_credentials(tenant_credentials)
    
    # Create client with tenant's credentials
    client = create_client(credentials)
    
    # Credentials go out of scope after request
    # Python garbage collection ensures cleanup
```

### 2. Transport Security

**Always use HTTPS:**
- Cloud Run provides automatic TLS termination
- Enforces HTTPS-only access
- Certificates managed by Google

**Additional headers:**
```python
# In your ADK client
headers = {
    "Authorization": f"Bearer {auth_token}",
    "X-Tenant-ID": tenant_id,
    "X-Request-ID": unique_request_id  # For audit trail
}
```

### 3. Authentication Layers

**Option A: API Key per Tenant**
```python
# Cloud Run environment variable
TENANT_API_KEYS = {
    "tenant-001": "encrypted_key_1",
    "tenant-002": "encrypted_key_2"
}

# Validate in MCP server
def validate_tenant_access(tenant_id: str, api_key: str):
    expected = decrypt(TENANT_API_KEYS.get(tenant_id))
    return hmac.compare_digest(api_key, expected)
```

**Option B: JWT with Tenant Claims**
```python
# JWT payload
{
    "sub": "user@tenant.com",
    "tenant_id": "tenant-001",
    "exp": 1234567890,
    "allowed_properties": ["properties/123", "properties/456"]
}
```

### 4. Request Validation

```python
# Add to multitenant.py
def validate_property_access(tenant_id: str, property_id: str, credentials: Any):
    """Ensure tenant can only access their own properties"""
    
    # Option 1: Validate by attempting access
    try:
        # This will fail if no access
        client = admin_v1beta.AnalyticsAdminServiceAsyncClient(credentials=credentials)
        await client.get_property(name=property_id)
    except PermissionDenied:
        raise ValueError(f"Tenant {tenant_id} cannot access {property_id}")
    
    # Option 2: Maintain allowlist (more complex but faster)
    # if property_id not in TENANT_PROPERTY_ALLOWLIST[tenant_id]:
    #     raise ValueError(f"Property {property_id} not allowed for tenant {tenant_id}")
```

### 5. Audit Logging

```python
import structlog

logger = structlog.get_logger()

@mcp.tool()
async def run_report_mt(tenant_id: str, tenant_credentials: str, property_id: str, ...):
    # Log access attempt (without credentials!)
    logger.info(
        "analytics_access",
        tenant_id=tenant_id,
        property_id=property_id,
        tool="run_report_mt",
        timestamp=datetime.utcnow().isoformat()
    )
    
    try:
        # ... perform operation ...
        
        logger.info(
            "analytics_success",
            tenant_id=tenant_id,
            property_id=property_id,
            rows_returned=len(result.get("rows", []))
        )
    except Exception as e:
        logger.error(
            "analytics_error",
            tenant_id=tenant_id,
            property_id=property_id,
            error=str(e)
        )
        raise
```

### 6. Rate Limiting

```python
# Using Cloud Run's built-in concurrency limits
# In cloudbuild.yaml or deployment:
gcloud run deploy analytics-mcp \
    --concurrency=100 \
    --max-instances=10

# Application-level rate limiting
from functools import lru_cache
import time

@lru_cache(maxsize=1000)
def check_rate_limit(tenant_id: str, window: int = 60) -> bool:
    """Simple in-memory rate limiter"""
    key = f"{tenant_id}:{int(time.time() / window)}"
    count = request_counts.get(key, 0)
    if count > MAX_REQUESTS_PER_MINUTE:
        return False
    request_counts[key] = count + 1
    return True
```

## Deployment Security Checklist

- [ ] **Cloud Run Configuration**
  - [ ] Remove `--allow-unauthenticated` for production
  - [ ] Set up Cloud Armor for DDoS protection
  - [ ] Configure VPC Service Controls if needed
  - [ ] Enable Cloud Audit Logs

- [ ] **Credential Security**
  - [ ] Never log credentials
  - [ ] Enforce HTTPS-only access
  - [ ] Implement credential format validation
  - [ ] Set up alerts for invalid credential attempts

- [ ] **Monitoring**
  - [ ] Set up alerts for unusual access patterns
  - [ ] Monitor for cross-tenant access attempts
  - [ ] Track credential validation failures
  - [ ] Set up usage quotas per tenant

- [ ] **Application Security**
  - [ ] Validate all inputs
  - [ ] Implement request timeouts
  - [ ] Handle errors without exposing details
  - [ ] Regular security updates

## Testing Security

```bash
# Test 1: Ensure tenant isolation
curl -X POST https://your-mcp-server/tool \
  -H "Authorization: Bearer tenant-A-token" \
  -d '{
    "tool": "run_report_mt",
    "tenant_id": "tenant-B",  # Should fail!
    "tenant_credentials": "...",
    "property_id": "properties/123"
  }'

# Test 2: Invalid credentials
curl -X POST https://your-mcp-server/tool \
  -H "Authorization: Bearer valid-token" \
  -d '{
    "tool": "run_report_mt",
    "tenant_id": "tenant-A",
    "tenant_credentials": "invalid-base64",
    "property_id": "properties/123"
  }'

# Test 3: Rate limiting
for i in {1..100}; do
  curl -X POST https://your-mcp-server/tool ...
done
```

## Emergency Procedures

1. **Suspected Credential Leak**
   - Immediately revoke the service account in Google Cloud Console
   - Alert the affected tenant
   - Review audit logs for unauthorized access

2. **Cross-Tenant Data Access**
   - Shut down the service immediately
   - Review all recent requests in logs
   - Identify and fix the vulnerability
   - Notify all affected tenants

3. **DDoS Attack**
   - Cloud Run will auto-scale within limits
   - Enable Cloud Armor if not already
   - Implement stricter rate limiting
   - Consider IP allowlisting for known tenants

## Summary

The multi-tenant architecture with credential injection provides strong security because:

1. **No Shared Credentials**: Each tenant uses their own Google Cloud service account
2. **No Credential Storage**: Credentials are never persisted on the server
3. **Complete Isolation**: Each request is independent with its own credentials
4. **Audit Trail**: Every access is logged with tenant identification
5. **Tenant Control**: Tenants can revoke access instantly via Google Cloud Console

This approach aligns with the principle of least privilege and gives tenants full control over their data access.