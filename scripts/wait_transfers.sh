#!/bin/bash
# wait_transfers.sh: wait until TCP transfers on given port quiesce across containers
# Usage: ./scripts/wait_transfers.sh <port> <container1> [container2 ...]
# Optional envs:
#   TIMEOUT=900        # max seconds to wait
#   CHECK_INTERVAL=2   # seconds between checks
#   STABLE_CYCLES=3    # consecutive zero-active checks required

set -e

PORT="$1"
shift || true
CONTAINERS=("$@")

if [[ -z "$PORT" || ${#CONTAINERS[@]} -eq 0 ]]; then
  echo "Usage: $0 <port> <container1> [container2 ...]"
  exit 2
fi

TIMEOUT="${TIMEOUT:-900}"
CHECK_INTERVAL="${CHECK_INTERVAL:-2}"
STABLE_CYCLES="${STABLE_CYCLES:-3}"

start_ts=$(date +%s)
stable=0

echo "Waiting for TCP port ${PORT} to quiesce across: ${CONTAINERS[*]} (timeout=${TIMEOUT}s)"

while true; do
  active_total=0
  for c in "${CONTAINERS[@]}"; do
    # Count active (non-LISTEN/TIME-WAIT) TCP connections where local or remote endpoint has :PORT
    count=$(docker exec "$c" sh -lc "ss -tan 2>/dev/null | awk -v P=':${PORT}' 'NR>1 { if ((index(\$4,P)>0 || index(\$5,P)>0) && \$1!="LISTEN" && \$1!="TIME-WAIT") n++ } END{print n+0}'" 2>/dev/null || echo 0)
    active_total=$((active_total + count))
    echo " - ${c}: active=${count}"
  done

  if [[ "$active_total" -eq 0 ]]; then
    stable=$((stable + 1))
    echo "No active connections detected (stable ${stable}/${STABLE_CYCLES})"
  else
    stable=0
    echo "Active connections total=${active_total}; continuing to wait"
  fi

  if [[ "$stable" -ge "$STABLE_CYCLES" ]]; then
    echo "Transfers quiesced. Proceeding."
    break
  fi

  now=$(date +%s)
  elapsed=$((now - start_ts))
  if [[ "$elapsed" -ge "$TIMEOUT" ]]; then
    echo "Reached TIMEOUT (${TIMEOUT}s) while waiting for transfers to quiesce. Proceeding anyway."
    break
  fi

  sleep "$CHECK_INTERVAL"
done

# Small grace period to flush final packets into pcap
sleep 2

exit 0
