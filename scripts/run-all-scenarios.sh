#!/bin/bash

# Run all TCP congestion control test scenarios

set -e

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo "TCP Congestion Control Test Suite"
echo "================================="
echo "Starting full test run at $(date)"
echo "Results will be saved to the logs folder"
echo ""

# Make all scripts executable
chmod +x scripts/*.sh || true

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

echo "================================="
echo "All scenarios completed successfully!"
echo "Results consolidated in logs"
echo "================================="
