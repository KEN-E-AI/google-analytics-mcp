.PHONY: help install test format lint type-check run docker-build docker-run deploy clean

# Default target
help:
	@echo "Available commands:"
	@echo "  make install      - Install dependencies"
	@echo "  make test        - Run tests"
	@echo "  make format      - Format code"
	@echo "  make lint        - Run linting"
	@echo "  make type-check  - Run type checking"
	@echo "  make run         - Run server locally"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-run  - Run Docker container"
	@echo "  make deploy      - Deploy to Cloud Run"
	@echo "  make clean       - Clean build artifacts"

# Install dependencies
install:
	pip install -e .
	pip install pytest pytest-asyncio pytest-cov nox ruff black isort mypy

# Run tests
test:
	pytest tests/ -v

# Run tests with coverage
test-coverage:
	pytest tests/ -v --cov=analytics_mcp --cov-report=html --cov-report=term

# Format code
format:
	black .
	isort .

# Run linting
lint:
	ruff check .
	black --check .
	isort --check-only .

# Run type checking
type-check:
	mypy analytics_mcp --ignore-missing-imports

# Run all checks
check: format lint type-check test

# Run server locally
run:
	python simple_server.py

# Build Docker image
docker-build:
	docker build --platform linux/amd64 -t google-analytics-mcp:latest .

# Run Docker container
docker-run:
	docker run -p 8080:8080 \
		-e PORT=8080 \
		-e DEBUG=true \
		google-analytics-mcp:latest

# Run with docker-compose
docker-compose-up:
	docker-compose up --build

# Deploy to Cloud Run (requires PROJECT_ID and REGION env vars)
deploy:
	@if [ -z "$(PROJECT_ID)" ]; then echo "Error: PROJECT_ID not set"; exit 1; fi
	@if [ -z "$(REGION)" ]; then echo "Error: REGION not set"; exit 1; fi
	./quick-deploy.sh $(PROJECT_ID) $(REGION)

# Clean build artifacts
clean:
	rm -rf build/ dist/ *.egg-info .coverage htmlcov/ .pytest_cache/
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type f -name "*.bak" -delete

# Initialize new MCP server from template
init-new-service:
	@if [ -z "$(SERVICE)" ]; then echo "Usage: make init-new-service SERVICE=servicename"; exit 1; fi
	./init-new-mcp.sh $(SERVICE)