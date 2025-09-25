#!/bin/bash

# Scenario 1: Single client, clean network with captures and graphing

set -e

SCENARIO_NAME="scenario1-single-clean"

echo "Running Scenario 1: Single client, clean network (with captures)"

# Generate test file if needed
./scripts/generate-test-file.sh 200MB

# Start server and client containers so we can exec into them (client will be idle until we run command)
SCENARIO="$SCENARIO_NAME" docker-compose -f docker/docker-compose.yml up --build -d server client1
sleep 3

# Ensure server storage and logs are clean for this scenario
docker exec tcp-server /bin/sh -c "rm -rf /root/files/* /root/logs/${SCENARIO_NAME} || true"

# Start tcpdump captures inside server and client containers
docker exec tcp-server /root/scripts/manage_capture.sh start "$SCENARIO_NAME" server || true
docker exec tcp-client1 /root/scripts/manage_capture.sh start "$SCENARIO_NAME" client || true
# Ensure captures have time to initialize before starting the client transfer
sleep 5

# Write scenario marker files for logger metadata
docker exec tcp-server /bin/sh -c "mkdir -p /root/logs/${SCENARIO_NAME} && printf '%s\n' \"${SCENARIO_NAME}\" > /root/logs/${SCENARIO_NAME}/.scenario && printf '%s\n' tcp-server > /root/logs/${SCENARIO_NAME}/.container_name" 2>/dev/null || true
docker exec tcp-client1 /bin/sh -c "mkdir -p /root/logs/${SCENARIO_NAME} && printf '%s\n' \"${SCENARIO_NAME}\" > /root/logs/${SCENARIO_NAME}/.scenario && printf '%s\n' tcp-client1 > /root/logs/${SCENARIO_NAME}/.container_name" 2>/dev/null || true

# Run client upload (exec into existing client container) with timeout guard
docker exec tcp-client1 bash -c "timeout 900s bash -c \"echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs\""

# Wait until TCP transfers on port 8080 fully quiesce, to avoid stopping captures too early
TIMEOUT=900 CHECK_INTERVAL=3 STABLE_CYCLES=2 ./scripts/wait_transfers.sh 8080 tcp-client1

# Stop captures
docker exec tcp-client1 /root/scripts/manage_capture.sh stop "$SCENARIO_NAME" client || true
docker exec tcp-server /root/scripts/manage_capture.sh stop "$SCENARIO_NAME" server || true


# Do not consolidate logs to results — tests will use the files under the shared logs mount.
# Logs are already available under ./logs on the host via the shared volume.

# Cleanup
docker-compose -f docker/docker-compose.yml down

echo "Scenario 1 completed."
