package common

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
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
	Scenario      string    `json:"scenario,omitempty"`
	ContainerName string    `json:"container_name,omitempty"`
	TCPSamples    []TCPInfo `json:"tcp_samples,omitempty"` // TCP_INFO samples collected during connection
}

// Logger handles connection logging
type Logger struct {
	logDir        string
	scenario      string
	containerName string
}

// NewLogger creates a new logger instance
func NewLogger(logDir string) *Logger {
	// Create log directory if it doesn't exist
	os.MkdirAll(logDir, 0755)

	// Read scenario and container name from environment if provided.
	// Fallback for container name: use HOSTNAME if set.
	scenario := os.Getenv("SCENARIO")
	container := os.Getenv("CONTAINER_NAME")
	if container == "" {
		container = os.Getenv("HOSTNAME")
	}

	// If scenario wasn't provided via env, try reading a marker file inside the log dir.
	if scenario == "" {
		if b, err := os.ReadFile(filepath.Join(logDir, ".scenario")); err == nil {
			scenario = strings.TrimSpace(string(b))
		}
	}

	// If container name still empty, try reading a marker file inside the log dir.
	if container == "" {
		if b, err := os.ReadFile(filepath.Join(logDir, ".container_name")); err == nil {
			container = strings.TrimSpace(string(b))
		}
	}

	return &Logger{
		logDir:        logDir,
		scenario:      scenario,
		containerName: container,
	}
}

// LogConnection saves connection metrics to a JSON file
func (l *Logger) LogConnection(log *ConnectionLog) error {
	// Ensure scenario/container metadata is present in the log (prefer explicit values on the struct)
	if log.Scenario == "" {
		log.Scenario = l.scenario
	}
	if log.ContainerName == "" {
		log.ContainerName = l.containerName
	}

	// Calculate derived metrics
	log.Duration = log.EndTime.Sub(log.StartTime).Seconds()
	if log.Duration > 0 {
		log.Throughput = float64(log.BytesSent+log.BytesReceived) / log.Duration
	}

	// Create filename with timestamp — include scenario and container name (sanitized)
	sanitize := func(s string) string {
		if s == "" {
			return "unknown"
		}
		// replace characters that could break filenames
		s = strings.ReplaceAll(s, " ", "_")
		s = strings.ReplaceAll(s, "/", "_")
		s = strings.ReplaceAll(s, ":", "_")
		s = strings.ReplaceAll(s, "\\", "_")
		return s
	}

	// Ensure we write logs under the per-scenario folder inside the shared log directory.
	scenarioName := sanitize(log.Scenario)
	scenarioDir := filepath.Join(l.logDir, scenarioName)
	if err := os.MkdirAll(scenarioDir, 0755); err != nil {
		return fmt.Errorf("failed to create scenario log dir: %v", err)
	}

	filename := filepath.Join(scenarioDir, fmt.Sprintf("connection_%s_%s_%s.json",
		scenarioName,
		sanitize(log.ContainerName),
		log.StartTime.Format("20060102_150405")))

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

	// Show TCP_INFO summary if available
	if len(log.TCPSamples) > 0 {
		fmt.Printf("\n--- TCP Metrics Summary ---\n")
		fmt.Printf("TCP Samples Collected: %d\n", len(log.TCPSamples))

		// Show first and last sample for comparison
		first := log.TCPSamples[0]
		last := log.TCPSamples[len(log.TCPSamples)-1]

		fmt.Printf("Initial RTT: %.2f ms, Final RTT: %.2f ms\n",
			float64(first.RTT)/1000.0, float64(last.RTT)/1000.0)
		fmt.Printf("Initial cwnd: %d, Final cwnd: %d\n",
			first.SndCwnd, last.SndCwnd)
		fmt.Printf("Initial ssthresh: %d, Final ssthresh: %d\n",
			first.SndSsthresh, last.SndSsthresh)
		fmt.Printf("Total Retransmissions: %d\n", last.TotalRetrans)
		fmt.Printf("---------------------------\n")
	}

	fmt.Printf("========================\n\n")
}
