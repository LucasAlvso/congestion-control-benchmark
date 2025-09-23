#!/bin/bash

# Scenario 3a: Single client with packet loss (with captures)

set -e

SCENARIO_NAME="scenario3a-single-loss"

echo "Running Scenario 3a: Single client with packet loss (with captures)"

# Generate test file if needed
./scripts/generate-test-file.sh 200MB

# Start server and client containers (export SCENARIO so containers receive it via docker-compose)
SCENARIO="$SCENARIO_NAME" docker-compose -f docker/docker-compose.yml up --build -d server client1
sleep 3

# Ensure server storage and logs are clean for this scenario
docker exec tcp-server /bin/sh -c "rm -rf /root/files/* /root/logs/${SCENARIO_NAME} || true"

# Start captures
docker exec tcp-server /root/scripts/manage_capture.sh start "$SCENARIO_NAME" server || true
docker exec tcp-client1 /root/scripts/manage_capture.sh start "$SCENARIO_NAME" client || true
# Ensure captures have time to initialize before starting the client transfer
sleep 5

# Apply packet loss with retry and run client with timeout guard
# Apply netem on server as well for bidirectional emulation
docker exec tcp-server /bin/sh -c "for i in 1 2 3; do tc qdisc add dev eth0 root netem loss 5% && break || sleep 1; done"
docker exec tcp-client1 /bin/sh -c "for i in 1 2 3; do tc qdisc add dev eth0 root netem loss 5% && break || sleep 1; done && timeout 900s sh -c \"echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs\""

# Add buffer time before stopping captures to ensure all packets are captured
echo "Waiting additional time to ensure all packets are captured..."
sleep 3

# Stop captures
docker exec tcp-client1 /root/scripts/manage_capture.sh stop "$SCENARIO_NAME" client || true
docker exec tcp-server /root/scripts/manage_capture.sh stop "$SCENARIO_NAME" server || true

# Do not consolidate logs to results — tests will use the files under the shared logs mount.
# Logs are already available under ./logs on the host via the shared volume.

# Cleanup
docker-compose -f docker/docker-compose.yml down

echo "Scenario 3a completed."
