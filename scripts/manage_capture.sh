#!/bin/bash
# manage_capture.sh: start/stop tcpdump captures inside container
# Usage:
#  ./manage_capture.sh start <scenario> <role> [id]
#  ./manage_capture.sh stop  <scenario> <role> [id]
set -e

ACTION="$1"
SCENARIO="$2"
ROLE="$3"
ID="$4"

if [[ -z "$ACTION" || -z "$SCENARIO" || -z "$ROLE" ]]; then
  echo "Usage: $0 {start|stop} <scenario> <role> [id]"
  exit 2
fi

PCAP_DIR="/root/logs/${SCENARIO}/pcap"
mkdir -p "$PCAP_DIR"

if [[ -n "$ID" ]]; then
  BASENAME="${ROLE}_${ID}"
else
  BASENAME="${ROLE}"
fi

# Use a timestamped pcap filename to avoid collisions across runs.
TIMESTAMP=$(date +%s)
PCAP_PATH="${PCAP_DIR}/${BASENAME}_${TIMESTAMP}.pcap"
# Stable pidfile name so we can stop the latest capture for the role/id.
PID_PATH="${PCAP_DIR}/${BASENAME}.pid"

if [[ "$ACTION" == "start" ]]; then
  # If a capture is already running for this role/id, report and do not start another.
  if [[ -f "$PID_PATH" ]]; then
    # pidfile stores PID on the first line; handle legacy single-line pidfiles too.
    OLD_PID=$(sed -n '1p' "$PID_PATH")
    if kill -0 "$OLD_PID" >/dev/null 2>&1; then
      echo "Capture already running with pid $OLD_PID for $BASENAME (pidfile: $PID_PATH)"
      exit 0
    else
      echo "Stale pidfile found, removing: $PID_PATH"
      rm -f "$PID_PATH"
    fi
  fi

  # Remove any old pcap with the same base name (shouldn't normally happen due to timestamped name)
  if [[ -f "$PCAP_PATH" ]]; then
    rm -f "$PCAP_PATH" || true
  fi

  # Start tcpdump capturing only TCP packets on the docker bridge interface.
  # Use -s 0 to capture full packets, -n to avoid name resolution, -U for packet-buffered output.
  # Capture both directions:
  # - when run for a client role, capture traffic to/from the server
  # - when run for the server role, capture traffic to/from all clients
  if [[ "$ROLE" == "server" ]]; then
    FILTER='tcp and (host client1 or host client2 or host client3 or host client4)'
  else
    FILTER='tcp and host server'
  fi
  nohup tcpdump -i eth0 -s 0 -U "$FILTER" -w "$PCAP_PATH" >/dev/null 2>&1 &
  PID=$!

  # Save PID and PCAP path in pidfile (PID on first line, PCAP path on second).
  # This allows the stop action to know the exact file that was created.
  printf "%s\n%s\n" "$PID" "$PCAP_PATH" > "$PID_PATH"

  # Give the process a moment to start and verify it's running.
  sleep 0.2
  if kill -0 "$PID" >/dev/null 2>&1; then
    # Verify the pcap file is being written to. Wait up to 5s for the file
    # to appear and grow; if it doesn't, warn the user but continue so tests
    # don't block indefinitely.
    COUNT=0
    LAST_SIZE=0
    while [ $COUNT -lt 10 ]; do
      if [ -f "$PCAP_PATH" ]; then
        SIZE=$(stat -c%s "$PCAP_PATH" 2>/dev/null || echo 0)
        if [ "$SIZE" -gt 0 ]; then
          # file has started growing
          echo "Started capture: $PCAP_PATH (pid $PID)"
          exit 0
        fi
        LAST_SIZE=$SIZE
      fi
      COUNT=$((COUNT+1))
      sleep 0.5
    done

    echo "Started tcpdump pid $PID but pcap file did not grow within timeout: $PCAP_PATH"
    echo "Proceeding, but inspect the capture after the run."
    exit 0
  else
    echo "Failed to start tcpdump (pid $PID); check container logs"
    rm -f "$PID_PATH"
    exit 1
  fi
fi

if [[ "$ACTION" == "stop" ]]; then
  if [[ -f "$PID_PATH" ]]; then
    # pidfile format: first line = PID, second line = PCAP path
    PID=$(sed -n '1p' "$PID_PATH" | tr -d '[:space:]')
    PCAP_FILE=$(sed -n '2p' "$PID_PATH" | tr -d '[:space:]')

    # Fallback: if PCAP_FILE is empty, use the computed PCAP_PATH (legacy support)
    if [[ -z "$PCAP_FILE" ]]; then
      PCAP_FILE="$PCAP_PATH"
    fi

    if [[ -n "$PID" ]] && kill -0 "$PID" >/dev/null 2>&1; then
      # attempt graceful termination first
      kill "$PID" >/dev/null 2>&1 || true
      sleep 1
      # if still running, force kill
      if kill -0 "$PID" >/dev/null 2>&1; then
        kill -9 "$PID" >/dev/null 2>&1 || true
      fi
      echo "Stopped capture pid=$PID for $PCAP_FILE"
    else
      echo "No running tcpdump with pid ${PID:-'(none)'}; expected pcap: $PCAP_FILE"
    fi

    rm -f "$PID_PATH"
    exit 0
  else
    echo "No pidfile found at $PID_PATH"
    exit 1
  fi
fi

echo "Unknown action: $ACTION"
exit 2
