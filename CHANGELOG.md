# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Multi-tenant support for all Google Analytics tools
- Cloud Run deployment scripts and configuration
- Comprehensive template structure for creating new MCP servers
- GitHub Actions workflows for CI/CD
- Docker Compose configuration for local development
- Makefile for common development tasks
- Template initialization script (`init-new-mcp.sh`)

### Changed
- Refactored server implementation to use FastAPI for better HTTP/SSE support
- Updated all tools to support tenant credential injection
- Improved error handling and logging

### Security
- Implemented secure credential handling with base64 encoding
- Added tenant isolation to prevent cross-tenant data access
- No credential storage - all credentials provided per request

## [0.1.0] - 2024-01-XX

### Added
- Initial release with Google Analytics Data API v1 support
- Core reporting tools: `run_report`, `run_realtime_report`
- Account management tools: `get_account_summaries`, `get_property_details`
- Basic MCP server implementation with stdio transport

[Unreleased]: https://github.com/your-org/google-analytics-mcp/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/your-org/google-analytics-mcp/releases/tag/v0.1.0