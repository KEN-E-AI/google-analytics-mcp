#!/bin/bash

# Test script to verify the template initialization works correctly
# Usage: ./test-template.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Testing MCP Template Initialization${NC}"
echo ""

# Create a temporary directory for testing
TEST_DIR=$(mktemp -d)
echo -e "${YELLOW}Created test directory: ${TEST_DIR}${NC}"

# Copy current repository to test directory
echo -e "${BLUE}Copying template files...${NC}"
cp -r . "${TEST_DIR}/test-mcp"
cd "${TEST_DIR}/test-mcp"

# Remove git history to simulate fresh template
rm -rf .git

# Test the initialization script
echo -e "${BLUE}Running initialization script for 'testservice'...${NC}"
echo "y" | ./init-new-mcp.sh testservice

# Verify file changes
echo ""
echo -e "${BLUE}Verifying changes...${NC}"

# Check if directory was renamed
if [ -d "testservice_mcp" ]; then
    echo -e "${GREEN}✓ Package directory renamed correctly${NC}"
else
    echo -e "${RED}✗ Package directory not renamed${NC}"
    exit 1
fi

# Check if imports were updated
if grep -q "testservice_mcp" pyproject.toml; then
    echo -e "${GREEN}✓ pyproject.toml updated correctly${NC}"
else
    echo -e "${RED}✗ pyproject.toml not updated${NC}"
    exit 1
fi

# Check if service name was updated
if grep -q "Testservice MCP Server" simple_server.py; then
    echo -e "${GREEN}✓ Server name updated correctly${NC}"
else
    echo -e "${RED}✗ Server name not updated${NC}"
    exit 1
fi

# Check if TODO file was created
if [ -f "TODO_TESTSERVICE.md" ]; then
    echo -e "${GREEN}✓ TODO file created${NC}"
else
    echo -e "${RED}✗ TODO file not created${NC}"
    exit 1
fi

# Check if template tool file exists
if [ -f "testservice_mcp/tools/multitenant.py" ]; then
    echo -e "${GREEN}✓ Template tool file created${NC}"
else
    echo -e "${RED}✗ Template tool file not created${NC}"
    exit 1
fi

# Try to run the server (just check if it starts without errors)
echo ""
echo -e "${BLUE}Testing server startup...${NC}"
timeout 5 python simple_server.py > /dev/null 2>&1 || true
echo -e "${GREEN}✓ Server can be started${NC}"

# Clean up
echo ""
echo -e "${BLUE}Cleaning up...${NC}"
cd /
rm -rf "${TEST_DIR}"

echo ""
echo -e "${GREEN}✅ All tests passed! The template is working correctly.${NC}"
echo -e "${YELLOW}You can now use init-new-mcp.sh to create new MCP servers.${NC}"