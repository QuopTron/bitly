package gobackend

import "time"

// hasSignedSession reports whether an extension declares a signed-session
// config. Only those sources can be mid-bootstrap when the first feed fires,
// so only they are worth waiting on before retrying a zero-section result.
func tieneSesionFirmada(name string) bool {
	if extRegistry == nil || extRegistry.Runtime() == nil {
		return false
	}
	sb := extRegistry.Runtime().Sandbox(name)
	return sb != nil && sb.SignedSession != nil
}

// signedSessionSourceReady reports whether an extension's signed session is
// usable.
func signedSessionSourceReady(name string) bool {
	if extRegistry == nil || extRegistry.Runtime() == nil {
		return false
	}
	sb := extRegistry.Runtime().Sandbox(name)
	if sb == nil || sb.SignedSession == nil {
		return false
	}
	st := sb.SignedSessionStatus()
	auth, _ := st["authenticated"].(bool)
	return auth
}

// waitForSignedSession polls a signed-session source until its session is
// usable or the deadline passes. Bounded so a gateway that demands a human
// challenge (never becomes authenticated without the user) can't stall the
// whole feed — it only waits the full window when a bootstrap is genuinely
// in flight.
func waitForSignedSession(name string, maxWait time.Duration) bool {
	deadline := time.Now().Add(maxWait)
	for {
		if signedSessionSourceReady(name) {
			return true
		}
		if time.Now().After(deadline) {
			return false
		}
		time.Sleep(300 * time.Millisecond)
	}
}

// =========================================================================
