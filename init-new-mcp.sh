#!/bin/bash

# Initialize a new MCP server from this template
# Usage: ./init-new-mcp.sh SERVICE_NAME
# Example: ./init-new-mcp.sh salesforce

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if service name provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: Service name required${NC}"
    echo "Usage: $0 SERVICE_NAME"
    echo "Example: $0 salesforce"
    exit 1
fi

SERVICE_NAME=$1
SERVICE_NAME_LOWER=$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]')
SERVICE_NAME_UPPER=$(echo "$SERVICE_NAME" | tr '[:lower:]' '[:upper:]')
SERVICE_NAME_TITLE=$(echo "$SERVICE_NAME" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')

echo -e "${BLUE}Initializing new MCP server: ${SERVICE_NAME_TITLE}${NC}"
echo ""

# Confirm before proceeding
echo -e "${YELLOW}This will transform the current repository into:${NC}"
echo "  - Package name: ${SERVICE_NAME_LOWER}_mcp"
echo "  - Service name: ${SERVICE_NAME_TITLE} MCP Server"
echo "  - Command name: ${SERVICE_NAME_LOWER}-mcp"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 1
fi

echo ""
echo -e "${GREEN}Step 1: Updating package structure${NC}"

# Rename main package directory
if [ -d "analytics_mcp" ]; then
    mv analytics_mcp "${SERVICE_NAME_LOWER}_mcp"
    echo "  ✓ Renamed package directory"
fi

# Update Python imports
echo -e "${GREEN}Step 2: Updating imports${NC}"
find . -name "*.py" -type f -exec sed -i.bak "s/analytics_mcp/${SERVICE_NAME_LOWER}_mcp/g" {} +
find . -name "*.py" -type f -exec sed -i.bak "s/Google Analytics/${SERVICE_NAME_TITLE}/g" {} +
echo "  ✓ Updated Python imports"

# Update pyproject.toml
echo -e "${GREEN}Step 3: Updating pyproject.toml${NC}"
sed -i.bak "s/google-analytics-mcp/${SERVICE_NAME_LOWER}-mcp/g" pyproject.toml
sed -i.bak "s/analytics_mcp/${SERVICE_NAME_LOWER}_mcp/g" pyproject.toml
echo "  ✓ Updated package configuration"

# Update Dockerfile
echo -e "${GREEN}Step 4: Updating Dockerfile${NC}"
sed -i.bak "s/analytics_mcp/${SERVICE_NAME_LOWER}_mcp/g" Dockerfile
echo "  ✓ Updated Dockerfile"

# Update documentation
echo -e "${GREEN}Step 5: Updating documentation${NC}"
sed -i.bak "s/Google Analytics/${SERVICE_NAME_TITLE}/g" README.md
sed -i.bak "s/analytics/${SERVICE_NAME_LOWER}/g" README.md
sed -i.bak "s/Google Analytics/${SERVICE_NAME_TITLE}/g" CLAUDE.md
sed -i.bak "s/analytics_mcp/${SERVICE_NAME_LOWER}_mcp/g" CLAUDE.md
sed -i.bak "s/google-analytics-mcp/${SERVICE_NAME_LOWER}-mcp/g" README.md
sed -i.bak "s/google-analytics-mcp/${SERVICE_NAME_LOWER}-mcp/g" CLAUDE.md
echo "  ✓ Updated documentation"

# Update server files
echo -e "${GREEN}Step 6: Updating server configuration${NC}"
sed -i.bak "s/Google Analytics MCP Server/${SERVICE_NAME_TITLE} MCP Server/g" simple_server.py
sed -i.bak "s/analytics_mcp/${SERVICE_NAME_LOWER}_mcp/g" simple_server.py
sed -i.bak "s/google-analytics-mcp/${SERVICE_NAME_LOWER}-mcp/g" docker-compose.yml
sed -i.bak "s/analytics_mcp/${SERVICE_NAME_LOWER}_mcp/g" docker-compose.yml
sed -i.bak "s/google-analytics-mcp/${SERVICE_NAME_LOWER}-mcp/g" Makefile
sed -i.bak "s/analytics_mcp/${SERVICE_NAME_LOWER}_mcp/g" Makefile
sed -i.bak "s/google-analytics-mcp/${SERVICE_NAME_LOWER}-mcp/g" .env.example
sed -i.bak "s/google-analytics-mcp/${SERVICE_NAME_LOWER}-mcp/g" .github/workflows/*.yml
echo "  ✓ Updated server and configuration files"

# Clean up backup files
echo -e "${GREEN}Step 7: Cleaning up${NC}"
find . -name "*.bak" -type f -delete
echo "  ✓ Removed backup files"

# Create a template tool file
echo -e "${GREEN}Step 8: Creating template tool${NC}"
cat > "${SERVICE_NAME_LOWER}_mcp/tools/multitenant.py" << EOF
"""Multi-tenant tools for ${SERVICE_NAME_TITLE}."""

import base64
import json
import logging
from typing import Any, Dict, List

from ${SERVICE_NAME_LOWER}_mcp.coordinator import mcp

logger = logging.getLogger(__name__)


def _decode_credentials(tenant_credentials: str) -> Dict[str, Any]:
    """Decode and validate tenant credentials."""
    try:
        cred_json = base64.b64decode(tenant_credentials).decode('utf-8')
        creds = json.loads(cred_json)
        
        # TODO: Validate required fields for ${SERVICE_NAME_TITLE}
        # Example: required = ['api_key', 'api_secret']
        
        return creds
    except Exception as e:
        logger.error(f"Failed to decode credentials: {e}")
        raise ValueError("Invalid credentials format")


@mcp.tool()
async def example_tool_mt(
    tenant_id: str,
    tenant_credentials: str,
    parameter: str
) -> Dict[str, Any]:
    """Example ${SERVICE_NAME_TITLE} tool with multi-tenant support.
    
    Args:
        tenant_id: Unique identifier for the tenant
        tenant_credentials: Base64-encoded credentials JSON
        parameter: Example parameter
    
    Returns:
        Example response
    """
    credentials = _decode_credentials(tenant_credentials)
    
    # TODO: Implement your ${SERVICE_NAME_TITLE} logic here
    # Example:
    # client = create_${SERVICE_NAME_LOWER}_client(credentials)
    # result = await client.do_something(parameter)
    
    return {
        "status": "success",
        "message": f"Executed example_tool_mt for tenant {tenant_id}",
        "parameter": parameter
    }


# TODO: Add more tools for ${SERVICE_NAME_TITLE}
# @mcp.tool()
# async def another_tool_mt(...):
#     ...
EOF
echo "  ✓ Created template tool file"

# Create TODO file
echo -e "${GREEN}Step 9: Creating TODO list${NC}"
cat > "TODO_${SERVICE_NAME_UPPER}.md" << EOF
# TODO: Complete ${SERVICE_NAME_TITLE} MCP Server Setup

## 1. Update Dependencies

Edit \`pyproject.toml\`:
- [ ] Remove Google Analytics dependencies
- [ ] Add ${SERVICE_NAME_TITLE} SDK/client library
- [ ] Update version and description

## 2. Implement Tools

Edit \`${SERVICE_NAME_LOWER}_mcp/tools/multitenant.py\`:
- [ ] Define credential structure for ${SERVICE_NAME_TITLE}
- [ ] Implement credential validation
- [ ] Create ${SERVICE_NAME_TITLE} client initialization
- [ ] Implement actual tools (replace example_tool_mt)

## 3. Update Documentation

Edit \`README.md\`:
- [ ] Update service description
- [ ] Document available tools
- [ ] Add ${SERVICE_NAME_TITLE}-specific examples
- [ ] Update credential preparation instructions

Edit \`CLAUDE.md\`:
- [ ] Update tool descriptions
- [ ] Add ${SERVICE_NAME_TITLE}-specific guidance

## 4. Testing

- [ ] Test credential encoding/decoding
- [ ] Test each tool with real ${SERVICE_NAME_TITLE} credentials
- [ ] Test error handling
- [ ] Run local server and verify endpoints

## 5. Clean Up

- [ ] Remove this TODO file when complete
- [ ] Remove Google Analytics specific files if any remain
- [ ] Update .gitignore if needed

## 6. Deploy

- [ ] Test deployment with \`quick-deploy.sh\`
- [ ] Verify Cloud Run deployment works
- [ ] Test with ADK integration
EOF
echo "  ✓ Created TODO list"

echo ""
echo -e "${GREEN}✅ Initialization complete!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Review ${YELLOW}TODO_${SERVICE_NAME_UPPER}.md${NC} for remaining tasks"
echo "2. Install ${SERVICE_NAME_TITLE} dependencies in pyproject.toml"
echo "3. Implement your tools in ${SERVICE_NAME_LOWER}_mcp/tools/multitenant.py"
echo "4. Test locally with: python simple_server.py"
echo "5. Deploy with: ./quick-deploy.sh YOUR_PROJECT_ID us-central1"
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"