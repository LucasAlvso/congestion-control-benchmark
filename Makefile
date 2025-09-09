.PHONY: build clean test docker-build docker-test

# Build binaries
build:
	mkdir -p bin
	go build -o bin/server ./src/server
	go build -o bin/client ./src/client

# Clean build artifacts
clean:
	rm -rf bin/
	rm -rf test-files/
	rm -rf logs/
	docker-compose -f docker/docker-compose.yml down --volumes --remove-orphans

# Generate test file
test-file:
	./scripts/generate-test-file.sh

# Build Docker containers
docker-build:
	cd docker && docker-compose build

# Run Docker test
docker-test:
	./scripts/build-and-test.sh

# Run local test (requires test file)
test: build test-file
	@echo "Starting server in background..."
	./bin/server --port=8080 &
	@sleep 2
	@echo "Testing LIST command..."
	echo "list" | ./bin/client --port=8080
	@echo "Stopping server..."
	pkill -f "./bin/server" || true

# Full test with Docker
full-test: clean docker-build docker-test

# Development setup
dev: build test-file
	@echo "Development environment ready!"
	@echo "Run './bin/server' to start server"
	@echo "Run './bin/client' to start client"
