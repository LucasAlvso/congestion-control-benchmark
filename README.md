# TCP Congestion Benchmark

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

## Logs

Connection logs are saved in JSON format in the `logs/` directory with metrics:
- Start/end timestamps
- Bytes sent/received
- Connection duration
- Throughput (bytes/second)
- Remote address
- Operation type
