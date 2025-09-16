#!/bin/bash

# Scenario 1: Single client, clean network

set -e

SCENARIO_NAME="scenario1-single-clean"
RESULTS_DIR="./results/$SCENARIO_NAME"
mkdir -p $RESULTS_DIR

echo "Running Scenario 1: Single client, clean network"

# Generate test file if needed
./scripts/generate-test-file.sh 200MB

# Start server and single client
docker-compose -f docker/docker-compose.yml up --build -d server
sleep 3

# Run client with file upload
docker-compose -f docker/docker-compose.yml run --rm client1 bash -c "
    echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs
"

# Copy logs
docker cp tcp-server:/root/logs $RESULTS_DIR/server_logs
docker cp tcp-client1:/root/logs $RESULTS_DIR/client_logs 2>/dev/null || true

# Cleanup
docker-compose -f docker/docker-compose.yml down

echo "Scenario 1 completed. Results in $RESULTS_DIR"
