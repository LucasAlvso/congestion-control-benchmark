#!/bin/bash
# generate_graphs.sh <scenario>
# Generates CSVs from pcaps using tshark and calls Python plotting script.
set -e

SCENARIO="$1"
if [[ -z "$SCENARIO" ]]; then
  echo "Usage: $0 <scenario>"
  exit 2
fi

PCAP_DIR="/root/logs/${SCENARIO}/pcap"
OUT_DIR="/root/logs/${SCENARIO}/pcap_csv"
GRAPHS_DIR="/root/logs/${SCENARIO}/graphs"

mkdir -p "$OUT_DIR" "$GRAPHS_DIR"

# For each pcap file produce a CSV and a pair of graphs
for p in "$PCAP_DIR"/*.pcap; do
  [ -e "$p" ] || continue
  base=$(basename "$p" .pcap)
  csv="$OUT_DIR/${base}.csv"
  png_prefix="$GRAPHS_DIR/${base}"

  echo "Processing $p -> $csv"

  # Export fields with relative time and TCP metrics
  # Fields: frame.time_relative, tcp.seq, tcp.ack, tcp.len, tcp.analysis.bytes_in_flight
  # First attempt: filter to TCP frames that carry payload or have bytes_in_flight
  # analysis. This reduces CSV size in normal transfers, but may miss some
  # captures (eg. if client-side capture contains mostly ACKs). If the CSV
  # ends up header-only, retry with a broader 'tcp' display filter.
  tshark -r "$p" -Y "tcp && (tcp.len > 0 || tcp.analysis.bytes_in_flight)" -T fields \
    -e frame.time_relative \
    -e tcp.seq \
    -e tcp.ack \
    -e tcp.len \
    -e tcp.analysis.bytes_in_flight \
    -E header=y -E separator=, -E quote=d > "$csv" 2>/dev/null || true

  # If CSV is empty (only header) then retry using a broader tcp filter so the
  # plotting step gets a chance to extract sequence/ACK samples or at least
  # produce more informative CSV rows (some traces have ACK-only packets).
  if [ "$(wc -l < "$csv" 2>/dev/null || echo 0)" -le 1 ]; then
    echo "CSV appears header-only for $p — retrying with broader 'tcp' filter"
    tshark -r "$p" -Y "tcp" -T fields \
      -e frame.time_relative \
      -e tcp.seq \
      -e tcp.ack \
      -e tcp.len \
      -e tcp.analysis.bytes_in_flight \
      -E header=y -E separator=, -E quote=d > "$csv" 2>/dev/null || true
  fi

  # Final sanity check: warn if still empty so user can inspect the original pcap.
  if [ "$(wc -l < "$csv" 2>/dev/null || echo 0)" -le 1 ]; then
    echo "Warning: CSV for $p contains no usable TCP samples (header only). Inspect $p with tshark/wireshark."
  fi

  # Call python plotting script (plot_pcap.py must exist in /root/scripts)
  if [[ -f /root/scripts/plot_pcap.py ]]; then
    # Prefer venv python if present (created in Dockerfile at /opt/venv)
    if [[ -x /opt/venv/bin/python ]]; then
      /opt/venv/bin/python /root/scripts/plot_pcap.py "$csv" "$png_prefix"
    else
      python3 /root/scripts/plot_pcap.py "$csv" "$png_prefix"
    fi
  else
    echo "plot_pcap.py not found in /root/scripts — skipping plotting for $csv"
  fi
done

echo "Graph generation completed. Graphs in $GRAPHS_DIR"
