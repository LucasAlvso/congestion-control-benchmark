#!/bin/bash

# Scenario 1: Single client, clean network with captures and graphing

set -e

SCENARIO_NAME="scenario1-single-clean"
RESULTS_DIR="./results/$SCENARIO_NAME"
mkdir -p "$RESULTS_DIR"

echo "Running Scenario 1: Single client, clean network (with captures)"

# Generate test file if needed
./scripts/generate-test-file.sh 200MB

# Start server and client containers so we can exec into them (client will be idle until we run command)
docker-compose -f docker/docker-compose.yml up --build -d server client1
sleep 3

# Start tcpdump captures inside server and client containers
docker exec tcp-server /root/scripts/manage_capture.sh start "$SCENARIO_NAME" server || true
docker exec tcp-client1 /root/scripts/manage_capture.sh start "$SCENARIO_NAME" client || true

# Run client upload (exec into existing client container)
docker exec tcp-client1 bash -c "echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs"

# Stop captures
docker exec tcp-client1 /root/scripts/manage_capture.sh stop "$SCENARIO_NAME" client || true
docker exec tcp-server /root/scripts/manage_capture.sh stop "$SCENARIO_NAME" server || true

# Generate graphs inside server container (server image has tshark/python)
docker exec tcp-server /root/scripts/generate_graphs.sh "$SCENARIO_NAME" || true

# Copy logs & graphs from containers (logs are also mounted to ../logs, but keep cp for compatibility)
mkdir -p "$RESULTS_DIR/server_logs" "$RESULTS_DIR/client_logs"
docker cp tcp-server:/root/logs "$RESULTS_DIR/server_logs" 2>/dev/null || true
docker cp tcp-client1:/root/logs "$RESULTS_DIR/client_logs" 2>/dev/null || true

# Cleanup
docker-compose -f docker/docker-compose.yml down

echo "Scenario 1 completed. Results in $RESULTS_DIR"
