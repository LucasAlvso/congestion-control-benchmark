#!/bin/bash

# Scenario 4b: Multiple clients with variable latency

set -e

SCENARIO_NAME="scenario4b-multiple-latency"
RESULTS_DIR="./results/$SCENARIO_NAME"
mkdir -p $RESULTS_DIR

echo "Running Scenario 4b: Multiple clients with variable latency"

# Generate test file if needed
./scripts/generate-test-file.sh 200MB

# Start server
docker-compose -f docker/docker-compose.yml up --build -d server
sleep 3

# Run 3 clients concurrently with variable latency
docker-compose -f docker/docker-compose.yml run --rm -d --name temp-client1 --cap-add=NET_ADMIN client1 bash -c "
    tc qdisc add dev eth0 root netem delay 50ms 20ms distribution normal
    echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs
" &

docker-compose -f docker/docker-compose.yml run --rm -d --name temp-client2 --cap-add=NET_ADMIN client2 bash -c "
    tc qdisc add dev eth0 root netem delay 50ms 20ms distribution normal
    echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs
" &

docker-compose -f docker/docker-compose.yml run --rm -d --name temp-client3 --cap-add=NET_ADMIN client3 bash -c "
    tc qdisc add dev eth0 root netem delay 50ms 20ms distribution normal
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

echo "Scenario 4b completed. Results in $RESULTS_DIR"
