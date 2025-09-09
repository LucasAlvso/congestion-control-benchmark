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

	// Send PUT frame
	frame := protocol.CreatePutFrame(filename, fileData)
	if err := protocol.WriteFrame(conn, frame); err != nil {
		fmt.Printf("Failed to send PUT: %v\n", err)
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
		fmt.Printf("File %s uploaded successfully\n", filename)
	}

	// Log connection
	log := &common.ConnectionLog{
		StartTime:     startTime,
		EndTime:       endTime,
		BytesSent:     int64(5 + len(frame.Payload)), // opcode + length + payload
		BytesReceived: int64(5 + len(response.Payload)),
		RemoteAddr:    address,
		Operation:     fmt.Sprintf("PUT %s", filename),
	}
	logger.LogConnection(log)
	logger.PrintSummary(log)
}
