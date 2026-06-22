package core

import (
	"context"
	"testing"
)

func resetCancelMaps() {
	cancelMu.Lock()
	cancelMap = make(map[string]*cancelEntry)
	cancelMu.Unlock()

	extensionRequestCancelMu.Lock()
	extensionRequestCancelMap = make(map[string]*cancelEntry)
	extensionRequestCancelMu.Unlock()
}

func TestErrDownloadCancelled(t *testing.T) {
	if ErrDownloadCancelled == nil {
		t.Fatal("ErrDownloadCancelled should not be nil")
	}
	if ErrDownloadCancelled.Error() != "download cancelled" {
		t.Errorf("unexpected error message: %s", ErrDownloadCancelled.Error())
	}
}

func TestErrExtensionRequestCancelled(t *testing.T) {
	if ErrExtensionRequestCancelled == nil {
		t.Fatal("ErrExtensionRequestCancelled should not be nil")
	}
	if ErrExtensionRequestCancelled.Error() != "extension request cancelled" {
		t.Errorf("unexpected error message: %s", ErrExtensionRequestCancelled.Error())
	}
}

func TestInitDownloadCancel_EmptyID(t *testing.T) {
	resetCancelMaps()
	ctx := InitDownloadCancel("")
	if ctx == nil {
		t.Fatal("expected non-nil context")
	}
	if ctx.Err() != nil {
		t.Error("expected background context, not canceled")
	}
}

func TestInitDownloadCancel_NewEntry(t *testing.T) {
	resetCancelMaps()
	ctx := InitDownloadCancel("item-1")
	if ctx == nil {
		t.Fatal("expected non-nil context")
	}
	if ctx.Err() != nil {
		t.Error("new context should not be canceled")
	}

	cancelMu.Lock()
	entry, ok := cancelMap["item-1"]
	cancelMu.Unlock()
	if !ok {
		t.Fatal("entry should exist in map")
	}
	if entry.refs != 1 {
		t.Errorf("expected refs=1, got %d", entry.refs)
	}
	if entry.canceled {
		t.Error("new entry should not be canceled")
	}
}

func TestInitDownloadCancel_ReusesEntry(t *testing.T) {
	resetCancelMaps()
	ctx1 := InitDownloadCancel("item-2")
	ctx2 := InitDownloadCancel("item-2")

	if ctx1 != ctx2 {
		t.Error("expected same context for same itemID")
	}

	cancelMu.Lock()
	entry, ok := cancelMap["item-2"]
	cancelMu.Unlock()
	if !ok {
		t.Fatal("entry should exist")
	}
	if entry.refs != 2 {
		t.Errorf("expected refs=2 after calling twice, got %d", entry.refs)
	}
}

func TestCancelDownload_NewEntry(t *testing.T) {
	resetCancelMaps()
	CancelDownload("cancel-new")
	if !IsDownloadCancelled("cancel-new") {
		t.Error("expected download to be cancelled")
	}
}

func TestCancelDownload_CancelsContext(t *testing.T) {
	resetCancelMaps()
	ctx := InitDownloadCancel("cancel-ctx")
	CancelDownload("cancel-ctx")

	if ctx.Err() != context.Canceled {
		t.Error("expected context to be canceled after CancelDownload")
	}
}

func TestCancelDownload_EmptyID(t *testing.T) {
	resetCancelMaps()
	CancelDownload("")
	// Should not panic
}

func TestIsDownloadCancelled_EmptyID(t *testing.T) {
	resetCancelMaps()
	if IsDownloadCancelled("") {
		t.Error("empty ID should not be considered cancelled")
	}
}

func TestIsDownloadCancelled_NonExistent(t *testing.T) {
	resetCancelMaps()
	if IsDownloadCancelled("non-existent") {
		t.Error("non-existent ID should not be considered cancelled")
	}
}

func TestClearDownloadCancel_DecrementsRefs(t *testing.T) {
	resetCancelMaps()
	InitDownloadCancel("clear-refs")
	InitDownloadCancel("clear-refs")

	cancelMu.Lock()
	entry := cancelMap["clear-refs"]
	refsBefore := entry.refs
	cancelMu.Unlock()

	ClearDownloadCancel("clear-refs")

	cancelMu.Lock()
	refsAfter := entry.refs
	exists := cancelMap["clear-refs"] != nil
	cancelMu.Unlock()

	if refsAfter != refsBefore-1 {
		t.Errorf("expected refs=%d, got %d", refsBefore-1, refsAfter)
	}
	if !exists {
		t.Error("entry should still exist after one Clear")
	}
}

