# Creating a New MCP Server with Claude Code

This guide walks you through creating a new MCP server using this template with Claude Code's assistance. Following these steps, you can typically complete the entire process in 30-60 minutes.

## Steps to Create a New MCP Server

### 1. **Initial Setup**
```bash
# Clone the template repository
git clone https://github.com/KEN-E-AI/google-analytics-mcp.git mcp-[servicename]
cd mcp-[servicename]

# Remove git history and initialize new repo
rm -rf .git
git init

# Run the initialization script
./init-new-mcp.sh [servicename]
```

### 2. **Review the Generated TODO File**
```bash
# Open the TODO file that was created
cat TODO_[SERVICENAME].md
```
This file contains a checklist of all remaining tasks specific to your service.

### 3. **Tell Claude Code About Your Service**
Provide Claude Code with:
- The service/API you're integrating (e.g., "Stripe payment processing")
- What tools you need (e.g., "create payments, refunds, list transactions")
- The authentication method (API keys, OAuth, etc.)
- Any specific requirements or constraints

Example prompt:
```
I'm creating an MCP server for Stripe payment processing. I need tools for:
- Creating payment intents
- Processing refunds  
- Listing transactions
- Getting customer details

Stripe uses API keys for authentication. Please help me implement these tools with multi-tenant support.
```

### 4. **Update Dependencies**
Claude Code will help you:
- Edit `pyproject.toml` to add your service's SDK
- Remove Google Analytics dependencies
- Update package metadata

### 5. **Implement the Tools**
Claude Code will:
- Create tool implementations in `[servicename]_mcp/tools/multitenant.py`
- Define the credential structure
- Implement proper error handling
- Add all requested tools with multi-tenant support

### 6. **Update Documentation**
Ask Claude Code to:
- Update README.md with your service-specific information
- Document the credential format
- Add usage examples
- Update CLAUDE.md with service-specific guidance

### 7. **Test Locally**
```bash
# Install dependencies
pip install -e .

# Run the server
python simple_server.py

# In another terminal, test the health endpoint
curl http://localhost:8080/health
```

### 8. **Test with Real Credentials**
Claude Code can help create a test script:
```python
# Ask Claude Code to create a test script that:
# - Encodes credentials properly
# - Tests each tool
# - Handles errors gracefully
```

### 9. **Deploy to Cloud Run**
```bash
# Set up your Google Cloud project
export PROJECT_ID=your-project-id
export REGION=us-central1

# Deploy using the provided script
./quick-deploy.sh $PROJECT_ID $REGION
```

### 10. **Set Up CI/CD**
Configure GitHub repository:
1. Go to Repository Settings → Secrets
2. Add these secrets:
   - `GCP_PROJECT_ID`: Your Google Cloud project ID
   - `GCP_SA_KEY`: Service account key JSON (base64 encoded)

### 11. **Final Testing**
Test the deployed service:
```bash
# Get the Cloud Run URL
SERVICE_URL=$(gcloud run services describe mcp-[servicename] --region=$REGION --format='value(status.url)')

# Test the deployment
curl $SERVICE_URL/health
```

## Tips for Working with Claude Code

### Be Specific About Requirements
- Provide API documentation links
- Show example API responses
- Specify error handling needs

### Iterative Development
- Start with 1-2 core tools
- Test thoroughly
- Add more tools incrementally

### Example Prompts for Claude Code

**For Implementation:**
```
"Please implement the create_payment_mt tool for Stripe. Here's the API docs: [link]. 
The tool should accept amount, currency, and description parameters."
```

**For Testing:**
```
"Create a comprehensive test script that tests all the Stripe tools with mock credentials 
and shows how to handle common errors."
```

**For Documentation:**
```
"Update the README.md to reflect the Stripe MCP server, including examples of how to 
encode Stripe API keys and use each tool."
```

### Common Issues Claude Code Can Help With

1. **Credential Structure**: "Help me define the credential JSON structure for [service]"
2. **Error Handling**: "Add proper error handling for rate limits and invalid credentials"
3. **Testing**: "Create unit tests for the credential decoding function"
4. **Examples**: "Create example scripts showing how to use each tool"

## Quick Reference Commands

### Development Workflow
```bash
# Run all checks before committing
make check

# Test with Docker
make docker-run

# View logs during development
docker-compose logs -f

# Clean and rebuild
make clean
make install
```

### Debugging Tips
```bash
# Check what tools are available
curl http://localhost:8080/

# Test a specific tool
curl -X POST http://localhost:8080/ \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "your_tool_mt",
    "params": {
      "tenant_id": "test",
      "tenant_credentials": "base64_encoded_creds",
      ...
    },
    "id": 1
  }'
```

## Final Checklist

- [ ] All tools implemented and tested
- [ ] Documentation updated (README, CLAUDE.md)
- [ ] Local testing passed
- [ ] Deployed to Cloud Run
- [ ] CI/CD configured
- [ ] Integration tested with ADK/client
- [ ] Remove TODO file
- [ ] Create initial release tag

## Common Patterns by Service Type

### API Key Services (Stripe, SendGrid, etc.)
```python
def _decode_credentials(tenant_credentials: str) -> Dict[str, str]:
    creds = json.loads(base64.b64decode(tenant_credentials))
    return {
        "api_key": creds["api_key"],
        "api_secret": creds.get("api_secret")  # If needed
    }
```

### OAuth Services (Salesforce, Google, etc.)
```python
def _decode_credentials(tenant_credentials: str) -> Dict[str, str]:
    creds = json.loads(base64.b64decode(tenant_credentials))
    return {
        "client_id": creds["client_id"],
        "client_secret": creds["client_secret"],
        "refresh_token": creds["refresh_token"]
    }
```

### Database Services (PostgreSQL, MongoDB, etc.)
```python
def _decode_credentials(tenant_credentials: str) -> Dict[str, str]:
    creds = json.loads(base64.b64decode(tenant_credentials))
    return {
        "host": creds["host"],
        "port": creds["port"],
        "database": creds["database"],
        "username": creds["username"],
        "password": creds["password"]
    }
```

## Getting Help

If you encounter issues:
1. Check the logs: `docker-compose logs`
2. Verify credentials are properly base64 encoded
3. Test tools individually before integration
4. Ask Claude Code for debugging assistance

With Claude Code's assistance and this template, you'll have a production-ready MCP server deployed and running quickly!