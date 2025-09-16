#!/bin/bash

# Scenario 2: Multiple clients, clean network

set -e

SCENARIO_NAME="scenario2-multiple-clean"
RESULTS_DIR="./results/$SCENARIO_NAME"
mkdir -p $RESULTS_DIR

echo "Running Scenario 2: Multiple clients, clean network"

# Generate test file if needed
./scripts/generate-test-file.sh 200MB

# Start server
docker-compose -f docker/docker-compose.yml up --build -d server
sleep 3

# Run 3 clients concurrently
docker-compose -f docker/docker-compose.yml run --rm -d --name temp-client1 client1 bash -c "
    echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs
" &

docker-compose -f docker/docker-compose.yml run --rm -d --name temp-client2 client2 bash -c "
    echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs
" &

docker-compose -f docker/docker-compose.yml run --rm -d --name temp-client3 client3 bash -c "
    echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs
" &

# Wait for all clients to complete
wait

# Copy logs
docker cp tcp-server:/root/logs $RESULTS_DIR/server_logs
docker cp temp-client1:/root/logs $RESULTS_DIR/client1_logs 2>/dev/null || true
docker cp temp-client2:/root/logs $RESULTS_DIR/client2_logs 2>/dev/null || true
docker cp temp-client3:/root/logs $RESULTS_DIR/client3_logs 2>/dev/null || true

# Cleanup
docker-compose -f docker/docker-compose.yml down

echo "Scenario 2 completed. Results in $RESULTS_DIR"
