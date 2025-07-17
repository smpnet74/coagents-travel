# Backend Dockerfile for CoAgents Travel
# Single-stage build for reliability

FROM python:3.12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Poetry
RUN pip install poetry

# Create non-root user
RUN useradd --create-home --shell /bin/bash app

# Set work directory
WORKDIR /app

# Copy dependency files
COPY pyproject.toml poetry.lock* ./

# Configure poetry and install dependencies
RUN poetry config virtualenvs.in-project true && \
    poetry lock && \
    poetry install --no-root

# Copy application code
COPY . .

# Change ownership to app user
RUN chown -R app:app /app

# Switch to non-root user
USER app

# Ensure poetry uses the project venv for this user
RUN poetry config virtualenvs.in-project true

# Add the virtual environment to PATH
ENV PATH="/app/.venv/bin:$PATH"

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/docs || exit 1

# Start the application directly with uvicorn since PATH includes venv
CMD ["uvicorn", "travel.demo:app", "--host", "0.0.0.0", "--port", "8000"]