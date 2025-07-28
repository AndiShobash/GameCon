#!/bin/bash
set -e

echo "=== Starting Code Coverage Analysis (Docker Test Image) ==="

# Build the test image
echo "Building test Docker image..."
docker build -f Dockerfile.test -t gamecon-test .

# Run tests in container
echo "Running tests in container..."
docker run --rm \
    --name gamecon-test-runner \
    gamecon-test

# Get the container ID from the last run (alternative approach to get coverage file)
echo "Extracting coverage report..."
CONTAINER_ID=$(docker create gamecon-test)
docker cp $CONTAINER_ID:/app/coverage.xml . || echo "No coverage.xml found in container"
docker rm $CONTAINER_ID

# Verify coverage file
if [ -f "coverage.xml" ]; then
    echo "✓ Coverage report generated successfully"
    echo "Coverage file size: $(ls -lh coverage.xml | awk '{print $5}')"
    
    # Show coverage summary
    echo "Coverage report preview:"
    head -n 10 coverage.xml
else
    echo "✗ Coverage report not found"
    # Try alternative: run container with volume just for the output file
    echo "Attempting alternative approach to get coverage..."
    docker run --rm -v "$(pwd):/output" gamecon-test sh -c "
        python -m pytest tests/test_basic.py -v --cov=app --cov-report=xml --cov-report=term &&
        cp coverage.xml /output/ || echo 'Failed to copy coverage file'
    "
fi

echo "=== Code Coverage Analysis Complete ==="