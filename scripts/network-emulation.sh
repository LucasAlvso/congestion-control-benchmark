#!/bin/bash

# Network emulation script using tc/netem for TCP congestion control testing
# Usage: ./network-emulation.sh <action> <interface> [options]
#
# Actions:
#   setup-bandwidth <interface> <rate>     - Set bandwidth limit (e.g., 10mbit)
#   setup-delay <interface> <delay>        - Set network delay (e.g., 50ms)
#   setup-loss <interface> <loss_rate>     - Set packet loss (e.g., 0.1%)
#   setup-combined <interface> <rate> <delay> <loss> - Combined setup
#   clear <interface>                      - Remove all rules
#   status <interface>                     - Show current rules

set -e

ACTION=$1
INTERFACE=$2

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <action> <interface> [options]"
    echo ""
    echo "Actions:"
    echo "  setup-bandwidth <interface> <rate>     - Set bandwidth limit (e.g., 10mbit)"
    echo "  setup-delay <interface> <delay>        - Set network delay (e.g., 50ms)"
    echo "  setup-loss <interface> <loss_rate>     - Set packet loss (e.g., 0.1%)"
    echo "  setup-combined <interface> <rate> <delay> <loss> - Combined setup"
    echo "  clear <interface>                      - Remove all rules"
    echo "  status <interface>                     - Show current rules"
    echo ""
    echo "Examples:"
    echo "  $0 setup-bandwidth eth0 10mbit"
    echo "  $0 setup-delay eth0 50ms"
    echo "  $0 setup-loss eth0 0.1%"
    echo "  $0 setup-combined eth0 10mbit 50ms 0.1%"
    echo "  $0 clear eth0"
    exit 1
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

# Function to clear existing rules
clear_rules() {
    local iface=$1
    echo "Clearing existing tc rules on $iface..."
    tc qdisc del dev $iface root 2>/dev/null || true
    echo "Rules cleared."
}

# Function to show current rules
show_status() {
    local iface=$1
    echo "Current tc rules on $iface:"
    tc qdisc show dev $iface
    echo ""
    tc class show dev $iface 2>/dev/null || true
}

case $ACTION in
    "setup-bandwidth")
        if [[ $# -ne 3 ]]; then
            echo "Usage: $0 setup-bandwidth <interface> <rate>"
            exit 1
        fi
        
        RATE=$3
        echo "Setting up bandwidth limitation: $RATE on $INTERFACE"
        
        clear_rules $INTERFACE
        
        # Set up HTB (Hierarchical Token Bucket) for bandwidth control
        tc qdisc add dev $INTERFACE root handle 1: htb default 10
        tc class add dev $INTERFACE parent 1: classid 1:10 htb rate $RATE ceil $RATE
        
        echo "Bandwidth limit set to $RATE"
        ;;
        
    "setup-delay")
        if [[ $# -ne 3 ]]; then
            echo "Usage: $0 setup-delay <interface> <delay>"
            exit 1
        fi
        
        DELAY=$3
        echo "Setting up network delay: $DELAY on $INTERFACE"
        
        clear_rules $INTERFACE
        
        # Set up netem for delay
        tc qdisc add dev $INTERFACE root netem delay $DELAY
        
        echo "Network delay set to $DELAY"
        ;;
        
    "setup-loss")
        if [[ $# -ne 3 ]]; then
            echo "Usage: $0 setup-loss <interface> <loss_rate>"
            exit 1
        fi
        
        LOSS=$3
        echo "Setting up packet loss: $LOSS on $INTERFACE"
        
        clear_rules $INTERFACE
        
        # Set up netem for packet loss
        tc qdisc add dev $INTERFACE root netem loss $LOSS
        
        echo "Packet loss set to $LOSS"
        ;;
        
    "setup-combined")
        if [[ $# -ne 5 ]]; then
            echo "Usage: $0 setup-combined <interface> <rate> <delay> <loss>"
            exit 1
        fi
        
        RATE=$3
        DELAY=$4
        LOSS=$5
        echo "Setting up combined network conditions on $INTERFACE:"
        echo "  Bandwidth: $RATE"
        echo "  Delay: $DELAY"
        echo "  Loss: $LOSS"
        
        clear_rules $INTERFACE
        
        # Set up HTB for bandwidth control
        tc qdisc add dev $INTERFACE root handle 1: htb default 10
        tc class add dev $INTERFACE parent 1: classid 1:10 htb rate $RATE ceil $RATE
        
        # Add netem for delay and loss as child of HTB
        tc qdisc add dev $INTERFACE parent 1:10 handle 10: netem delay $DELAY loss $LOSS
        
        echo "Combined network conditions applied successfully"
        ;;
        
    "clear")
        clear_rules $INTERFACE
        ;;
        
    "status")
        show_status $INTERFACE
        ;;
        
    *)
        echo "Unknown action: $ACTION"
        echo "Available actions: setup-bandwidth, setup-delay, setup-loss, setup-combined, clear, status"
        exit 1
        ;;
esac

echo "Operation completed. Use '$0 status $INTERFACE' to verify."
