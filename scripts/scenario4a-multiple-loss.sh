#!/bin/bash

# Scenario 4a: Multiple clients with packet loss (with captures)

set -e

SCENARIO_NAME="scenario4a-multiple-loss"
RESULTS_DIR="./results/$SCENARIO_NAME"
mkdir -p "$RESULTS_DIR"

echo "Running Scenario 4a: Multiple clients with packet loss (with captures)"

# Generate test file if needed
./scripts/generate-test-file.sh 200MB

# Start server and client containers
docker-compose -f docker/docker-compose.yml up --build -d server client1 client2 client3
sleep 3

# Start captures on server and clients
docker exec tcp-server /root/scripts/manage_capture.sh start "$SCENARIO_NAME" server || true
docker exec tcp-client1 /root/scripts/manage_capture.sh start "$SCENARIO_NAME" client 1 || true
docker exec tcp-client2 /root/scripts/manage_capture.sh start "$SCENARIO_NAME" client 2 || true
docker exec tcp-client3 /root/scripts/manage_capture.sh start "$SCENARIO_NAME" client 3 || true
# Ensure captures have time to initialize before starting the client transfers
sleep 0.5

# Run clients concurrently with packet loss applied inside each client container
docker exec -d tcp-client1 /bin/sh -c "for i in 1 2 3; do tc qdisc add dev eth0 root netem loss 0.1% && break || sleep 1; done && timeout 900s sh -c \"echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs\""
docker exec -d tcp-client2 /bin/sh -c "for i in 1 2 3; do tc qdisc add dev eth0 root netem loss 0.1% && break || sleep 1; done && timeout 900s sh -c \"echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs\""
docker exec -d tcp-client3 /bin/sh -c "for i in 1 2 3; do tc qdisc add dev eth0 root netem loss 0.1% && break || sleep 1; done && timeout 900s sh -c \"echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs\""

# Wait for clients to finish (timeout guard)
TIMEOUT=600
START=$(date +%s)
while true; do
  RUNNING=0
  for c in tcp-client1 tcp-client2 tcp-client3; do
    if docker exec "$c" pgrep -f './client' >/dev/null 2>&1; then
      RUNNING=1
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

# Generate graphs on server
docker exec tcp-server /root/scripts/generate_graphs.sh "$SCENARIO_NAME" || true

# Copy logs & graphs from containers
mkdir -p "$RESULTS_DIR/server_logs" "$RESULTS_DIR/client1_logs" "$RESULTS_DIR/client2_logs" "$RESULTS_DIR/client3_logs"
docker cp tcp-server:/root/logs "$RESULTS_DIR/server_logs" 2>/dev/null || true
docker cp tcp-client1:/root/logs "$RESULTS_DIR/client1_logs" 2>/dev/null || true
docker cp tcp-client2:/root/logs "$RESULTS_DIR/client2_logs" 2>/dev/null || true
docker cp tcp-client3:/root/logs "$RESULTS_DIR/client3_logs" 2>/dev/null || true

# Cleanup
docker-compose -f docker/docker-compose.yml down

echo "Scenario 4a completed. Results in $RESULTS_DIR"
