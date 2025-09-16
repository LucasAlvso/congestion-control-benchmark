#!/bin/bash

# Generate 200MB test file
echo "Generating 200MB test file..."

# Create test-files directory if it doesn't exist
mkdir -p test-files

# Generate 200MB file with random data
dd if=/dev/urandom of=test-files/test_200MB.bin bs=1M count=200

echo "Test file generated: test-files/test_200MB.bin (200MB)"
ls -lh test-files/test_200MB.bin
