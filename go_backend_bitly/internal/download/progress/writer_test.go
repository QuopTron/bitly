package progress

import (
	"errors"
	"strings"
	"testing"
)

type mockWriter struct {
	data []byte
}

func (m *mockWriter) Write(p []byte) (int, error) {
	m.data = append(m.data, p...)
	return len(p), nil
}

func TestNewItemProgressWriter(t *testing.T) {
	pw := NewItemProgressWriter(&mockWriter{}, "test-item")
	if pw == nil {
		t.Fatal("expected non-nil writer")
	}
	if pw.itemID != "test-item" {
		t.Errorf("itemID = %q", pw.itemID)
	}
}

func TestNewItemProgressWriterWithCancel(t *testing.T) {
	called := false
	pw := NewItemProgressWriterWithCancel(&mockWriter{}, "cancelled-item", func(id string) bool {
		called = true
		return id == "cancelled-item"
	})
	if pw == nil {
		t.Fatal("expected non-nil writer")
	}
	pw.Write([]byte("hello"))
	if !called {
		t.Error("cancel function should have been called")
	}
}

func TestWrite_Cancelled(t *testing.T) {
	pw := NewItemProgressWriterWithCancel(&mockWriter{}, "cancelled", func(id string) bool {
		return true
	})
	n, err := pw.Write([]byte("test"))
	if n != 0 {
		t.Errorf("expected 0 bytes on cancel, got %d", n)
	}
	if !errors.Is(err, ErrDownloadCancelled) {
		t.Errorf("expected ErrDownloadCancelled, got %v", err)
	}
}

func TestWrite_WithErrorWriter(t *testing.T) {
	mw := &mockWriter{}
	pw := NewItemProgressWriter(mw, "")
	n, err := pw.Write([]byte("hello"))
	if err != nil {
		t.Fatal(err)
	}
	if n != 5 {
		t.Errorf("n = %d", n)
	}
	if string(mw.data) != "hello" {
		t.Errorf("data = %q", string(mw.data))
	}
}

func TestProgressError_ImplementsError(t *testing.T) {
	e := &ProgressError{Message: "something failed"}
	if e.Error() != "something failed" {
		t.Errorf("Error() = %q", e.Error())
	}
}

func TestErrDownloadCancelled(t *testing.T) {
	if ErrDownloadCancelled == nil {
		t.Fatal("ErrDownloadCancelled is nil")
	}
	if !strings.Contains(ErrDownloadCancelled.Error(), "cancelled") {
		t.Errorf("message = %q", ErrDownloadCancelled.Error())
	}
}

func TestWrite_WithCustomWriterError(t *testing.T) {
	mw := &mockWriter{}
	pw := NewItemProgressWriter(mw, "test")

	data := make([]byte, progressUpdateThreshold+1)
	for i := range data {
		data[i] = 'x'
	}

	n, err := pw.Write(data)
	if err != nil {
		t.Fatal(err)
	}
	if n != len(data) {
		t.Errorf("expected %d bytes, got %d", len(data), n)
	}
}

func TestWrite_BelowThreshold(t *testing.T) {
	mw := &mockWriter{}
	pw := NewItemProgressWriter(mw, "small")
	smallData := []byte("small")
	n, err := pw.Write(smallData)
	if err != nil {
		t.Fatal(err)
	}
	if n != len(smallData) {
		t.Errorf("expected %d bytes, got %d", len(smallData), n)
	}
}
