package protocol

import (
	"encoding/binary"
	"fmt"
	"io"
	"net"
)

// Operation codes
const (
	OpList  byte = 1
	OpPut   byte = 2
	OpQuit  byte = 3
	OpError byte = 255
)

// Frame represents a protocol message
type Frame struct {
	OpCode     byte
	PayloadLen uint32
	Payload    []byte
}

// WriteFrame sends a frame over the connection
func WriteFrame(conn net.Conn, frame *Frame) error {
	// Write opcode
	if err := binary.Write(conn, binary.BigEndian, frame.OpCode); err != nil {
		return fmt.Errorf("failed to write opcode: %v", err)
	}

	// Write payload length
	if err := binary.Write(conn, binary.BigEndian, frame.PayloadLen); err != nil {
		return fmt.Errorf("failed to write payload length: %v", err)
	}

	// Write payload if exists
	if frame.PayloadLen > 0 {
		if _, err := conn.Write(frame.Payload); err != nil {
			return fmt.Errorf("failed to write payload: %v", err)
		}
	}

	return nil
}

// ReadFrame reads a frame from the connection
func ReadFrame(conn net.Conn) (*Frame, error) {
	frame := &Frame{}

	// Read opcode
	if err := binary.Read(conn, binary.BigEndian, &frame.OpCode); err != nil {
		return nil, fmt.Errorf("failed to read opcode: %v", err)
	}

	// Read payload length
	if err := binary.Read(conn, binary.BigEndian, &frame.PayloadLen); err != nil {
		return nil, fmt.Errorf("failed to read payload length: %v", err)
	}

	// Read payload if exists
	if frame.PayloadLen > 0 {
		frame.Payload = make([]byte, frame.PayloadLen)
		if _, err := io.ReadFull(conn, frame.Payload); err != nil {
			return nil, fmt.Errorf("failed to read payload: %v", err)
		}
	}

	return frame, nil
}

// CreateListFrame creates a LIST operation frame
func CreateListFrame() *Frame {
	return &Frame{
		OpCode:     OpList,
		PayloadLen: 0,
		Payload:    nil,
	}
}

// CreatePutFrame creates a PUT operation frame
func CreatePutFrame(filename string, fileData []byte) *Frame {
	// Format: [filename_len:4][filename][filedata]
	filenameBytes := []byte(filename)
	payload := make([]byte, 4+len(filenameBytes)+len(fileData))

	binary.BigEndian.PutUint32(payload[0:4], uint32(len(filenameBytes)))
	copy(payload[4:4+len(filenameBytes)], filenameBytes)
	copy(payload[4+len(filenameBytes):], fileData)

	return &Frame{
		OpCode:     OpPut,
		PayloadLen: uint32(len(payload)),
		Payload:    payload,
	}
}

// CreateQuitFrame creates a QUIT operation frame
func CreateQuitFrame() *Frame {
	return &Frame{
		OpCode:     OpQuit,
		PayloadLen: 0,
		Payload:    nil,
	}
}

// CreateErrorFrame creates an ERROR frame
func CreateErrorFrame(message string) *Frame {
	payload := []byte(message)
	return &Frame{
		OpCode:     OpError,
		PayloadLen: uint32(len(payload)),
		Payload:    payload,
	}
}

// ParsePutFrame extracts filename and file data from PUT frame
func ParsePutFrame(frame *Frame) (string, []byte, error) {
	if frame.OpCode != OpPut {
		return "", nil, fmt.Errorf("not a PUT frame")
	}

	if len(frame.Payload) < 4 {
		return "", nil, fmt.Errorf("invalid PUT frame payload")
	}

	filenameLen := binary.BigEndian.Uint32(frame.Payload[0:4])
	if len(frame.Payload) < int(4+filenameLen) {
		return "", nil, fmt.Errorf("invalid PUT frame: filename length mismatch")
	}

	filename := string(frame.Payload[4 : 4+filenameLen])
	fileData := frame.Payload[4+filenameLen:]

	return filename, fileData, nil
}
