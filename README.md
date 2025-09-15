# TCP Congestion Control Benchmark

A comprehensive client-server application designed for analyzing TCP congestion control behavior under different network conditions. This implementation fulfills the requirements of the university laboratory assignment for TCP congestion control analysis.

## Features

### Core Protocol Implementation
- **Custom Application Protocol**: Binary frame format with operation codes (LIST, PUT, QUIT)
- **Concurrent Server**: Handles multiple simultaneous client connections
- **Reliable File Transfer**: TCP-based file upload with error handling
- **Remote File Listing**: Server-side file directory browsing

### TCP Analysis & Instrumentation
- **TCP_INFO Collection**: Real-time TCP metrics gathering (Linux only)
- **Connection Logging**: Detailed per-connection performance metrics
- **Network Emulation**: tc/netem integration for bandwidth/latency/loss simulation
- **Automated Test Scenarios**: 4 pre-configured test scenarios matching assignment requirements

### Performance Metrics
- RTT (Round Trip Time) monitoring
- Congestion window (cwnd) tracking  
- Slow start threshold (ssthresh) analysis
- Retransmission counting
- Throughput calculation
- Connection duration timing

## Quick Start

### 1. Build the Project
```bash
make build
```

### 2. Generate Test Files
```bash
# Generate 200MB test file for experiments
./scripts/generate-test-file.sh 200MB
```

### 3. Run Basic Test
```bash
# Start server
./bin/server -port 8080 -log-dir ./logs &

# Run client
echo -e "list\nquit" | ./bin/client -host localhost -port 8080 -log-dir ./logs
```

### 4. Run Automated Test Scenarios
```bash
# Run all 4 scenarios with network emulation (requires sudo)
sudo ./scripts/run-test-scenarios.sh

# Run without network emulation  
./scripts/run-test-scenarios.sh lo --no-netem
```

## Usage

### Server Application
```bash
./bin/server [options]
```

**Options:**
- `-port <port>`: Server listening port (default: 8080)
- `-dir <directory>`: File storage directory (default: ./files)  
- `-log-dir <directory>`: Connection logs directory (default: ./logs)

**Example:**
```bash
./bin/server -port 9000 -dir /tmp/server-files -log-dir /tmp/logs
```

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

**Example:**
```bash
./bin/client -host 192.168.1.100 -port 9000 -log-dir ./client-logs
```

## Test Scenarios

The automated test suite implements the 4 scenarios required by the assignment:

### Scenario 1: Single Client, Clean Network
- 1 client uploads 200MB file
- No network impairments
- Baseline performance measurement

### Scenario 2: Multiple Clients, Clean Network  
- 3 concurrent clients upload 200MB files
- No network impairments
- Concurrency impact analysis

### Scenario 3: Single Client, Impaired Network
- 1 client uploads 200MB file
- Network conditions: 0.1% packet loss
- Congestion control behavior under loss

### Scenario 4: Multiple Clients, Impaired Network
- 3 concurrent clients upload 200MB files  
- Network conditions: 0.1% packet loss
- Combined concurrency and loss effects

## Network Emulation

### Prerequisites (Linux)
```bash
# Ensure tc (traffic control) is available
sudo apt-get install iproute2  # Ubuntu/Debian
sudo yum install iproute        # CentOS/RHEL
```

### Manual Network Configuration
```bash
# Set bandwidth limit (10 Mbit/s)
sudo ./scripts/network-emulation.sh setup-bandwidth lo 10mbit

# Add network delay (50ms)
sudo ./scripts/network-emulation.sh setup-delay lo 50ms

# Add packet loss (0.1%)
sudo ./scripts/network-emulation.sh setup-loss lo 0.1%

# Combined conditions
sudo ./scripts/network-emulation.sh setup-combined lo 10mbit 50ms 0.1%

# Clear all rules
sudo ./scripts/network-emulation.sh clear lo

# Check current status
sudo ./scripts/network-emulation.sh status lo
```

## Docker Support

### Multi-Client Testing
```bash
cd docker

# Start server
docker-compose up -d server

# Run multiple clients concurrently
docker-compose up client1 client2 client3 client4

# Cleanup
docker-compose down
```

