#!/bin/bash
set -e

echo "=== Running Security Scans with Dockerfile.test ==="

# Build test image if not already built
echo "Building test image..."
docker build -f Dockerfile.test -t gamecon-test . || echo "Image already exists"

# Run security scans in container and copy results back
echo "Creating container for security scans..."
CONTAINER_ID=$(docker create gamecon-test sh -c "
    echo 'Installing security tools...' &&
    pip install --no-cache-dir bandit &&
    
    echo 'Running Bandit security scan...' &&
    bandit -r app/ -f json -o bandit-report.json || echo 'Bandit scan completed' &&
    bandit -r app/ || echo 'Bandit scan completed'
")

echo "Starting container for security scans..."
docker start -a $CONTAINER_ID

echo "Copying security reports back..."
docker cp $CONTAINER_ID:/app/bandit-report.json . || echo "No bandit report to copy"

echo "Cleaning up container..."
docker rm $CONTAINER_ID

echo "Security scan reports:"
ls -la *-report.json || echo "No report files found"

# Show report summary if it exists
if [ -f "bandit-report.json" ]; then
    echo "✓ Bandit security report generated"
    echo "Bandit report size: $(ls -lh bandit-report.json | awk '{print $5}')"
else
    echo "⚠ Bandit report not found"
fi

echo "=== Security Scans Complete ==="