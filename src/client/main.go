package main

import (
	"bufio"
	"flag"
	"fmt"
	"io"
	"net"
	"os"
	"strings"
	"time"

	"tcp-congestion-benchmark/src/common"
	"tcp-congestion-benchmark/src/protocol"
)

func main() {
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

	// Open file for streaming
	f, err := os.Open(filename)
	if err != nil {
		fmt.Printf("Failed to open file %s: %v\n", filename, err)
		return
	}
	defer f.Close()

	fi, err := f.Stat()
	if err != nil {
		fmt.Printf("Failed to stat file %s: %v\n", filename, err)
		return
	}
	filesize := fi.Size()

	conn, err := net.Dial("tcp", address)
	if err != nil {
		fmt.Printf("Failed to connect: %v\n", err)
		return
	}
	defer conn.Close()

	// Initialize TCP_INFO collector
	tcpCollector := common.NewTCPInfoCollector()
	tcpCollector.CollectSample(conn)

	filenameBytes := []byte(filename)
	shouldSample := filesize > 1024*1024
	done := make(chan bool)

	// Validate payload fits in uint32
	if filesize > int64(^uint32(0))-int64(4+len(filenameBytes)) {
		fmt.Printf("File %s is too large to send\n", filename)
		if shouldSample {
			close(done)
		}
		return
	}
	payloadLen := uint32(4 + len(filenameBytes) + int(filesize))

	// Start sampling goroutine for large files
	if shouldSample {
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

	// Read entire file into memory
	fileData := make([]byte, filesize)
	if _, err := f.Seek(0, io.SeekStart); err != nil {
		fmt.Printf("Failed to seek file: %v\n", err)
		if shouldSample {
			close(done)
		}
		return
	}
	if _, err := io.ReadFull(f, fileData); err != nil {
		fmt.Printf("Failed to read file into memory: %v\n", err)
		if shouldSample {
			close(done)
		}
		return
	}

	// Create and send PUT frame in a single transfer
	frame := protocol.CreatePutFrame(filename, fileData)
	if err := protocol.WriteFrame(conn, frame); err != nil {
		fmt.Printf("Failed to send PUT frame: %v\n", err)
		if shouldSample {
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
		if shouldSample {
			close(done)
		}
		return
	}

	// Stop sampling goroutine
	if shouldSample {
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
		BytesSent:     int64(5) + int64(payloadLen), // opcode + length (5) + payload
		BytesReceived: int64(5) + int64(len(response.Payload)),
		RemoteAddr:    address,
		Operation:     fmt.Sprintf("PUT %s", filename),
		TCPSamples:    tcpCollector.GetSamples(),
	}
	logger.LogConnection(log)
	logger.PrintSummary(log)
}