func TestClearDownloadCancel_RemovesWhenZero(t *testing.T) {
	resetCancelMaps()
	InitDownloadCancel("clear-zero")
	ClearDownloadCancel("clear-zero")

	cancelMu.Lock()
	_, exists := cancelMap["clear-zero"]
	cancelMu.Unlock()

	if exists {
		t.Error("entry should be removed when refs reaches 0")
	}
}

func TestClearDownloadCancel_EmptyID(t *testing.T) {
	resetCancelMaps()
	ClearDownloadCancel("")
	// Should not panic
}

func TestInitDownloadCancel_AfterCancelReturnsCanceledCtx(t *testing.T) {
	resetCancelMaps()
	// Cancel first, then init
	CancelDownload("cancel-then-init")
	ctx := InitDownloadCancel("cancel-then-init")

	if ctx.Err() != context.Canceled {
		t.Error("expected canceled context when init after CancelDownload")
	}

	cancelMu.Lock()
	entry, ok := cancelMap["cancel-then-init"]
	cancelMu.Unlock()
	if !ok {
		t.Fatal("entry should exist")
	}
	if entry.refs != 1 {
		t.Errorf("expected refs=1, got %d", entry.refs)
	}
}

func TestClearDownloadCancel_MultipleRefs(t *testing.T) {
	resetCancelMaps()
	InitDownloadCancel("multi")
	InitDownloadCancel("multi")
	InitDownloadCancel("multi")

	ClearDownloadCancel("multi")
	ClearDownloadCancel("multi")

	cancelMu.Lock()
	_, exists := cancelMap["multi"]
	cancelMu.Unlock()
	if !exists {
		t.Error("entry should still exist after 2 Clear calls (3 inits)")
	}

	ClearDownloadCancel("multi")

	cancelMu.Lock()
	_, exists = cancelMap["multi"]
	cancelMu.Unlock()
	if exists {
		t.Error("entry should be removed after matching Clear calls")
	}
}

func TestDownloadCancelLifecycle(t *testing.T) {
	resetCancelMaps()
	ctx := InitDownloadCancel("lifecycle")

	if IsDownloadCancelled("lifecycle") {
		t.Error("should not be cancelled initially")
	}

	CancelDownload("lifecycle")

	if !IsDownloadCancelled("lifecycle") {
		t.Error("should be cancelled after CancelDownload")
	}

	if ctx.Err() != context.Canceled {
		t.Error("context should be canceled")
	}

	ClearDownloadCancel("lifecycle")

	cancelMu.Lock()
	_, exists := cancelMap["lifecycle"]
	cancelMu.Unlock()
	if exists {
		t.Error("entry should be removed after lifecycle")
	}
}

func TestInitExtensionRequestCancel_EmptyID(t *testing.T) {
	resetCancelMaps()
	ctx := InitExtensionRequestCancel("")
	if ctx == nil {
		t.Fatal("expected non-nil context")
	}
	if ctx.Err() != nil {
		t.Error("expected background context for empty ID")
	}
}

func TestInitExtensionRequestCancel_NewEntry(t *testing.T) {
	resetCancelMaps()
	ctx := InitExtensionRequestCancel("ext-1")
	if ctx == nil {
		t.Fatal("expected non-nil context")
	}
	if ctx.Err() != nil {
		t.Error("new extension context should not be canceled")
	}

	extensionRequestCancelMu.Lock()
	entry, ok := extensionRequestCancelMap["ext-1"]
	extensionRequestCancelMu.Unlock()
	if !ok {
		t.Fatal("entry should exist in extension map")
	}
	if entry.refs != 1 {
		t.Errorf("expected refs=1, got %d", entry.refs)
	}
}

func TestInitExtensionRequestCancel_ReusesEntry(t *testing.T) {
	resetCancelMaps()
	ctx1 := InitExtensionRequestCancel("ext-reuse")
	ctx2 := InitExtensionRequestCancel("ext-reuse")

	if ctx1 != ctx2 {
		t.Error("expected same context for same requestID")
	}

	extensionRequestCancelMu.Lock()
	entry, ok := extensionRequestCancelMap["ext-reuse"]
	extensionRequestCancelMu.Unlock()
	if !ok {
		t.Fatal("entry should exist")
	}
	if entry.refs != 2 {
		t.Errorf("expected refs=2, got %d", entry.refs)
	}
}

func TestCancelExtensionRequest(t *testing.T) {
	resetCancelMaps()
	ctx := InitExtensionRequestCancel("ext-cancel")
	CancelExtensionRequest("ext-cancel")

	if ctx.Err() != context.Canceled {
		t.Error("extension context should be canceled")
	}
	if !IsExtensionRequestCancelled("ext-cancel") {
		t.Error("extension should be marked as cancelled")
	}
}

