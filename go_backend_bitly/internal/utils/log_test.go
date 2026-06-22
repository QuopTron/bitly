package utils

import (
	"strings"
	"testing"
)

func resetLogBuffer() {
	lb := GetLogBuffer()
	lb.mu.Lock()
	lb.entries = lb.entries[:0]
	lb.mu.Unlock()
}

func enableLogging() {
	GetLogBuffer().SetLoggingEnabled(true)
}

func disableLogging() {
	GetLogBuffer().SetLoggingEnabled(false)
}

func TestLogBufferBasic(t *testing.T) {
	resetLogBuffer()
	enableLogging()
	defer disableLogging()

	lb := GetLogBuffer()

	if lb.Count() != 0 {
		t.Fatalf("expected empty buffer, got %d entries", lb.Count())
	}

	lb.Add("INFO", "test", "hello world")
	if lb.Count() != 1 {
		t.Fatalf("expected 1 entry, got %d", lb.Count())
	}

	lb.Add("DEBUG", "test", "debug message")
	if lb.Count() != 2 {
		t.Fatalf("expected 2 entries, got %d", lb.Count())
	}
}

func TestLogBufferGetAll(t *testing.T) {
	resetLogBuffer()
	enableLogging()
	defer disableLogging()

	lb := GetLogBuffer()
	lb.Add("INFO", "tag1", "msg1")
	lb.Add("WARN", "tag2", "msg2")

	all := lb.GetAll()
	if !strings.Contains(all, "msg1") || !strings.Contains(all, "msg2") {
		t.Errorf("GetAll() missing entries: %s", all)
	}
	if !strings.Contains(all, "\"level\":\"INFO\"") {
		t.Errorf("GetAll() missing level field: %s", all)
	}
	if !strings.Contains(all, "\"tag\":\"tag1\"") {
		t.Errorf("GetAll() missing tag field: %s", all)
	}
}

func TestLogBufferGetSince(t *testing.T) {
	resetLogBuffer()
	enableLogging()
	defer disableLogging()

	lb := GetLogBuffer()

	lb.Add("INFO", "t", "first")
	lb.Add("INFO", "t", "second")
	lb.Add("INFO", "t", "third")

	entries, total := lb.GetSince(1)
	if total != 3 {
		t.Errorf("expected total 3, got %d", total)
	}
	if len(entries) != 2 {
		t.Fatalf("expected 2 entries from index 1, got %d", len(entries))
	}
	if entries[0].Message != "second" {
		t.Errorf("expected first entry message 'second', got %q", entries[0].Message)
	}

	entries, total = lb.GetSince(10)
	if len(entries) != 0 {
		t.Errorf("expected empty for out-of-range index, got %d entries", len(entries))
	}
	if total != 3 {
		t.Errorf("expected total 3, got %d", total)
	}

	entries, total = lb.GetSince(-1)
	if len(entries) != 3 {
		t.Errorf("expected 3 entries for negative index, got %d", len(entries))
	}
	if total != 3 {
		t.Errorf("expected total 3 for GetSince(-1), got %d", total)
	}
}

func TestLogBufferClear(t *testing.T) {
	resetLogBuffer()
	enableLogging()
	defer disableLogging()

	lb := GetLogBuffer()
	lb.Add("INFO", "t", "msg")
	lb.Add("INFO", "t", "msg")
	if lb.Count() != 2 {
		t.Fatalf("expected 2 entries before clear")
	}

	lb.Clear()
	if lb.Count() != 0 {
		t.Errorf("expected 0 entries after clear, got %d", lb.Count())
	}
}

func TestLogBufferMaxSize(t *testing.T) {
	resetLogBuffer()
	enableLogging()
	defer disableLogging()

	lb := GetLogBuffer()
	for i := 0; i < 600; i++ {
		lb.Add("INFO", "t", "message")
	}
	if lb.Count() > 500 {
		t.Errorf("expected buffer capped at ~500, got %d", lb.Count())
	}
}

