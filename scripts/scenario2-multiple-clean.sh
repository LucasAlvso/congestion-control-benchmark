#!/bin/bash

# Scenario 2: Multiple clients, clean network (with captures)

set -e

SCENARIO_NAME="scenario2-multiple-clean"

echo "Running Scenario 2: Multiple clients, clean network (with captures)"

# Generate test file if needed
./scripts/generate-test-file.sh 200MB

# Start server and client containers (export SCENARIO so containers receive it via docker-compose)
SCENARIO="$SCENARIO_NAME" docker-compose -f docker/docker-compose.yml up --build -d server client1 client2 client3

# Wait for containers to be fully ready
echo "Waiting for containers to be ready..."
sleep 5

# Ensure server storage and logs are clean for this scenario
docker exec tcp-server /bin/sh -c "rm -rf /root/files/* /root/logs/${SCENARIO_NAME} || true"

# Start captures on server and clients
docker exec tcp-server /root/scripts/manage_capture.sh start "$SCENARIO_NAME" server || true
docker exec tcp-client1 /root/scripts/manage_capture.sh start "$SCENARIO_NAME" client 1 || true
docker exec tcp-client2 /root/scripts/manage_capture.sh start "$SCENARIO_NAME" client 2 || true
docker exec tcp-client3 /root/scripts/manage_capture.sh start "$SCENARIO_NAME" client 3 || true

# Ensure captures have time to initialize before starting the client transfers
sleep 5

# Verify containers are ready and test files exist
echo "Verifying container readiness..."
docker exec tcp-client1 ls -la /root/test-files/ || echo "Client1 test-files not accessible"
docker exec tcp-client2 ls -la /root/test-files/ || echo "Client2 test-files not accessible"
docker exec tcp-client3 ls -la /root/test-files/ || echo "Client3 test-files not accessible"

# Run clients concurrently with simplified commands and proper paths
echo "Starting client transfers..."
docker exec -d tcp-client1 /bin/sh -c "cd /root && timeout 900s bash -c 'echo \"put test-files/test_200MB_scenario2-multiple-clean_client1.bin\" | ./client --host=server --port=8080 --log-dir=./logs'"
docker exec -d tcp-client2 /bin/sh -c "cd /root && timeout 900s bash -c 'echo \"put test-files/test_200MB_scenario2-multiple-clean_client2.bin\" | ./client --host=server --port=8080 --log-dir=./logs'"
docker exec -d tcp-client3 /bin/sh -c "cd /root && timeout 900s bash -c 'echo \"put test-files/test_200MB_scenario2-multiple-clean_client3.bin\" | ./client --host=server --port=8080 --log-dir=./logs'"

# Wait until TCP transfers on port 8080 fully quiesce, to avoid stopping captures too early
TIMEOUT=1200 CHECK_INTERVAL=3 STABLE_CYCLES=2 ./scripts/wait_transfers.sh 8080 tcp-client1 tcp-client2 tcp-client3

# Stop captures
docker exec tcp-client1 /root/scripts/manage_capture.sh stop "$SCENARIO_NAME" client 1 || true
docker exec tcp-client2 /root/scripts/manage_capture.sh stop "$SCENARIO_NAME" client 2 || true
docker exec tcp-client3 /root/scripts/manage_capture.sh stop "$SCENARIO_NAME" client 3 || true
docker exec tcp-server /root/scripts/manage_capture.sh stop "$SCENARIO_NAME" server || true

# Do not consolidate logs to results — tests will use the files under the shared logs mount.
# Logs are already available under ./logs on the host via the shared volume.

# Cleanup
docker-compose -f docker/docker-compose.yml down

echo "Scenario 2 completed."
