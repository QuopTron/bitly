package gobackend

import (
	"strings"
	"testing"
)

// TestSignedSessionStatusArgShape guards the fix for Android's reflection
// bridge: dispatchGoCall serializes the whole method args map
// ({"extension_id":"deezer"}) into the single String parameter, so
// GetSignedSessionStatus must accept BOTH that JSON shape and the bare
// extension id the desktop dispatcher passes. Before the fix, Android looked
// up a sandbox literally named '{"extension_id":"deezer"}', found none, and
// every provider reported unauthenticated — which re-triggered all Cloudflare
// verifications on every status/session check.
func TestSignedSessionStatusArgShape(t *testing.T) {
	InitGlobalState()

	raw := GetSignedSessionStatus("deezer")
	jsonShape := GetSignedSessionStatus(`{"extension_id":"deezer"}`)

	if strings.Contains(raw, "no cargada") {
		t.Fatalf("bare-id shape failed sandbox lookup: %s", raw)
	}
	if raw != jsonShape {
		t.Fatalf("arg shapes disagree:\n  raw : %s\n  json: %s", raw, jsonShape)
	}
	if strings.Contains(jsonShape, "authenticated\":true") {
		// A host test has no session; the point is the sandbox resolves and the
		// status is a real (unauthenticated) status, not a lookup failure.
		t.Fatalf("unexpected authenticated status without a session: %s", jsonShape)
	}
}
