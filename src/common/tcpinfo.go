package common

import (
	"net"
	"syscall"
	"time"
	"unsafe"
)

// TCPInfo represents TCP connection metrics
type TCPInfo struct {
	Timestamp     time.Time `json:"timestamp"`
	RTT           uint32    `json:"rtt_us"`         // Round trip time in microseconds
	RTTVar        uint32    `json:"rtt_var_us"`     // RTT variance in microseconds
	SndCwnd       uint32    `json:"snd_cwnd"`       // Congestion window size
	SndSsthresh   uint32    `json:"snd_ssthresh"`   // Slow start threshold
	Retransmits   uint8     `json:"retransmits"`    // Number of retransmits
	TotalRetrans  uint32    `json:"total_retrans"`  // Total retransmissions
	BytesAcked    uint64    `json:"bytes_acked"`    // Bytes acknowledged
	BytesReceived uint64    `json:"bytes_received"` // Bytes received
	SegsOut       uint32    `json:"segs_out"`       // Segments sent
	SegsIn        uint32    `json:"segs_in"`        // Segments received
}

// TCPInfoCollector collects TCP_INFO metrics from connections
type TCPInfoCollector struct {
	samples []TCPInfo
}

// NewTCPInfoCollector creates a new TCP info collector
func NewTCPInfoCollector() *TCPInfoCollector {
	return &TCPInfoCollector{
		samples: make([]TCPInfo, 0),
	}
}

// GetTCPInfo retrieves TCP_INFO from a connection (Linux only)
func (c *TCPInfoCollector) GetTCPInfo(conn net.Conn) (*TCPInfo, error) {
	tcpConn, ok := conn.(*net.TCPConn)
	if !ok {
		return nil, nil // Skip if not TCP connection
	}

	// Get raw connection
	rawConn, err := tcpConn.SyscallConn()
	if err != nil {
		return nil, err
	}

	var tcpInfo *TCPInfo
	var syscallErr error

	err = rawConn.Control(func(fd uintptr) {
		tcpInfo, syscallErr = getTCPInfoFromFD(int(fd))
	})

	if err != nil {
		return nil, err
	}
	if syscallErr != nil {
		return nil, syscallErr
	}

	return tcpInfo, nil
}

// CollectSample collects a TCP_INFO sample from the connection
func (c *TCPInfoCollector) CollectSample(conn net.Conn) error {
	info, err := c.GetTCPInfo(conn)
	if err != nil || info == nil {
		return err
	}

	c.samples = append(c.samples, *info)
	return nil
}

// GetSamples returns all collected samples
func (c *TCPInfoCollector) GetSamples() []TCPInfo {
	return c.samples
}

// ClearSamples clears all collected samples
func (c *TCPInfoCollector) ClearSamples() {
	c.samples = c.samples[:0]
}

// getTCPInfoFromFD gets TCP_INFO using getsockopt syscall (Linux specific)
func getTCPInfoFromFD(fd int) (*TCPInfo, error) {
	// TCP_INFO structure size and syscall constants for Linux
	const (
		SOL_TCP  = 6
		TCP_INFO = 11
	)

	// Linux tcp_info structure (simplified version with key fields)
	type linuxTCPInfo struct {
		State         uint8
		CaState       uint8
		Retransmits   uint8
		Probes        uint8
		Backoff       uint8
		Options       uint8
		Pad           [2]uint8
		Rto           uint32
		Ato           uint32
		SndMss        uint32
		RcvMss        uint32
		Unacked       uint32
		Sacked        uint32
		Lost          uint32
		Retrans       uint32
		Fackets       uint32
		LastDataSent  uint32
		LastAckSent   uint32
		LastDataRecv  uint32
		LastAckRecv   uint32
		Pmtu          uint32
		RcvSsthresh   uint32
		Rtt           uint32
		Rttvar        uint32
		SndSsthresh   uint32
		SndCwnd       uint32
		Advmss        uint32
		Reordering    uint32
		RcvRtt        uint32
		RcvSpace      uint32
		TotalRetrans  uint32
		PacingRate    uint64
		MaxPacingRate uint64
		BytesAcked    uint64
		BytesReceived uint64
		SegsOut       uint32
		SegsIn        uint32
		NotsentBytes  uint32
		MinRtt        uint32
		DataSegsIn    uint32
		DataSegsOut   uint32
		DeliveryRate  uint64
		BusyTime      uint64
		RwndLimited   uint64
		SndbufLimited uint64
	}

	var info linuxTCPInfo
	infoSize := unsafe.Sizeof(info)

	// Call getsockopt to get TCP_INFO
	_, _, errno := syscall.Syscall6(
		syscall.SYS_GETSOCKOPT,
		uintptr(fd),
		SOL_TCP,
		TCP_INFO,
		uintptr(unsafe.Pointer(&info)),
		uintptr(unsafe.Pointer(&infoSize)),
		0,
	)

	if errno != 0 {
		return nil, errno
	}

	// Convert to our TCPInfo structure
	tcpInfo := &TCPInfo{
		Timestamp:     time.Now(),
		RTT:           info.Rtt,
		RTTVar:        info.Rttvar,
		SndCwnd:       info.SndCwnd,
		SndSsthresh:   info.SndSsthresh,
		Retransmits:   info.Retransmits,
		TotalRetrans:  info.TotalRetrans,
		BytesAcked:    info.BytesAcked,
		BytesReceived: info.BytesReceived,
		SegsOut:       info.SegsOut,
		SegsIn:        info.SegsIn,
	}

	return tcpInfo, nil
}
