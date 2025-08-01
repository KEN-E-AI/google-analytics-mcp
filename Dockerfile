# Use Python 3.11 slim image with explicit platform
FROM --platform=linux/amd64 python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies directly
RUN pip install --no-cache-dir \
    google-analytics-data==0.18.19 \
    google-analytics-admin==0.24.1 \
    google-auth~=2.40 \
    'mcp[cli]>=1.2.0' \
    httpx>=0.28.1 \
    fastapi \
    uvicorn[standard]

# Copy application code
COPY analytics_mcp/ ./analytics_mcp/
COPY simple_server.py ./

# Create non-root user for security
RUN useradd -m -u 1000 mcp && chown -R mcp:mcp /app
USER mcp

# Expose port (Cloud Run will override this)
EXPOSE 8080

# Set environment variables
ENV PORT=8080
ENV PYTHONUNBUFFERED=1
ENV UVICORN_PORT=8080
ENV UVICORN_HOST=0.0.0.0
ENV PYTHONPATH=/app

# Run the simple server
CMD ["python", "simple_server.py"]