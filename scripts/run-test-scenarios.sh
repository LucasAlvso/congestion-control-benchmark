#!/bin/bash

# Automated test scenarios for TCP congestion control analysis
# Implements the 4 scenarios from the university assignment:
# 1. Single client, clean network, 200MB file
# 2. Multiple clients (2-4), clean network, 200MB file
# 3. Single client, with network impairments, 200MB file
# 4. Multiple clients, with network impairments, 200MB file

set -e

# Configuration
TEST_FILE_SIZE="200MB"
TEST_FILE="test-files/test_${TEST_FILE_SIZE}.bin"
SERVER_HOST="localhost"
SERVER_PORT="8080"
RESULTS_DIR="./test-results"
LOGS_DIR="./logs"
PCAP_DIR="./pcaps"
CLIENT_BIN="./bin/client"
SERVER_BIN="./bin/server"

# Network emulation settings
BANDWIDTH_LIMIT="10mbit"
NETWORK_DELAY="50ms"
PACKET_LOSS="0.1%"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to create test directory structure
setup_test_environment() {
    print_status "Setting up test environment..."
    
    # Create directories
    mkdir -p $RESULTS_DIR $LOGS_DIR $PCAP_DIR test-files
    
    # Build binaries if they don't exist
    if [[ ! -f $CLIENT_BIN ]] || [[ ! -f $SERVER_BIN ]]; then
        print_status "Building binaries..."
        make build || {
            print_error "Failed to build binaries. Run 'make build' first."
            exit 1
        }
    fi
    
    # Generate test file if it doesn't exist
    if [[ ! -f $TEST_FILE ]]; then
        print_status "Generating ${TEST_FILE_SIZE} test file..."
        ./scripts/generate-test-file.sh $TEST_FILE_SIZE || {
            print_error "Failed to generate test file"
            exit 1
        }
    fi
    
    print_success "Test environment ready"
}

# Function to start server in background
start_server() {
    local scenario_name=$1
    print_status "Starting server for scenario: $scenario_name"
    
    # Kill any existing server
    pkill -f "$SERVER_BIN" 2>/dev/null || true
    sleep 1
    
    # Start server with logs
    $SERVER_BIN -port $SERVER_PORT -log-dir "$LOGS_DIR/${scenario_name}_server" > "$RESULTS_DIR/${scenario_name}_server.log" 2>&1 &
    SERVER_PID=$!
    
    # Wait for server to start
    sleep 2
    
    # Check if server is running
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        print_error "Failed to start server"
        return 1
    fi
    
    print_success "Server started (PID: $SERVER_PID)"
    return 0
}

# Function to stop server
stop_server() {
    if [[ -n $SERVER_PID ]]; then
        print_status "Stopping server (PID: $SERVER_PID)"
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
        SERVER_PID=""
    fi
}

# Function to start packet capture
start_packet_capture() {
    local scenario_name=$1
    local interface=${2:-"lo"} # Default to loopback interface
    
    print_status "Starting packet capture for scenario: $scenario_name"
    
    # Check if tcpdump is available
    if ! command -v tcpdump &> /dev/null; then
        print_warning "tcpdump not available, skipping packet capture"
        return 0
    fi
    
    # Start tcpdump in background
    sudo tcpdump -i $interface -w "$PCAP_DIR/${scenario_name}.pcap" "port $SERVER_PORT" > /dev/null 2>&1 &
    TCPDUMP_PID=$!
    
    sleep 1
    
    if kill -0 $TCPDUMP_PID 2>/dev/null; then
        print_success "Packet capture started (PID: $TCPDUMP_PID)"
    else
        print_warning "Failed to start packet capture"
        TCPDUMP_PID=""
    fi
}

# Function to stop packet capture
stop_packet_capture() {
    if [[ -n $TCPDUMP_PID ]]; then
        print_status "Stopping packet capture (PID: $TCPDUMP_PID)"
        sudo kill $TCPDUMP_PID 2>/dev/null || true
        wait $TCPDUMP_PID 2>/dev/null || true
        TCPDUMP_PID=""
    fi
}

# Function to run single client test
run_single_client() {
    local scenario_name=$1
    local client_log_dir="$LOGS_DIR/${scenario_name}_client1"
    
    print_status "Running single client test..."
    
    mkdir -p $client_log_dir
    
    # Run client
    timeout 300 $CLIENT_BIN -host $SERVER_HOST -port $SERVER_PORT -log-dir "$client_log_dir" > "$RESULTS_DIR/${scenario_name}_client1.log" 2>&1 <<EOF || {
        print_error "Client test failed or timed out"
        return 1
    }
put $TEST_FILE
quit
EOF
    
    print_success "Single client test completed"
}

# Function to run multiple clients test
run_multiple_clients() {
    local scenario_name=$1
    local num_clients=${2:-3} # Default to 3 clients
    
    print_status "Running multiple clients test ($num_clients clients)..."
    
    local pids=()
    
    # Start multiple clients concurrently
    for i in $(seq 1 $num_clients); do
        local client_log_dir="$LOGS_DIR/${scenario_name}_client${i}"
        mkdir -p $client_log_dir
        
        # Run each client in background
        (
            timeout 300 $CLIENT_BIN -host $SERVER_HOST -port $SERVER_PORT -log-dir "$client_log_dir" > "$RESULTS_DIR/${scenario_name}_client${i}.log" 2>&1 <<EOF
put $TEST_FILE
quit
EOF
        ) &
        
        pids+=($!)
        print_status "Started client $i (PID: $!)"
        
        # Small delay between client starts
        sleep 0.5
    done
    
    # Wait for all clients to complete
    print_status "Waiting for all clients to complete..."
    local failed=0
    for pid in "${pids[@]}"; do
        if ! wait $pid; then
            print_warning "Client (PID: $pid) failed or timed out"
            failed=$((failed + 1))
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        print_success "All clients completed successfully"
    else
        print_warning "$failed clients failed"
    fi
}

