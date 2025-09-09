#!/bin/bash

echo "=== TCP Congestion Benchmark Build and Test ==="

# Generate test file
echo "1. Generating test file..."
./scripts/generate-test-file.sh

# Build Docker containers
echo "2. Building Docker containers..."
cd docker
docker-compose build

# Start server
echo "3. Starting server..."
docker-compose up -d server

# Wait for server to start
echo "Waiting for server to start..."
sleep 3

# Test basic functionality
echo "4. Testing basic functionality..."
echo "Starting interactive client (client1)..."
echo "You can now test the following commands:"
echo "  list"
echo "  put test-files/test-200mb.bin"
echo "  quit"
echo ""
echo "To test concurrent clients, open new terminals and run:"
echo "  docker exec -it tcp-client2 ./client"
echo "  docker exec -it tcp-client3 ./client"
echo "  docker exec -it tcp-client4 ./client"
echo ""

# Start interactive client
docker-compose run --rm client1

echo "5. Cleaning up..."
docker-compose down

echo "Build and test completed!"