func TestCancelExtensionRequest_BeforeInit(t *testing.T) {
	resetCancelMaps()
	CancelExtensionRequest("ext-before-init")

	ctx := InitExtensionRequestCancel("ext-before-init")
	if ctx.Err() != context.Canceled {
		t.Error("extension context should be canceled when init after cancel")
	}
}

func TestCancelExtensionRequest_EmptyID(t *testing.T) {
	resetCancelMaps()
	CancelExtensionRequest("")
	// Should not panic
}

func TestIsExtensionRequestCancelled_EmptyID(t *testing.T) {
	resetCancelMaps()
	if IsExtensionRequestCancelled("") {
		t.Error("empty ID should not be considered cancelled")
	}
}

func TestIsExtensionRequestCancelled_NonExistent(t *testing.T) {
	resetCancelMaps()
	if IsExtensionRequestCancelled("nonexistent") {
		t.Error("non-existent request should not be considered cancelled")
	}
}

func TestClearExtensionRequestCancel(t *testing.T) {
	resetCancelMaps()
	InitExtensionRequestCancel("ext-clear")
	InitExtensionRequestCancel("ext-clear")

	ClearExtensionRequestCancel("ext-clear")

	extensionRequestCancelMu.Lock()
	entry := extensionRequestCancelMap["ext-clear"]
	exists1 := entry != nil
	refs1 := 0
	if exists1 {
		refs1 = entry.refs
	}
	extensionRequestCancelMu.Unlock()

	if refs1 != 1 {
		t.Errorf("expected refs=1 after one Clear, got %d", refs1)
	}
	if !exists1 {
		t.Error("entry should still exist after one Clear (2 inits)")
	}

	ClearExtensionRequestCancel("ext-clear")

	extensionRequestCancelMu.Lock()
	_, exists2 := extensionRequestCancelMap["ext-clear"]
	extensionRequestCancelMu.Unlock()

	if exists2 {
		t.Error("entry should be removed after refs reaches 0")
	}
}

func TestClearExtensionRequestCancel_EmptyID(t *testing.T) {
	resetCancelMaps()
	ClearExtensionRequestCancel("")
	// Should not panic
}

func TestExtensionCancelLifecycle(t *testing.T) {
	resetCancelMaps()
	ctx := InitExtensionRequestCancel("ext-lifecycle")

	if IsExtensionRequestCancelled("ext-lifecycle") {
		t.Error("should not be cancelled initially")
	}

	CancelExtensionRequest("ext-lifecycle")

	if !IsExtensionRequestCancelled("ext-lifecycle") {
		t.Error("should be cancelled after CancelExtensionRequest")
	}

	if ctx.Err() != context.Canceled {
		t.Error("context should be canceled")
	}

	ClearExtensionRequestCancel("ext-lifecycle")

	extensionRequestCancelMu.Lock()
	_, exists := extensionRequestCancelMap["ext-lifecycle"]
	extensionRequestCancelMu.Unlock()
	if exists {
		t.Error("entry should be removed after lifecycle")
	}
}

func TestCancelDownload_DoesNotAffectExtensionMap(t *testing.T) {
	resetCancelMaps()
	InitDownloadCancel("dl-only")
	InitExtensionRequestCancel("ext-only")

	CancelDownload("dl-only")

	if !IsDownloadCancelled("dl-only") {
		t.Error("download should be cancelled")
	}
	if IsExtensionRequestCancelled("ext-only") {
		t.Error("extension should NOT be cancelled")
	}

	cancelMu.Lock()
	_, dlExists := cancelMap["dl-only"]
	cancelMu.Unlock()
	extensionRequestCancelMu.Lock()
	_, extExists := extensionRequestCancelMap["ext-only"]
	extensionRequestCancelMu.Unlock()

	if !dlExists {
		t.Error("download entry should exist")
	}
	if !extExists {
		t.Error("extension entry should still exist")
	}
}

func TestConcurrentInitCancelDownload(t *testing.T) {
	resetCancelMaps()
	const goroutines = 20
	done := make(chan struct{}, goroutines)

	for i := 0; i < goroutines; i++ {
		go func() {
			ctx := InitDownloadCancel("concurrent")
			_ = ctx
			done <- struct{}{}
		}()
	}

	for i := 0; i < goroutines; i++ {
		<-done
	}

	cancelMu.Lock()
	entry := cancelMap["concurrent"]
	refs := entry.refs
	cancelMu.Unlock()

	if refs != goroutines {
		t.Errorf("expected refs=%d, got %d", goroutines, refs)
	}

	for i := 0; i < goroutines; i++ {
		ClearDownloadCancel("concurrent")
	}

	cancelMu.Lock()
	_, exists := cancelMap["concurrent"]
	cancelMu.Unlock()
	if exists {
		t.Error("entry should be removed after all Clear calls")
	}
}