# Function to apply network conditions
apply_network_conditions() {
    local condition_type=$1
    local interface=${2:-"lo"}
    
    case $condition_type in
        "clean")
            print_status "Applying clean network conditions..."
            sudo ./scripts/network-emulation.sh clear $interface 2>/dev/null || {
                print_warning "Failed to clear network conditions (may not have permissions)"
            }
            ;;
        "loss")
            print_status "Applying packet loss conditions ($PACKET_LOSS)..."
            sudo ./scripts/network-emulation.sh setup-loss $interface $PACKET_LOSS || {
                print_warning "Failed to apply packet loss (may not have permissions)"
            }
            ;;
        "delay")
            print_status "Applying network delay conditions ($NETWORK_DELAY)..."
            sudo ./scripts/network-emulation.sh setup-delay $interface $NETWORK_DELAY || {
                print_warning "Failed to apply network delay (may not have permissions)"
            }
            ;;
        "combined")
            print_status "Applying combined network conditions..."
            sudo ./scripts/network-emulation.sh setup-combined $interface $BANDWIDTH_LIMIT $NETWORK_DELAY $PACKET_LOSS || {
                print_warning "Failed to apply combined conditions (may not have permissions)"
            }
            ;;
    esac
}

# Function to run a complete test scenario
run_scenario() {
    local scenario_num=$1
    local scenario_name=$2
    local network_condition=$3
    local client_mode=$4
    local num_clients=${5:-3}
    
    print_status "========================================="
    print_status "Running Scenario $scenario_num: $scenario_name"
    print_status "========================================="
    
    # Setup
    apply_network_conditions $network_condition
    start_packet_capture "scenario${scenario_num}"
    
    if ! start_server "scenario${scenario_num}"; then
        print_error "Failed to start server for scenario $scenario_num"
        return 1
    fi
    
    # Run the actual test
    case $client_mode in
        "single")
            run_single_client "scenario${scenario_num}"
            ;;
        "multiple")
            run_multiple_clients "scenario${scenario_num}" $num_clients
            ;;
    esac
    
    # Cleanup
    stop_server
    stop_packet_capture
    
    # Clear network conditions
    apply_network_conditions "clean"
    
    print_success "Scenario $scenario_num completed"
    echo ""
}

# Function to generate summary report
generate_summary() {
    print_status "Generating test summary..."
    
    local summary_file="$RESULTS_DIR/test_summary.txt"
    
    cat > $summary_file <<EOF
TCP Congestion Control Test Results Summary
==========================================
Generated: $(date)
Test File Size: $TEST_FILE_SIZE

Scenarios Executed:
1. Single client, clean network
2. Multiple clients (3), clean network  
3. Single client with packet loss ($PACKET_LOSS)
4. Multiple clients (3) with packet loss ($PACKET_LOSS)

Files Generated:
- Connection logs: $LOGS_DIR/
- Client outputs: $RESULTS_DIR/
- Packet captures: $PCAP_DIR/

Analysis Instructions:
1. Open packet captures in Wireshark
2. Apply filters for TCP analysis:
   - tcp.analysis.retransmission
   - tcp.analysis.fast_retransmission  
   - tcp.analysis.duplicate_ack
3. Generate TCP stream graphs for congestion window analysis
4. Review connection logs for TCP_INFO metrics

EOF

    print_success "Summary generated: $summary_file"
}

# Main execution function
main() {
    local interface=${1:-"lo"} # Allow interface to be specified
    
    echo "TCP Congestion Control Benchmark Test Suite"
    echo "==========================================="
    echo ""
    
    # Check if running as root for network emulation
    if [[ $EUID -ne 0 ]] && [[ "$2" != "--no-netem" ]]; then
        print_warning "Not running as root - network emulation will be skipped"
        print_warning "Run with sudo for full network emulation, or add --no-netem to skip"
        echo ""
    fi
    
    # Setup
    setup_test_environment
    
    # Run all 4 scenarios
    run_scenario 1 "Single client, clean network" "clean" "single"
    run_scenario 2 "Multiple clients, clean network" "clean" "multiple" 3
    run_scenario 3 "Single client with packet loss" "loss" "single"  
    run_scenario 4 "Multiple clients with packet loss" "loss" "multiple" 3
    
    # Generate summary
    generate_summary
    
    print_success "All test scenarios completed!"
    print_status "Results available in: $RESULTS_DIR"
    print_status "Logs available in: $LOGS_DIR"
    print_status "Packet captures available in: $PCAP_DIR"
}

# Handle script arguments
case "${1:-}" in
    "-h"|"--help")
        echo "Usage: $0 [interface] [--no-netem]"
        echo ""
        echo "Arguments:"
        echo "  interface    Network interface for emulation (default: lo)"
        echo "  --no-netem   Skip network emulation (for systems without tc/netem)"
        echo ""
        echo "Examples:"
        echo "  sudo $0                    # Run with loopback interface"
        echo "  sudo $0 eth0              # Run with eth0 interface"
        echo "  $0 lo --no-netem          # Run without network emulation"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
