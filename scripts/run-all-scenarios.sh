#!/bin/bash

# Run all TCP congestion control test scenarios

set -e

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
MASTER_RESULTS_DIR="./results/full_test_$TIMESTAMP"

echo "TCP Congestion Control Test Suite"
echo "================================="
echo "Starting full test run at $(date)"
echo "Results will be saved to: $MASTER_RESULTS_DIR"
echo ""

mkdir -p $MASTER_RESULTS_DIR

# Make all scenario scripts executable
chmod +x scripts/scenario*.sh

# Run all scenarios
echo "Running Scenario 1..."
./scripts/scenario1-single-clean.sh
echo ""

echo "Running Scenario 2..."
./scripts/scenario2-multiple-clean.sh
echo ""

echo "Running Scenario 3a..."
./scripts/scenario3a-single-loss.sh
echo ""

echo "Running Scenario 3b..."
./scripts/scenario3b-single-latency.sh
echo ""

echo "Running Scenario 4a..."
./scripts/scenario4a-multiple-loss.sh
echo ""

echo "Running Scenario 4b..."
./scripts/scenario4b-multiple-latency.sh
echo ""

# Consolidate all results
echo "Consolidating results..."
cp -r ./results/scenario* $MASTER_RESULTS_DIR/

# Generate summary
cat > $MASTER_RESULTS_DIR/test_summary.txt <<EOF
TCP Congestion Control Test Results
==================================
Test completed: $(date)
Duration: Full test suite

Scenarios executed:
- Scenario 1: Single client, clean network
- Scenario 2: Multiple clients (3), clean network
- Scenario 3a: Single client with packet loss (0.1%)
- Scenario 3b: Single client with variable latency (50ms ±20ms)
- Scenario 4a: Multiple clients (3) with packet loss (0.1%)
- Scenario 4b: Multiple clients (3) with variable latency (50ms ±20ms)

Test file: 200MB

Results location: $MASTER_RESULTS_DIR
Individual scenario results: $MASTER_RESULTS_DIR/scenario*/
EOF

echo "================================="
echo "All scenarios completed successfully!"
echo "Results consolidated in: $MASTER_RESULTS_DIR"
echo "================================="
