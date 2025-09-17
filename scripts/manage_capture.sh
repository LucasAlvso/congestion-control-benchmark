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

PCAP_PATH="${PCAP_DIR}/${BASENAME}.pcap"
PID_PATH="${PCAP_DIR}/${BASENAME}.pcap.pid"

if [[ "$ACTION" == "start" ]]; then
  # Start tcpdump capturing only TCP packets on all interfaces
  # Run in background and save PID to pidfile
  nohup tcpdump -i any tcp -w "$PCAP_PATH" >/dev/null 2>&1 &
  echo $! > "$PID_PATH"
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
