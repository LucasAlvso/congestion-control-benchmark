package main

import (
	"encoding/csv"
	"encoding/json"
	"flag"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// Mirror struct fields we care about from connection JSON
// Only include metrics relevant for the report.
type ConnectionLog struct {
	StartTime            time.Time   `json:"start_time"`
	EndTime              time.Time   `json:"end_time"`
	BytesSent            int64       `json:"bytes_sent"`
	BytesReceived        int64       `json:"bytes_received"`
	Duration             float64     `json:"duration_seconds"`
	Throughput           float64     `json:"throughput_bps"`
	RemoteAddr           string      `json:"remote_addr"`
	Operation            string      `json:"operation"`
	Scenario             string      `json:"scenario"`
	ContainerName        string      `json:"container_name"`
	InitialRTTMs         float64     `json:"initial_rtt_ms"`
	FinalRTTMs           float64     `json:"final_rtt_ms"`
	InitialCwnd          uint32      `json:"initial_cwnd"`
	FinalCwnd            uint32      `json:"final_cwnd"`
	InitialSsthresh      uint32      `json:"initial_ssthresh"`
	FinalSsthresh        uint32      `json:"final_ssthresh"`
	TotalRetransmissions uint32      `json:"total_retransmissions"`
	TCPSamples           []TCPSample `json:"tcp_samples"`
}

// Subset of TCP sample fields
type TCPSample struct {
	Timestamp    time.Time `json:"timestamp"`
	RTT          uint32    `json:"rtt_us"`
	RTTVar       uint32    `json:"rtt_var_us"`
	SndCwnd      uint32    `json:"snd_cwnd"`
	SndSsthresh  uint32    `json:"snd_ssthresh"`
	TotalRetrans uint32    `json:"total_retrans"`
}

func main() {
	logsDir := flag.String("logs", "./logs", "Root logs directory (scenarios inside)")
	outFile := flag.String("out", "connection_summary.csv", "Per-connection output CSV filename")
	scenarioOut := flag.String("scenario-out", "scenario_aggregate.csv", "Scenario-level aggregated CSV filename")
	includeSamples := flag.Bool("samples", true, "Include averaged TCP sample metrics (mean RTT, cwnd, ssthresh, retrans deltas)")
	flag.Parse()

	var logFiles []string
	// Walk logs directory for connection_*.json
	filepath.WalkDir(*logsDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if d.IsDir() {
			return nil
		}
		name := d.Name()
		if strings.HasPrefix(name, "connection_") && strings.HasSuffix(name, ".json") {
			logFiles = append(logFiles, path)
		}
		return nil
	})

	if len(logFiles) == 0 {
		fmt.Fprintf(os.Stderr, "No connection log files found under %s\n", *logsDir)
		os.Exit(1)
	}

	// Stable order for reproducibility
	sort.Strings(logFiles)

	// Per-connection CSV
	out, err := os.Create(*outFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create output: %v\n", err)
		os.Exit(1)
	}
	defer out.Close()
	w := csv.NewWriter(out)
	defer w.Flush()
	head := []string{"scenario", "container", "operation", "start_time", "end_time", "duration_s", "bytes_sent", "bytes_received", "throughput_Bps", "init_rtt_ms", "final_rtt_ms", "init_cwnd", "final_cwnd", "init_ssthresh", "final_ssthresh", "total_retrans"}
	if *includeSamples {
		head = append(head, "mean_rtt_ms", "mean_cwnd", "mean_ssthresh", "mean_retrans_rate_per_s")
	}
	w.Write(head)

	// Aggregation structures
	type agg struct {
		connections      int
		sumDuration      float64
		sumBytesSent     int64
		sumBytesRecv     int64
		sumThroughput    float64
		sumInitRTT       float64
		sumFinalRTT      float64
		sumInitCwnd      float64
		sumFinalCwnd     float64
		sumInitSsthresh  float64
		sumFinalSsthresh float64
		sumTotalRetrans  float64
		sumMeanRTT       float64
		sumMeanCwnd      float64
		sumMeanSsthresh  float64
		sumRetransRate   float64
	}
	scenarioAgg := make(map[string]*agg)

	for _, f := range logFiles {
		data, err := os.ReadFile(f)
		if err != nil {
			continue
		}
		var cl ConnectionLog
		if err := json.Unmarshal(data, &cl); err != nil {
			continue
		}

		meanRTTms := 0.0
		meanCwnd := 0.0
		meanSsthresh := 0.0
		retransRate := 0.0
		if *includeSamples && len(cl.TCPSamples) > 0 && cl.Duration > 0 {
			var sumRTT float64
			var sumCwnd float64
			var sumSsthresh float64
			for _, s := range cl.TCPSamples {
				sumRTT += float64(s.RTT) / 1000.0
				sumCwnd += float64(s.SndCwnd)
				sumSsthresh += float64(s.SndSsthresh)
			}
			N := float64(len(cl.TCPSamples))
			meanRTTms = sumRTT / N
			meanCwnd = sumCwnd / N
			meanSsthresh = sumSsthresh / N
			first := cl.TCPSamples[0].TotalRetrans
			last := cl.TCPSamples[len(cl.TCPSamples)-1].TotalRetrans
			retransRate = float64(last-first) / cl.Duration
		}

		row := []string{
			cl.Scenario,
			cl.ContainerName,
			cl.Operation,
			cl.StartTime.Format(time.RFC3339),
			cl.EndTime.Format(time.RFC3339),
			fmt.Sprintf("%.3f", cl.Duration),
			fmt.Sprintf("%d", cl.BytesSent),
			fmt.Sprintf("%d", cl.BytesReceived),
			fmt.Sprintf("%.2f", cl.Throughput),
			fmt.Sprintf("%.3f", cl.InitialRTTMs),
			fmt.Sprintf("%.3f", cl.FinalRTTMs),
			fmt.Sprintf("%d", cl.InitialCwnd),
			fmt.Sprintf("%d", cl.FinalCwnd),
			fmt.Sprintf("%d", cl.InitialSsthresh),
			fmt.Sprintf("%d", cl.FinalSsthresh),
			fmt.Sprintf("%d", cl.TotalRetransmissions),
		}
		if *includeSamples {
			row = append(row,
				fmt.Sprintf("%.3f", meanRTTms),
				fmt.Sprintf("%.2f", meanCwnd),
				fmt.Sprintf("%.2f", meanSsthresh),
				fmt.Sprintf("%.5f", retransRate),
			)
		}
		w.Write(row)

		// Scenario aggregation (focus on *client* containers)
		if strings.Contains(strings.ToLower(cl.ContainerName), "client") {
			a := scenarioAgg[cl.Scenario]
			if a == nil {
				a = &agg{}
				scenarioAgg[cl.Scenario] = a
			}
			a.connections++
			a.sumDuration += cl.Duration
			a.sumBytesSent += cl.BytesSent
			a.sumBytesRecv += cl.BytesReceived
			a.sumThroughput += cl.Throughput
			a.sumInitRTT += cl.InitialRTTMs
			a.sumFinalRTT += cl.FinalRTTMs
			a.sumInitCwnd += float64(cl.InitialCwnd)
			a.sumFinalCwnd += float64(cl.FinalCwnd)
			a.sumInitSsthresh += float64(cl.InitialSsthresh)
			a.sumFinalSsthresh += float64(cl.FinalSsthresh)
			a.sumTotalRetrans += float64(cl.TotalRetransmissions)
			if *includeSamples {
				a.sumMeanRTT += meanRTTms
				a.sumMeanCwnd += meanCwnd
				a.sumMeanSsthresh += meanSsthresh
				a.sumRetransRate += retransRate
			}
		}
	}

	if err := w.Error(); err != nil {
		fmt.Fprintf(os.Stderr, "CSV write error (per-connection): %v\n", err)
		os.Exit(1)
	}

	// Scenario aggregate CSV
	out2, err := os.Create(*scenarioOut)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create scenario output: %v\n", err)
		os.Exit(1)
	}
	defer out2.Close()
	w2 := csv.NewWriter(out2)
	defer w2.Flush()
	head2 := []string{"scenario", "client_connections", "avg_duration_s", "sum_bytes_sent", "sum_bytes_received", "avg_throughput_Bps", "avg_init_rtt_ms", "avg_final_rtt_ms", "avg_init_cwnd", "avg_final_cwnd", "avg_init_ssthresh", "avg_final_ssthresh", "avg_total_retrans"}
	if *includeSamples {
		head2 = append(head2, "avg_mean_rtt_ms", "avg_mean_cwnd", "avg_mean_ssthresh", "avg_retrans_rate_per_s")
	}
	w2.Write(head2)

	// Stable order of scenarios
	var scenarios []string
	for s := range scenarioAgg {
		scenarios = append(scenarios, s)
	}
	sort.Strings(scenarios)
	for _, s := range scenarios {
		a := scenarioAgg[s]
		c := float64(a.connections)
		if c == 0 {
			continue
		}
		row := []string{
			s,
			fmt.Sprintf("%d", a.connections),
			fmt.Sprintf("%.3f", a.sumDuration/c),
			fmt.Sprintf("%d", a.sumBytesSent),
			fmt.Sprintf("%d", a.sumBytesRecv),
			fmt.Sprintf("%.2f", a.sumThroughput/c),
			fmt.Sprintf("%.3f", a.sumInitRTT/c),
			fmt.Sprintf("%.3f", a.sumFinalRTT/c),
			fmt.Sprintf("%.2f", a.sumInitCwnd/c),
			fmt.Sprintf("%.2f", a.sumFinalCwnd/c),
			fmt.Sprintf("%.2f", a.sumInitSsthresh/c),
			fmt.Sprintf("%.2f", a.sumFinalSsthresh/c),
			fmt.Sprintf("%.2f", a.sumTotalRetrans/c),
		}
		if *includeSamples {
			row = append(row,
				fmt.Sprintf("%.3f", a.sumMeanRTT/c),
				fmt.Sprintf("%.2f", a.sumMeanCwnd/c),
				fmt.Sprintf("%.2f", a.sumMeanSsthresh/c),
				fmt.Sprintf("%.5f", a.sumRetransRate/c),
			)
		}
		w2.Write(row)
	}

	w2.Flush()
	if err := w2.Error(); err != nil {
		fmt.Fprintf(os.Stderr, "CSV write error (scenario aggregate): %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Per-connection summary written to %s (logs scanned: %d)\n", *outFile, len(logFiles))
	fmt.Printf("Scenario aggregate summary written to %s (scenarios: %d)\n", *scenarioOut, len(scenarios))
}
