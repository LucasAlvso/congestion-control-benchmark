#!/bin/bash

# Scenario 2: Multiple clients, clean network (with captures)

set -e

SCENARIO_NAME="scenario2-multiple-clean"
RESULTS_DIR="./results/$SCENARIO_NAME"
mkdir -p "$RESULTS_DIR"

echo "Running Scenario 2: Multiple clients, clean network (with captures)"

# Generate test file if needed
./scripts/generate-test-file.sh 200MB

# Start server and client containers
docker-compose -f docker/docker-compose.yml up --build -d server client1 client2 client3
sleep 3

# Ensure server storage and logs are clean for this scenario
docker exec tcp-server /bin/sh -c "rm -rf /root/files/* /root/logs/${SCENARIO_NAME} || true"

# Start captures on server and clients
docker exec tcp-server /root/scripts/manage_capture.sh start "$SCENARIO_NAME" server || true
docker exec tcp-client1 /root/scripts/manage_capture.sh start "$SCENARIO_NAME" client 1 || true
docker exec tcp-client2 /root/scripts/manage_capture.sh start "$SCENARIO_NAME" client 2 || true
docker exec tcp-client3 /root/scripts/manage_capture.sh start "$SCENARIO_NAME" client 3 || true

# Run clients concurrently (exec into containers)
docker exec -d tcp-client1 /bin/sh -c "timeout 900s sh -c \"echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs\""
docker exec -d tcp-client2 /bin/sh -c "timeout 900s sh -c \"echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs\""
docker exec -d tcp-client3 /bin/sh -c "timeout 900s sh -c \"echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs\""

# Wait for clients to finish by polling logs (simple approach: wait until client logs contain transfer completion or container exits)
# Wait for a conservative timeout (e.g., 10 minutes) to avoid infinite waits
TIMEOUT=600
START=$(date +%s)
while true; do
  RUNNING=0
  for c in tcp-client1 tcp-client2 tcp-client3; do
    if docker exec "$c" ps aux >/dev/null 2>&1; then
      # check if client process still running inside container
      if docker exec "$c" pgrep -f './client' >/dev/null 2>&1; then
        RUNNING=1
      fi
    fi
  done

  if [ "$RUNNING" -eq 0 ]; then
    break
  fi

  NOW=$(date +%s)
  ELAPSED=$((NOW-START))
  if [ "$ELAPSED" -gt "$TIMEOUT" ]; then
    echo "Timeout waiting for clients to finish"
    break
  fi
  sleep 2
done

# Stop captures
docker exec tcp-client1 /root/scripts/manage_capture.sh stop "$SCENARIO_NAME" client 1 || true
docker exec tcp-client2 /root/scripts/manage_capture.sh stop "$SCENARIO_NAME" client 2 || true
docker exec tcp-client3 /root/scripts/manage_capture.sh stop "$SCENARIO_NAME" client 3 || true
docker exec tcp-server /root/scripts/manage_capture.sh stop "$SCENARIO_NAME" server || true

# Generate graphs on server (processes all pcaps written under /root/logs/<scenario>)
docker exec tcp-server /root/scripts/generate_graphs.sh "$SCENARIO_NAME" || true

# Copy logs & graphs from containers
mkdir -p "$RESULTS_DIR/server_logs" "$RESULTS_DIR/client1_logs" "$RESULTS_DIR/client2_logs" "$RESULTS_DIR/client3_logs"
docker cp tcp-server:/root/logs "$RESULTS_DIR/server_logs" 2>/dev/null || true
docker cp tcp-client1:/root/logs "$RESULTS_DIR/client1_logs" 2>/dev/null || true
docker cp tcp-client2:/root/logs "$RESULTS_DIR/client2_logs" 2>/dev/null || true
docker cp tcp-client3:/root/logs "$RESULTS_DIR/client3_logs" 2>/dev/null || true

# Cleanup
docker-compose -f docker/docker-compose.yml down

echo "Scenario 2 completed. Results in $RESULTS_DIR"
