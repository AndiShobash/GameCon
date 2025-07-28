#!/bin/bash
set -e

echo "=== Starting SonarQube Analysis ==="

# Check required environment variables
if [ -z "$SONAR_HOST_URL" ] || [ -z "$SONAR_TOKEN" ]; then
    echo "Error: SONAR_HOST_URL and SONAR_TOKEN environment variables are required"
    exit 1
fi

echo "Running SonarQube analysis with Java..."
echo "Java version:"
java -version

echo "Current workspace:"
pwd
ls -la

echo "App folder contents:"
ls -la app/

echo "Coverage file:"
if [ -f "coverage.xml" ]; then
    echo "coverage.xml found"
    ls -la coverage.xml
else
    echo "Warning: coverage.xml not found"
fi

echo "Downloading SonarQube Scanner..."
# Download and extract SonarQube Scanner using curl
SCANNER_VERSION="6.2.1.4610"
SCANNER_URL="https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SCANNER_VERSION}-linux-x64.zip"

curl -sL "$SCANNER_URL" -o sonar-scanner.zip
unzip -q sonar-scanner.zip

echo "SonarQube Scanner downloaded and extracted"

echo "Running SonarQube analysis..."
./sonar-scanner-${SCANNER_VERSION}-linux-x64/bin/sonar-scanner \
    -Dsonar.projectKey=gamecon-app \
    -Dsonar.projectName="GameCon Application" \
    -Dsonar.projectVersion=1.0 \
    -Dsonar.sources=app \
    -Dsonar.host.url="$SONAR_HOST_URL" \
    -Dsonar.token="$SONAR_TOKEN" \
    -Dsonar.projectBaseDir=. \
    -Dsonar.java.binaries=.

echo "SonarQube analysis complete!"
echo "Check dashboard: $SONAR_HOST_URL/dashboard?id=gamecon-app"

# Cleanup
echo "Cleaning up SonarQube Scanner files..."
rm -rf sonar-scanner.zip sonar-scanner-${SCANNER_VERSION}-linux-x64

echo "=== SonarQube Analysis Complete ==="