func TestLogBufferLoggingDisabled(t *testing.T) {
	resetLogBuffer()
	disableLogging()

	lb := GetLogBuffer()
	lb.Add("INFO", "t", "should not appear")
	if lb.Count() != 0 {
		t.Errorf("expected 0 entries when logging disabled, got %d", lb.Count())
	}

	lb.Add("ERROR", "t", "error always logged")
	if lb.Count() != 1 {
		t.Errorf("expected ERROR entry even when logging disabled, got %d", lb.Count())
	}
}

func TestLogBufferSanitization(t *testing.T) {
	resetLogBuffer()
	enableLogging()
	defer disableLogging()

	lb := GetLogBuffer()
	lb.Add("INFO", "auth", "token is access_token=secret123")
	entries, _ := lb.GetSince(0)
	if len(entries) == 0 {
		t.Fatal("expected at least 1 entry")
	}
	last := entries[len(entries)-1]
	if strings.Contains(last.Message, "secret123") {
		t.Errorf("message not sanitized: %s", last.Message)
	}
	if !strings.Contains(last.Message, "[REDACTED]") {
		t.Errorf("expected [REDACTED] in sanitized message, got: %s", last.Message)
	}
}

func TestLogFunctions(t *testing.T) {
	resetLogBuffer()
	enableLogging()
	defer disableLogging()

	LogInfo("test", "info %s", "message")
	LogDebug("test", "debug %s", "message")
	LogWarn("test", "warn %s", "message")
	LogError("test", "error %s", "message")

	lb := GetLogBuffer()
	if lb.Count() != 4 {
		t.Errorf("expected 4 log entries, got %d", lb.Count())
	}

	entries, _ := lb.GetSince(0)
	if len(entries) < 4 {
		t.Fatal("not enough entries")
	}
	levels := map[string]bool{}
	for _, e := range entries {
		levels[e.Level] = true
	}
	for _, level := range []string{"INFO", "DEBUG", "WARN", "ERROR"} {
		if !levels[level] {
			t.Errorf("missing log level %s", level)
		}
	}
}

func TestGoLog(t *testing.T) {
	resetLogBuffer()
	enableLogging()
	defer disableLogging()

	GoLog("plain message")
	GoLog("[mytag] tagged message")
	GoLog("something failed: error")
	GoLog("a warning message")
	GoLog("match found: success")

	lb := GetLogBuffer()
	entries, _ := lb.GetSince(0)

	tests := []struct {
		idx     int
		wantTag string
		wantLvl string
		msgPart string
	}{
		{0, "Go", "INFO", "plain message"},
		{1, "mytag", "INFO", "tagged message"},
		{2, "Go", "ERROR", "failed"},
		{3, "Go", "WARN", "warning"},
		{4, "Go", "INFO", "match found"},
	}

	for _, tt := range tests {
		if tt.idx >= len(entries) {
			t.Errorf("missing entry at index %d", tt.idx)
			continue
		}
		e := entries[tt.idx]
		if e.Tag != tt.wantTag {
			t.Errorf("GoLog[%d] tag = %q, want %q", tt.idx, e.Tag, tt.wantTag)
		}
		if e.Level != tt.wantLvl {
			t.Errorf("GoLog[%d] level = %q, want %q", tt.idx, e.Level, tt.wantLvl)
		}
		if !strings.Contains(e.Message, tt.msgPart) {
			t.Errorf("GoLog[%d] message = %q, want containing %q", tt.idx, e.Message, tt.msgPart)
		}
	}
}

func TestLogBufferGetAllJSON(t *testing.T) {
	resetLogBuffer()
	enableLogging()
	defer disableLogging()

	lb := GetLogBuffer()
	lb.Add("ERROR", "svc", "test error")
	all := lb.GetAll()

	if !strings.HasPrefix(all, "[") || !strings.HasSuffix(all, "]") {
		t.Errorf("GetAll() should return JSON array, got: %s", all)
	}
	if !strings.Contains(all, "\"timestamp\"") {
		t.Errorf("GetAll() missing timestamp field: %s", all)
	}
	if !strings.Contains(all, "\"message\":\"test error\"") {
		t.Errorf("GetAll() missing message content: %s", all)
	}
}
