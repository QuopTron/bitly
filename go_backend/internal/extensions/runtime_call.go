package extensions

import (
	"fmt"
	"time"

	"github.com/dop251/goja"
)

// CallMethod calls an exported function from a loaded extension.
func (r *Runtime) CallMethod(extID, method string, args ...interface{}) (ret interface{}, callErr error) {
	// Recover from JS panics so they don't crash the app
	defer func() {
		if rec := recover(); rec != nil {
			callErr = fmt.Errorf("ext %s: %s panic: %v", extID, method, rec)
		}
	}()

	sandbox, ok := r.sandboxes[extID]
	if !ok {
		return nil, fmt.Errorf("ext %s not loaded", extID)
	}

	// goja is not thread-safe: a background download goroutine and a bridge-
	// thread search can hit the same extension at the same time. Serialize per
	// sandbox so concurrent calls to one extension never race on its VM.
	//
	// The lock wait is BOUNDED: a JS call stuck inside a synchronous fetch
	// (the Go bridge can't honor the JS AbortController signal, so the 15s
	// JS timeout really runs the full 30s client timeout) would otherwise
	// block every later call to this extension for the whole hang — and a
	// leaked rescue goroutine holding this mutex would deadlock the app's
	// playback RPC forever. After the wait we fail fast and let the caller's
	// cooldown skip this provider instead.
	if !sandbox.tryLock(20 * time.Second) {
		return nil, fmt.Errorf("ext %s: %s busy (previous call stuck)", extID, method)
	}
	defer sandbox.unlock()

	fn := sandbox.VM.Get(method)
	if fn == nil || goja.IsUndefined(fn) {
		return nil, fmt.Errorf("ext %s: method %s not found", extID, method)
	}

	fnCall, isFunc := goja.AssertFunction(fn)
	if !isFunc {
		return nil, fmt.Errorf("ext %s: %s is not callable", extID, method)
	}

	jsArgs := make([]goja.Value, len(args))
	for i, arg := range args {
		jsArgs[i] = sandbox.VM.ToValue(arg)
	}

	result, err := fnCall(goja.Undefined(), jsArgs...)
	if err != nil {
		return nil, fmt.Errorf("ext %s: %s call failed: %w", extID, method, err)
	}
	if result != nil && !goja.IsUndefined(result) && !goja.IsNull(result) {
		return result.Export(), nil
	}
	return nil, nil
}

// HasMethod reports whether a loaded extension exports a callable [method].
// Used at wiring time to discover optional capabilities (e.g. the SpotiFLAC
// lyrics_provider contract) without paying a doomed call per request.
func (r *Runtime) HasMethod(extID, method string) bool {
	sandbox, ok := r.sandboxes[extID]
	if !ok {
		return false
	}
	sandbox.lockCh <- struct{}{}
	defer func() { <-sandbox.lockCh }()
	fn := sandbox.VM.Get(method)
	if fn == nil || goja.IsUndefined(fn) {
		return false
	}
	_, isFunc := goja.AssertFunction(fn)
	return isFunc
}

// tryLock acquires the sandbox mutex, waiting at most [d]. It returns false
// when the sandbox has been busy for too long — the previous JS call is stuck
// (a synchronous fetch the bridge can't abort) — so callers can fail fast and
// let the provider cooldown skip it instead of blocking forever.
func (s *Sandbox) tryLock(d time.Duration) bool {
	select {
	case s.lockCh <- struct{}{}:
		return true
	case <-time.After(d):
		return false
	}
}

func (s *Sandbox) unlock() {
	<-s.lockCh
}

// Sandbox returns the sandbox for a loaded extension.
func (r *Runtime) Sandbox(extID string) *Sandbox {
	return r.sandboxes[extID]
}

// SignedSessionSandboxIDs returns the ids of loaded sandboxes that declare a
// zarz signedSession config (and therefore participate in the Cloudflare
// keepalive / provisioning passes). Pandora and other non-zarz sources are
// naturally excluded because their manifest has no signedSession block.
func (r *Runtime) SignedSessionSandboxIDs() []string {
	ids := make([]string, 0, len(r.sandboxes))
	for id, sb := range r.sandboxes {
		if sb != nil && sb.SignedSession != nil {
			ids = append(ids, id)
		}
	}
	return ids
}

// Close cleans up all sandboxes. The lock wait is bounded (a sandbox stuck in
// a synchronous JS call must not hang app shutdown forever); if it can't be
// acquired we clear the interrupt anyway and drop the sandbox.
func (r *Runtime) Close() {
	for id, s := range r.sandboxes {
		if s.tryLock(2 * time.Second) {
			s.VM.ClearInterrupt()
			s.unlock()
		}
		delete(r.sandboxes, id)
	}
}
