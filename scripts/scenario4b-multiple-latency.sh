#!/bin/bash

# Scenario 4b: Multiple clients with variable latency (with captures)

set -e

SCENARIO_NAME="scenario4b-multiple-latency"
RESULTS_DIR="./results/$SCENARIO_NAME"
mkdir -p "$RESULTS_DIR"

echo "Running Scenario 4b: Multiple clients with variable latency (with captures)"

# Generate test file if needed
./scripts/generate-test-file.sh 200MB

# Start server and client containers
docker-compose -f docker/docker-compose.yml up --build -d server client1 client2 client3
sleep 3

# Ensure server storage and logs are clean for this scenario
docker exec tcp-server /bin/sh -c "rm -rf /root/files/* /root/logs/${SCENARIO_NAME} || true"

# Start captures on server and clients
docker exec tcp-server /root/scripts/manage_capture.sh start "$SCENARIO_NAME" server || true
sleep 0.2
docker exec tcp-client1 /root/scripts/manage_capture.sh start "$SCENARIO_NAME" client 1 || true
sleep 0.2
docker exec tcp-client2 /root/scripts/manage_capture.sh start "$SCENARIO_NAME" client 2 || true
sleep 0.2
docker exec tcp-client3 /root/scripts/manage_capture.sh start "$SCENARIO_NAME" client 3 || true

# Run clients concurrently with variable latency applied inside each client container
docker exec -d tcp-client1 /bin/sh -c "tc qdisc del dev eth0 root 2>/dev/null || true; for i in 1 2 3; do tc qdisc add dev eth0 root netem delay 15ms 3ms distribution normal && break || sleep 1; done && timeout 1200s sh -c \"echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs\""
docker exec -d tcp-client2 /bin/sh -c "tc qdisc del dev eth0 root 2>/dev/null || true; for i in 1 2 3; do tc qdisc add dev eth0 root netem delay 15ms 3ms distribution normal && break || sleep 1; done && timeout 1200s sh -c \"echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs\""
docker exec -d tcp-client3 /bin/sh -c "tc qdisc del dev eth0 root 2>/dev/null || true; for i in 1 2 3; do tc qdisc add dev eth0 root netem delay 15ms 3ms distribution normal && break || sleep 1; done && timeout 1200s sh -c \"echo 'put test-files/test_200MB.bin' | ./client --host=server --port=8080 --log-dir=./logs\""

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

# Copy logs & graphs from containers
mkdir -p "$RESULTS_DIR/server_logs" "$RESULTS_DIR/client1_logs" "$RESULTS_DIR/client2_logs" "$RESULTS_DIR/client3_logs"
docker cp tcp-server:/root/logs/${SCENARIO_NAME} "$RESULTS_DIR/server_logs" 2>/dev/null || true
docker cp tcp-client1:/root/logs/${SCENARIO_NAME} "$RESULTS_DIR/client1_logs" 2>/dev/null || true
docker cp tcp-client2:/root/logs/${SCENARIO_NAME} "$RESULTS_DIR/client2_logs" 2>/dev/null || true
docker cp tcp-client3:/root/logs/${SCENARIO_NAME} "$RESULTS_DIR/client3_logs" 2>/dev/null || true

# Cleanup
docker-compose -f docker/docker-compose.yml down

echo "Scenario 4b completed. Results in $RESULTS_DIR"
