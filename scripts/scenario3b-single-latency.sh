#!/bin/bash

# Scenario 3b: Single client with variable latency

set -e

SCENARIO_NAME="scenario3b-single-latency"
RESULTS_DIR="./results/$SCENARIO_NAME"
mkdir -p $RESULTS_DIR

echo "Running Scenario 3b: Single client with variable latency"

# Generate test file if needed
./scripts/generate-test-file.sh 200MB

# Start server
docker-compose -f docker/docker-compose.yml up --build -d server
sleep 3

# Run client with variable latency applied
docker-compose -f docker/docker-compose.yml run --rm --cap-add=NET_ADMIN client1 bash -c "
    tc qdisc add dev eth0 root netem delay 50ms 20ms distribution normal
    echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs
"

# Copy logs
docker cp tcp-server:/root/logs $RESULTS_DIR/server_logs
docker cp tcp-client1:/root/logs $RESULTS_DIR/client_logs 2>/dev/null || true

# Cleanup
docker-compose -f docker/docker-compose.yml down

echo "Scenario 3b completed. Results in $RESULTS_DIR"
