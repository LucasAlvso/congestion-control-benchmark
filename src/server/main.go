package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"net"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"tcp-congestion-benchmark/src/common"
	"tcp-congestion-benchmark/src/protocol"
)

func main() {
	// Command line flags
	host := flag.String("host", "0.0.0.0", "Server host")
	port := flag.String("port", "8080", "Server port")
	fileDir := flag.String("file-dir", "./files", "File storage directory")
	logDir := flag.String("log-dir", "./logs", "Log directory")
	flag.Parse()

	// Create file directory if it doesn't exist
	if err := os.MkdirAll(*fileDir, 0755); err != nil {
		fmt.Printf("Failed to create file directory: %v\n", err)
		return
	}

	logger := common.NewLogger(*logDir)
	address := fmt.Sprintf("%s:%s", *host, *port)

	// Start server
	listener, err := net.Listen("tcp", address)
	if err != nil {
		fmt.Printf("Failed to listen on %s: %v\n", address, err)
		return
	}
	defer listener.Close()

	fmt.Printf("TCP File Transfer Server\n")
	fmt.Printf("Listening on: %s\n", address)
	fmt.Printf("File directory: %s\n", *fileDir)
	fmt.Printf("Log directory: %s\n", *logDir)

	// Handle graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		fmt.Println("\nShutting down server...")
		listener.Close()
		os.Exit(0)
	}()

	// Accept connections
	for {
		conn, err := listener.Accept()
		if err != nil {
			fmt.Printf("Failed to accept connection: %v\n", err)
			continue
		}

		// Handle connection concurrently
		go handleConnection(conn, *fileDir, logger)
	}
}

func handleConnection(conn net.Conn, fileDir string, logger *common.Logger) {
	defer conn.Close()
	startTime := time.Now()
	remoteAddr := conn.RemoteAddr().String()

	fmt.Printf("New connection from: %s\n", remoteAddr)

	var totalBytesSent, totalBytesReceived int64
	var lastOperation string = "CONNECT"

	for {
		// Read frame from client
		frame, err := protocol.ReadFrame(conn)
		if err != nil {
			fmt.Printf("Connection %s closed: %v\n", remoteAddr, err)
			break
		}

		totalBytesReceived += int64(5 + len(frame.Payload))

		var response *protocol.Frame

		switch frame.OpCode {
		case protocol.OpList:
			lastOperation = "LIST"
			response = handleListRequest(fileDir)
		case protocol.OpPut:
			lastOperation = "PUT"
			response = handlePutRequest(frame, fileDir)
		case protocol.OpQuit:
			lastOperation = "QUIT"
			response = &protocol.Frame{OpCode: protocol.OpQuit, PayloadLen: 0}
			fmt.Printf("Client %s requested quit\n", remoteAddr)
		default:
			lastOperation = "UNKNOWN"
			response = protocol.CreateErrorFrame("Unknown operation")
		}

		// Send response
		if err := protocol.WriteFrame(conn, response); err != nil {
			fmt.Printf("Failed to send response to %s: %v\n", remoteAddr, err)
			break
		}

		totalBytesSent += int64(5 + len(response.Payload))

		// If client sent QUIT, close connection
		if frame.OpCode == protocol.OpQuit {
			break
		}
	}

	endTime := time.Now()

	// Log connection
	log := &common.ConnectionLog{
		StartTime:     startTime,
		EndTime:       endTime,
		BytesSent:     totalBytesSent,
		BytesReceived: totalBytesReceived,
		RemoteAddr:    remoteAddr,
		Operation:     lastOperation,
	}
	logger.LogConnection(log)
	logger.PrintSummary(log)
}

func handleListRequest(fileDir string) *protocol.Frame {
	files, err := ioutil.ReadDir(fileDir)
	if err != nil {
		return protocol.CreateErrorFrame(fmt.Sprintf("Failed to list files: %v", err))
	}

	var fileList []string
	for _, file := range files {
		if !file.IsDir() {
			fileList = append(fileList, fmt.Sprintf("%s (%d bytes)", file.Name(), file.Size()))
		}
	}

	if len(fileList) == 0 {
		return &protocol.Frame{
			OpCode:     protocol.OpList,
			PayloadLen: uint32(len("No files found")),
			Payload:    []byte("No files found"),
		}
	}

	response := strings.Join(fileList, "\n")
	return &protocol.Frame{
		OpCode:     protocol.OpList,
		PayloadLen: uint32(len(response)),
		Payload:    []byte(response),
	}
}

func handlePutRequest(frame *protocol.Frame, fileDir string) *protocol.Frame {
	filename, fileData, err := protocol.ParsePutFrame(frame)
	if err != nil {
		return protocol.CreateErrorFrame(fmt.Sprintf("Invalid PUT request: %v", err))
	}

	// Clean filename to prevent directory traversal
	filename = filepath.Base(filename)
	filePath := filepath.Join(fileDir, filename)

	// Check if file already exists
	if _, err := os.Stat(filePath); err == nil {
		return protocol.CreateErrorFrame(fmt.Sprintf("File %s already exists", filename))
	}

	// Write file
	if err := ioutil.WriteFile(filePath, fileData, 0644); err != nil {
		return protocol.CreateErrorFrame(fmt.Sprintf("Failed to save file: %v", err))
	}

	fmt.Printf("File saved: %s (%d bytes)\n", filename, len(fileData))

	response := fmt.Sprintf("File %s uploaded successfully (%d bytes)", filename, len(fileData))
	return &protocol.Frame{
		OpCode:     protocol.OpPut,
		PayloadLen: uint32(len(response)),
		Payload:    []byte(response),
	}
}
