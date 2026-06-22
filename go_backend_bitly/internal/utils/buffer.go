package utils

import (
	"encoding/json"
	"fmt"
	"sync"
	"time"
)

type LogEntry struct {
	Timestamp string `json:"timestamp"`
	Level     string `json:"level"`
	Tag       string `json:"tag"`
	Message   string `json:"message"`
}

type LogBuffer struct {
	entries        []LogEntry
	maxSize        int
	mu             sync.RWMutex
	loggingEnabled bool
}

const defaultLogBufferSize = 500

var (
	globalLogBuffer *LogBuffer
	logBufferOnce   sync.Once
)

func GetLogBuffer() *LogBuffer {
	logBufferOnce.Do(func() {
		globalLogBuffer = &LogBuffer{
			entries:        make([]LogEntry, 0, defaultLogBufferSize),
			maxSize:        defaultLogBufferSize,
			loggingEnabled: false,
		}
	})
	return globalLogBuffer
}

func (lb *LogBuffer) SetLoggingEnabled(enabled bool) {
	lb.mu.Lock()
	defer lb.mu.Unlock()
	lb.loggingEnabled = enabled
}

func (lb *LogBuffer) IsLoggingEnabled() bool {
	lb.mu.RLock()
	defer lb.mu.RUnlock()
	return lb.loggingEnabled
}

func (lb *LogBuffer) Add(level, tag, message string) {
	lb.mu.Lock()
	defer lb.mu.Unlock()

	if !lb.loggingEnabled && level != "ERROR" && level != "FATAL" {
		return
	}

	message = sanitizeSensitiveLogText(message)

	entry := LogEntry{
		Timestamp: time.Now().Format("15:04:05.000"),
		Level:     level,
		Tag:       tag,
		Message:   message,
	}

	if len(lb.entries) >= lb.maxSize {
		lb.entries = lb.entries[1:]
	}
	lb.entries = append(lb.entries, entry)

	fmt.Printf("[%s] %s\n", tag, message)
}

func (lb *LogBuffer) GetAll() string {
	lb.mu.RLock()
	defer lb.mu.RUnlock()

	jsonBytes, _ := json.Marshal(lb.entries)
	return string(jsonBytes)
}

func (lb *LogBuffer) GetSince(index int) ([]LogEntry, int) {
	lb.mu.RLock()
	defer lb.mu.RUnlock()

	if index < 0 {
		index = 0
	}
	if index >= len(lb.entries) {
		return []LogEntry{}, len(lb.entries)
	}

	entries := lb.entries[index:]
	return entries, len(lb.entries)
}

func (lb *LogBuffer) Clear() {
	lb.mu.Lock()
	defer lb.mu.Unlock()
	lb.entries = lb.entries[:0]
}

func (lb *LogBuffer) Count() int {
	lb.mu.RLock()
	defer lb.mu.RUnlock()
	return len(lb.entries)
}
