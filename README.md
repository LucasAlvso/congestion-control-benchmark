# TCP Congestion Control Benchmark


## Usage

### Generate Test Files
```bash
# Generate 200MB test file for experiments
./scripts/generate-test-file.sh 200MB
```

### Server Application
```bash
./bin/server [options]
```

**Options:**
- `-port <port>`: Server listening port (default: 8080)
- `-dir <directory>`: File storage directory (default: ./files)  
- `-log-dir <directory>`: Connection logs directory (default: ./logs)

### Client Application
```bash
./bin/client [options]
```

**Options:**
- `-host <hostname>`: Server hostname (default: localhost)
- `-port <port>`: Server port (default: 8080)
- `-log-dir <directory>`: Connection logs directory (default: ./logs)

**Interactive Commands:**
- `list`: List files available on server
- `put <filename>`: Upload file to server  
- `quit`: Close connection and exit


### Multi-Client
```bash
cd docker

# Start server
docker-compose up -d server

# Run multiple clients concurrently
docker-compose up client1 client2 client3 client4

# Cleanup
docker-compose down
```

## Protocol Specification

### Binary Frame Format
```
[OpCode:1byte][PayloadLen:4bytes][Payload:variable]
```

### Operation Codes
- **LIST (1)**: Request file listing from server
- **PUT (2)**: Upload file to server  
- **QUIT (3)**: Close connection gracefully
- **ERROR (255)**: Error response from server

### Message Flow
```
Client -> Server: LIST
Server -> Client: [file1_name:size, file2_name:size, ...]

Client -> Server: PUT filename + file_data
Server -> Client: ACK/ERROR

Client -> Server: QUIT
Server -> Client: Connection closes
```

## Data Collection & Analysis

## System Requirements
- Go 1.19 or later
- 300MB available disk space (for test files + binary + logs)