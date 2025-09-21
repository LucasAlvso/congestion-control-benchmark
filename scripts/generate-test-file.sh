#!/bin/bash

# Generate 200MB test files for all scenarios
echo "Generating 200MB test files for all scenarios..."

# Create test-files directory if it doesn't exist
mkdir -p test-files

# Generate base 200MB file with random data
echo "Creating base test file..."
dd if=/dev/urandom of=test-files/test_200MB.bin bs=1M count=200

# Create scenario-specific test files by copying the base file
echo "Creating scenario-specific test files..."

# Multiple client scenarios (with unique filenames)
cp test-files/test_200MB.bin "test-files/test_200MB_scenario2-multiple-clean_client1.bin"
cp test-files/test_200MB.bin "test-files/test_200MB_scenario2-multiple-clean_client2.bin"
cp test-files/test_200MB.bin "test-files/test_200MB_scenario2-multiple-clean_client3.bin"

cp test-files/test_200MB.bin "test-files/test_200MB_scenario4a-multiple-loss_client1.bin"
cp test-files/test_200MB.bin "test-files/test_200MB_scenario4a-multiple-loss_client2.bin"
cp test-files/test_200MB.bin "test-files/test_200MB_scenario4a-multiple-loss_client3.bin"

cp test-files/test_200MB.bin "test-files/test_200MB_scenario4b-multiple-latency_client1.bin"
cp test-files/test_200MB.bin "test-files/test_200MB_scenario4b-multiple-latency_client2.bin"
cp test-files/test_200MB.bin "test-files/test_200MB_scenario4b-multiple-latency_client3.bin"

echo "Test files generated:"
ls -lh test-files/test_200MB*.bin
