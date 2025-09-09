package common

import (
	"encoding/json"
	"fmt"
	"os"
	"time"
)

// ConnectionLog represents a connection's performance metrics
type ConnectionLog struct {
	StartTime     time.Time `json:"start_time"`
	EndTime       time.Time `json:"end_time"`
	BytesSent     int64     `json:"bytes_sent"`
	BytesReceived int64     `json:"bytes_received"`
	Duration      float64   `json:"duration_seconds"`
	Throughput    float64   `json:"throughput_bps"`
	RemoteAddr    string    `json:"remote_addr"`
	Operation     string    `json:"operation"`
}

// Logger handles connection logging
type Logger struct {
	logDir string
}

// NewLogger creates a new logger instance
func NewLogger(logDir string) *Logger {
	// Create log directory if it doesn't exist
	os.MkdirAll(logDir, 0755)
	return &Logger{logDir: logDir}
}

// LogConnection saves connection metrics to a JSON file
func (l *Logger) LogConnection(log *ConnectionLog) error {
	// Calculate derived metrics
	log.Duration = log.EndTime.Sub(log.StartTime).Seconds()
	if log.Duration > 0 {
		log.Throughput = float64(log.BytesSent+log.BytesReceived) / log.Duration
	}

	// Create filename with timestamp
	filename := fmt.Sprintf("%s/connection_%s.json",
		l.logDir,
		log.StartTime.Format("20060102_150405"))

	// Write to file
	file, err := os.Create(filename)
	if err != nil {
		return fmt.Errorf("failed to create log file: %v", err)
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(log); err != nil {
		return fmt.Errorf("failed to encode log: %v", err)
	}

	fmt.Printf("Connection log saved: %s\n", filename)
	return nil
}

// PrintSummary prints connection summary to console
func (l *Logger) PrintSummary(log *ConnectionLog) {
	fmt.Printf("\n=== Connection Summary ===\n")
	fmt.Printf("Remote: %s\n", log.RemoteAddr)
	fmt.Printf("Operation: %s\n", log.Operation)
	fmt.Printf("Duration: %.2f seconds\n", log.Duration)
	fmt.Printf("Bytes Sent: %d\n", log.BytesSent)
	fmt.Printf("Bytes Received: %d\n", log.BytesReceived)
	fmt.Printf("Throughput: %.2f bytes/sec\n", log.Throughput)
	fmt.Printf("========================\n\n")
}
