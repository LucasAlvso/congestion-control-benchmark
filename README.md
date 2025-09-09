# TCP Congestion Benchmark

A simple TCP client-server file transfer application for analyzing TCP congestion control behavior.

## Features

- **Client-Server Architecture**: TCP-based file transfer with custom protocol
- **Concurrent Server**: Handles multiple clients simultaneously using goroutines
- **Performance Logging**: Tracks connection metrics (throughput, duration, bytes transferred)
- **Docker Support**: Containerized deployment for consistent testing
- **Simple Protocol**: Binary frame format with LIST, PUT, QUIT operations

## Quick Start

### 1. Generate Test File
```bash
./scripts/generate-test-file.sh
```

### 2. Build and Test
```bash
./scripts/build-and-test.sh
```

### 3. Manual Testing

#### Start Server
```bash
cd docker
docker-compose up -d server
```

#### Run Client
```bash
docker-compose run --rm client1
```

#### Available Commands
- `list` - List files on server
- `put <filename>` - Upload file to server
- `quit` - Exit client

## Project Structure

```
tcp-congestion-benchmark/
├── src/
│   ├── client/          # Client implementation
│   ├── server/          # Server implementation
│   ├── protocol/        # Protocol definition
│   └── common/          # Shared utilities (logging)
├── docker/              # Docker configurations
├── scripts/             # Build and test scripts
├── test-files/          # Test files (200MB)
└── logs/               # Connection logs
```

## Protocol Format

Binary frame format:
```
[OpCode:1byte][PayloadLen:4bytes][Payload:variable]
```

Operations:
- `LIST` (1): Request file listing
- `PUT` (2): Upload file
- `QUIT` (3): Close connection
- `ERROR` (255): Error response

## Testing Scenarios

The application supports the four test scenarios required by the assignment:

1. **Scenario 1**: Single client, normal network
2. **Scenario 2**: Multiple concurrent clients, normal network
3. **Scenario 3**: Single client with network impairments
4. **Scenario 4**: Multiple clients with network impairments

## Logs

Connection logs are saved in JSON format in the `logs/` directory with metrics:
- Start/end timestamps
- Bytes sent/received
- Connection duration
- Throughput (bytes/second)
- Remote address
- Operation type

## Docker Commands

```bash
# Build containers
docker-compose build

# Start server only
docker-compose up -d server

# Run single client
docker-compose run --rm client1

# Run multiple clients (in separate terminals)
docker exec -it tcp-client2 ./client
docker exec -it tcp-client3 ./client
docker exec -it tcp-client4 ./client

# Stop all containers
docker-compose down
```

## Development

### Local Build
```bash
# Build client
go build -o bin/client ./src/client

# Build server
go build -o bin/server ./src/server

# Run server
./bin/server --host=localhost --port=8080

# Run client
./bin/client --host=localhost --port=8080
```

## Requirements

- Go 1.21+
- Docker & Docker Compose
- 200MB+ free disk space for test files
