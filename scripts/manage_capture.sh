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
    OLD_PID=$(cat "$PID_PATH")
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

  # Start tcpdump capturing only TCP packets on all interfaces.
  # Use -s 0 to capture full packets, -n to avoid name resolution, -U for packet-buffered output.
  nohup tcpdump -i any -s 0 -n -U tcp -w "$PCAP_PATH" >/dev/null 2>&1 &
  echo $! > "$PID_PATH"
  sleep 0.1
  echo "Started capture: $PCAP_PATH (pid $(cat $PID_PATH))"
  exit 0
fi

if [[ "$ACTION" == "stop" ]]; then
  if [[ -f "$PID_PATH" ]]; then
    PID=$(cat "$PID_PATH")
    if kill -0 "$PID" >/dev/null 2>&1; then
      kill "$PID"
      sleep 1
      echo "Stopped capture pid=$PID for $PCAP_PATH"
    else
      echo "No running tcpdump with pid $PID"
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
