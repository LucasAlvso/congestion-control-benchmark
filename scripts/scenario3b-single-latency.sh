#!/bin/bash

# Scenario 3b: Single client with variable latency (with captures)

set -e

SCENARIO_NAME="scenario3b-single-latency"

echo "Running Scenario 3b: Single client with variable latency (with captures)"

# Generate test file if needed
./scripts/generate-test-file.sh 200MB

# Start server and client containers (export SCENARIO so containers receive it via docker-compose)
SCENARIO="$SCENARIO_NAME" docker-compose -f docker/docker-compose.yml up --build -d server client1
sleep 3

# Ensure server storage and logs are clean for this scenario
docker exec tcp-server /bin/sh -c "rm -rf /root/files/* /root/logs/${SCENARIO_NAME} || true"

# Start captures
docker exec tcp-server /root/scripts/manage_capture.sh start "$SCENARIO_NAME" server || true
sleep 0.2
docker exec tcp-client1 /root/scripts/manage_capture.sh start "$SCENARIO_NAME" client || true
sleep 0.2
# Ensure captures have time to initialize before starting the client transfer
sleep 0.5

# Apply variable latency and run client (with timeout guard to avoid indefinite hang)
# Use timeout inside the container; 900s (15min) should be sufficient for the transfer under emulation.
docker exec tcp-client1 /bin/sh -c "tc qdisc del dev eth0 root 2>/dev/null || true; for i in 1 2 3; do tc qdisc add dev eth0 root netem delay 12ms 2ms distribution normal && break || sleep 1; done && timeout 1200s sh -c \"echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs\""

# Stop captures
docker exec tcp-client1 /root/scripts/manage_capture.sh stop "$SCENARIO_NAME" client || true
docker exec tcp-server /root/scripts/manage_capture.sh stop "$SCENARIO_NAME" server || true

# Do not consolidate logs to results — tests will use the files under the shared logs mount.
# Logs are already available under ./logs on the host via the shared volume.

# Cleanup
docker-compose -f docker/docker-compose.yml down

echo "Scenario 3b completed."
