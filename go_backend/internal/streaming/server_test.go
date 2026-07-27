package streaming

import (
	"testing"
)

func TestParseRangeFull(t *testing.T) {
	offset, length, err := ParseRange("", 1000)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if offset != 0 || length != 1000 {
		t.Errorf("expected (0, 1000), got (%d, %d)", offset, length)
	}
}

func TestParseRangeBytes(t *testing.T) {
	offset, length, err := ParseRange("bytes=0-499", 1000)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if offset != 0 || length != 500 {
		t.Errorf("expected (0, 500), got (%d, %d)", offset, length)
	}
}

func TestParseRangeMiddle(t *testing.T) {
	offset, length, err := ParseRange("bytes=500-999", 1000)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if offset != 500 || length != 500 {
		t.Errorf("expected (500, 500), got (%d, %d)", offset, length)
	}
}

func TestParseRangeTillEnd(t *testing.T) {
	offset, length, err := ParseRange("bytes=500-", 1000)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if offset != 500 || length != 500 {
		t.Errorf("expected (500, 500) from 500- in 1000-size file, got (%d, %d)", offset, length)
	}
}

func TestParseRangeSingleByte(t *testing.T) {
	offset, length, err := ParseRange("bytes=10-10", 1000)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if offset != 10 || length != 1 {
		t.Errorf("expected (10, 1), got (%d, %d)", offset, length)
	}
}

func TestParseRangeInvalidPrefix(t *testing.T) {
	_, _, err := ParseRange("invalid", 1000)
	if err == nil {
		t.Error("expected error for invalid prefix")
	}
}

func TestParseRangeInvalidFormat(t *testing.T) {
	_, _, err := ParseRange("bytes=invalid", 1000)
	if err == nil {
		t.Error("expected error for invalid format")
	}
}

func TestParseRangeNegativeStart(t *testing.T) {
	_, _, err := ParseRange("bytes=-100", 1000)
	if err == nil {
		t.Error("expected error for negative start")
	}
}

func TestParseRangeLargeFile(t *testing.T) {
	offset, length, err := ParseRange("bytes=0-1048575", 10*1024*1024)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if offset != 0 || length != 1048576 {
		t.Errorf("expected (0, 1048576), got (%d, %d)", offset, length)
	}
}
