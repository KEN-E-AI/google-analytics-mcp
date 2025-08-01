# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Code Formatting
- Format all Python files: `nox -s format`
- Uses Black formatter with 80 character line width

### Testing
- Run tests for all Python versions: `nox -s tests*`
- Run tests for specific Python version: `nox -s tests-3.11` (supports 3.9-3.13)
- Test command includes coverage reporting via `coverage run`
- Tests are located in `tests/` directory with pattern `*_test.py`

### Installation
- Install the package: `pip install -e .`
- Install with dev dependencies: `pip install -e .[dev]`

### Running Locally
- For local testing: `python simple_server.py`
- Server runs on http://localhost:8080
- Test with: `curl http://localhost:8080/health`

### Claude Desktop Compatibility

**IMPORTANT**: This MCP server is NOT compatible with Claude Desktop. Here's why:

1. **Transport Mismatch**: 
   - Claude Desktop expects stdio-based MCP servers
   - This server uses HTTP/JSON-RPC for Cloud Run deployment
   - These transport mechanisms are fundamentally incompatible

2. **Design Decision**:
   - Optimized for production use with ADK (Agent Development Kit)
   - Multi-tenant architecture requires HTTP for proper credential isolation
   - Cloud Run deployment requires HTTP endpoints

3. **Alternative Options**:
   - Use ADK for production integration
   - Test with curl commands directly
   - Use the original single-tenant stdio version for local testing only

## Architecture Overview

This is a multi-tenant MCP (Model Context Protocol) server for Google Analytics, deployed on Cloud Run.

### Core Components

1. **MCP Coordinator** (`analytics_mcp/coordinator.py`)
   - Creates singleton FastMCP instance
   - All tools register with `@mcp.tool` decorator

2. **HTTP Server** (`simple_server.py`)
   - FastAPI application for Cloud Run deployment
   - Handles JSON-RPC requests
   - Provides health check endpoint
   - Routes tool calls to appropriate handlers

3. **Tool Organization** (`analytics_mcp/tools/`)
   - **Standard Tools** (single-tenant, legacy):
     - `admin/info.py`: Account and property tools
     - `reporting/core.py`: Report generation
     - `reporting/realtime.py`: Real-time data
   - **Multi-Tenant Tools** (`multitenant.py`):
     - All tools with `_mt` suffix
     - Accept `tenant_id` and `tenant_credentials`
     - Complete tenant isolation

4. **Utilities** (`analytics_mcp/tools/utils.py`)
   - API client creation
   - Credential management
   - Property ID validation
   - Proto to dict conversion

### Multi-Tenant Pattern

```python
@mcp.tool()
async def tool_name_mt(
    tenant_id: str,              # Tenant identifier
    tenant_credentials: str,     # Base64 encoded service account JSON
    # ... other parameters
):
    credentials = _decode_credentials(tenant_credentials)
    client = create_client(credentials)
    # Tool implementation
```

### Deployment Architecture

1. **Container**: Dockerfile with Python 3.11, runs as non-root user
2. **Server**: FastAPI on port 8080 (Cloud Run requirement)
3. **Security**: No credential storage, TLS termination by Cloud Run
4. **Scaling**: Auto-scales based on traffic

### Adding New Tools

1. Add to `analytics_mcp/tools/multitenant.py`:
```python
@mcp.tool()
async def new_tool_mt(tenant_id: str, tenant_credentials: str, ...):
    # Implementation
```

2. Import in `simple_server.py` if in new module
3. Test locally before deploying

### Common Tasks

**Update dependencies**: Edit `pyproject.toml`, then rebuild
**Add new API**: Add to dependencies, update Dockerfile
**Debug issues**: Check logs in Cloud Console → Cloud Run → Logs
**Test locally**: `python simple_server.py` then use curl/httpie

### Important Files

- `simple_server.py` - Main HTTP server for Cloud Run
- `Dockerfile` - Container configuration
- `quick-deploy.sh` - Deployment script
- `analytics_mcp/tools/multitenant.py` - Multi-tenant tools
- `pyproject.toml` - Python dependencies