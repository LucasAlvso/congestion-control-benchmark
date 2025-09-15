package main

import (
	"bufio"
	"flag"
	"fmt"
	"io/ioutil"
	"net"
	"os"
	"strings"
	"time"

	"tcp-congestion-benchmark/src/common"
	"tcp-congestion-benchmark/src/protocol"
)

func main() {
	// Command line flags
	host := flag.String("host", "localhost", "Server host")
	port := flag.String("port", "8080", "Server port")
	logDir := flag.String("log-dir", "./logs", "Log directory")
	flag.Parse()

	logger := common.NewLogger(*logDir)
	address := fmt.Sprintf("%s:%s", *host, *port)

	fmt.Printf("TCP File Transfer Client\n")
	fmt.Printf("Server: %s\n", address)
	fmt.Printf("Commands: list, put <filename>, quit\n\n")

	scanner := bufio.NewScanner(os.Stdin)
	for {
		fmt.Print("> ")
		if !scanner.Scan() {
			break
		}

		command := strings.TrimSpace(scanner.Text())
		if command == "" {
			continue
		}

		parts := strings.Fields(command)
		switch parts[0] {
		case "list":
			handleList(address, logger)
		case "put":
			if len(parts) < 2 {
				fmt.Println("Usage: put <filename>")
				continue
			}
			handlePut(address, parts[1], logger)
		case "quit":
			fmt.Println("Goodbye!")
			return
		default:
			fmt.Printf("Unknown command: %s\n", parts[0])
		}
	}
}

func handleList(address string, logger *common.Logger) {
	startTime := time.Now()

	conn, err := net.Dial("tcp", address)
	if err != nil {
		fmt.Printf("Failed to connect: %v\n", err)
		return
	}
	defer conn.Close()

	// Send LIST frame
	frame := protocol.CreateListFrame()
	if err := protocol.WriteFrame(conn, frame); err != nil {
		fmt.Printf("Failed to send LIST: %v\n", err)
		return
	}

	// Read response
	response, err := protocol.ReadFrame(conn)
	if err != nil {
		fmt.Printf("Failed to read response: %v\n", err)
		return
	}

	endTime := time.Now()

	if response.OpCode == protocol.OpError {
		fmt.Printf("Server error: %s\n", string(response.Payload))
	} else {
		fmt.Printf("Files on server:\n%s\n", string(response.Payload))
	}

	// Log connection
	log := &common.ConnectionLog{
		StartTime:     startTime,
		EndTime:       endTime,
		BytesSent:     5, // opcode + payload length
		BytesReceived: int64(5 + len(response.Payload)),
		RemoteAddr:    address,
		Operation:     "LIST",
	}
	logger.LogConnection(log)
	logger.PrintSummary(log)
}

func handlePut(address string, filename string, logger *common.Logger) {
	startTime := time.Now()

	// Read file
	fileData, err := ioutil.ReadFile(filename)
	if err != nil {
		fmt.Printf("Failed to read file %s: %v\n", filename, err)
		return
	}

	conn, err := net.Dial("tcp", address)
	if err != nil {
		fmt.Printf("Failed to connect: %v\n", err)
		return
	}
	defer conn.Close()

	// Initialize TCP_INFO collector
	tcpCollector := common.NewTCPInfoCollector()

	// Collect initial TCP_INFO sample
	tcpCollector.CollectSample(conn)

	// Send PUT frame with periodic TCP_INFO sampling
	frame := protocol.CreatePutFrame(filename, fileData)

	// For large files, collect samples during transmission
	done := make(chan bool)
	if len(fileData) > 1024*1024 { // Files larger than 1MB
		go func() {
			ticker := time.NewTicker(100 * time.Millisecond) // Sample every 100ms
			defer ticker.Stop()

			for {
				select {
				case <-ticker.C:
					tcpCollector.CollectSample(conn)
				case <-done:
					return
				}
			}
		}()
	}

	if err := protocol.WriteFrame(conn, frame); err != nil {
		fmt.Printf("Failed to send PUT: %v\n", err)
		if len(fileData) > 1024*1024 {
			close(done)
		}
		return
	}

	// Collect sample after sending
	tcpCollector.CollectSample(conn)

	// Read response
	response, err := protocol.ReadFrame(conn)
	if err != nil {
		fmt.Printf("Failed to read response: %v\n", err)
		if len(fileData) > 1024*1024 {
			close(done)
		}
		return
	}

	// Stop sampling goroutine
	if len(fileData) > 1024*1024 {
		close(done)
	}

	// Collect final sample
	tcpCollector.CollectSample(conn)

	endTime := time.Now()

	if response.OpCode == protocol.OpError {
		fmt.Printf("Server error: %s\n", string(response.Payload))
	} else {
		fmt.Printf("File %s uploaded successfully\n", filename)
	}

	// Log connection with TCP_INFO samples
	log := &common.ConnectionLog{
		StartTime:     startTime,
		EndTime:       endTime,
		BytesSent:     int64(5 + len(frame.Payload)), // opcode + length + payload
		BytesReceived: int64(5 + len(response.Payload)),
		RemoteAddr:    address,
		Operation:     fmt.Sprintf("PUT %s", filename),
		TCPSamples:    tcpCollector.GetSamples(),
	}
	logger.LogConnection(log)
	logger.PrintSummary(log)
}