### Individual Container Management
```bash
# Build images
docker-compose build

# Interactive client session
docker-compose run --rm client1

# View server logs
docker-compose logs server
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

### Connection Logs
JSON format logs are generated for each connection:
```json
{
  "connection_id": "uuid",
  "start_time": "2024-01-15T10:30:00Z",
  "end_time": "2024-01-15T10:31:30Z", 
  "duration_seconds": 90.5,
  "remote_addr": "192.168.1.100:45678",
  "operation": "PUT test-200mb.bin",
  "bytes_sent": 209715200,
  "bytes_received": 1024,
  "throughput_bps": 2318502.2,
  "tcp_samples": [...]
}
```

### TCP_INFO Metrics (Linux Only)
Real-time TCP stack information:
- `rtt_us`: Round trip time (microseconds)
- `snd_cwnd`: Congestion window size  
- `snd_ssthresh`: Slow start threshold
- `total_retrans`: Total retransmissions
- `lost`: Lost packets
- `bytes_acked`: Acknowledged bytes

### Wireshark Analysis
Packet captures are saved to `./pcaps/` directory for analysis:

**Useful Wireshark Filters:**
```
tcp.analysis.retransmission
tcp.analysis.fast_retransmission  
tcp.analysis.duplicate_ack
tcp.analysis.lost_segment
tcp.analysis.bytes_in_flight
```

**Recommended Analysis:**
1. Statistics → TCP Stream Graphs → Time-Sequence (tcptrace)
2. Statistics → I/O Graphs with tcp.analysis.bytes_in_flight
3. Add columns: "Delta time displayed", "TCP Bytes in Flight"

## File Structure
```
tcp-congestion-benchmark/
├── src/
│   ├── server/main.go          # Server application
│   ├── client/main.go          # Client application  
│   ├── protocol/protocol.go    # Protocol implementation
│   └── common/
│       ├── logger.go           # Connection logging
│       └── tcpinfo.go          # TCP_INFO collection
├── scripts/
│   ├── build-and-test.sh       # Build and basic test
│   ├── generate-test-file.sh   # Test file generation
│   ├── network-emulation.sh    # Network condition setup
│   └── run-test-scenarios.sh   # Automated test suite
├── docker/
│   ├── docker-compose.yml      # Multi-client setup
│   ├── Dockerfile.server       # Server container
│   └── Dockerfile.client       # Client container
├── bin/                        # Compiled binaries
├── logs/                       # Connection logs
├── files/                      # Server file storage
├── test-files/                 # Test files for upload
└── pcaps/                      # Packet captures
```

## Development

### Building from Source
```bash
# Build binaries
make build

# Clean build artifacts  
make clean

# Run tests
make test

# Build Docker images
make docker-build
```

### Adding New Features
1. Protocol changes: Modify `src/protocol/protocol.go`
2. Logging enhancements: Update `src/common/logger.go`
3. TCP metrics: Extend `src/common/tcpinfo.go`
4. New test scenarios: Add to `scripts/run-test-scenarios.sh`

## System Requirements

### Minimum Requirements
- Go 1.19 or later
- Linux/macOS/Windows
- 1GB available disk space (for test files)

### Network Emulation Requirements (Optional)
- Linux with root privileges
- iproute2 package (tc command)
- sudo access for network configuration

### Analysis Tools (Optional)
- Wireshark for packet analysis
- tcpdump for packet capture
- Python 3.x for data processing scripts

## Troubleshooting

### Common Issues

**Permission Denied (Network Emulation)**
```bash
# Ensure running with sudo
sudo ./scripts/run-test-scenarios.sh
```

**Server Port Already in Use**
```bash
# Kill existing server process
pkill -f "./bin/server"

# Or use different port
./bin/server -port 8081
```

**TCP_INFO Not Available**
- TCP_INFO collection only works on Linux
- Feature automatically disabled on other platforms
- Basic connection metrics still collected

**Large File Upload Timeout**
```bash
# Increase client timeout or use smaller test files
./scripts/generate-test-file.sh 50MB
```

## Performance Expectations

### Baseline Performance (Loopback, No Impairments)
- Throughput: ~1-5 Gbps (limited by CPU)
- RTT: <1ms
- Retransmissions: 0%

### With Network Emulation (10Mbit, 50ms, 0.1% loss)
- Throughput: ~8-10 Mbps  
- RTT: ~50ms
- Retransmissions: <1%
- Transfer time (200MB): ~2-3 minutes

## License

MIT License - see LICENSE file for details.

## Assignment Compliance

This implementation fulfills all requirements of the TCP Congestion Control Laboratory Assignment:

✅ **Client/Server Architecture**: Complete implementation  
✅ **TCP Protocol**: All communication over TCP/IPv4  
✅ **Application Protocol**: Custom binary protocol with LIST/PUT/QUIT operations  
✅ **Concurrent Server**: Multi-client support with goroutines  
✅ **Error Handling**: Connection errors and file conflicts handled  
✅ **Command Line Interface**: Full CLI with host/port options  
✅ **Instrumentation**: Connection logs with performance metrics  
✅ **TCP_INFO Collection**: Linux TCP stack metrics (optional feature)  
✅ **Network Emulation**: tc/netem integration for controlled experiments  
✅ **Test Scenarios**: All 4 required scenarios automated  
✅ **Analysis Support**: Wireshark-compatible packet captures generated
