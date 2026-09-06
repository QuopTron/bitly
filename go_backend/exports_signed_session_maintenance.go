package gobackend

import (
	"encoding/json"
	"sync"
)

// =========================================================================
// EXTENSIONS — Signed Session maintenance (provision + keepalive)
//
// Both exports drive every zarz v2 sandbox at once, in parallel, each bounded
// by the sandbox's keepalive short-timeout client (a few seconds), so a hung
// gateway can never stall the app's startup or a background keepalive tick.
// Neither export ever opens UI: sources that need a human challenge are only
// flagged (needs_verification) and the modal is shown by the explicit-action
// flows (play/search/download) on demand.
// =========================================================================

// ProvisionSignedSessions is the startup provisioning pass. For every zarz v2
// sandbox it: reports status, silently refreshes a valid-but-near-expiry
// session, and attempts a silent bootstrap when the session is missing or
// expired. If the gateway demands a human challenge the source is flagged
// needs_verification — no modal is opened here (only explicit actions ask).
//
// Flutter contract: {} or {"extension_ids":[...]} → {extID: status}.
func ProvisionSignedSessions(payload string) string {
	ids := signedSessionMaintenanceTargets(payload)
	type outcome struct {
		id string
		m  map[string]any
	}
	ch := make(chan outcome, len(ids))
	var wg sync.WaitGroup
	for _, id := range ids {
		wg.Add(1)
		go func(extID string) {
			defer wg.Done()
			sb := signedSessionSandbox(extID)
			if sb == nil || sb.SignedSession == nil {
				ch <- outcome{extID, map[string]any{
					"authenticated": false, "refreshed": false,
					"needs_verification": false, "error": "signedSession is not configured",
				}}
				return
			}
			// SignedSessionProvision serializes record mutation through the
			// session state's own locks (loadOrInit + bootstrap guard + keepalive
			// guard), matching SignedSessionAuthURL. We deliberately do NOT hold
			// the sandbox Mu across the network call: that lock guards the goja
			// VM and a slow gateway would otherwise stall any JS download
			// running on this extension for the whole refresh.
			ch <- outcome{extID, sb.SignedSessionProvision()}
		}(id)
	}
	wg.Wait()
	close(ch)

	results := map[string]any{}
	for o := range ch {
		results[o.id] = o.m
	}
	data, _ := json.Marshal(results)
	return string(data)
}

// KeepAliveSignedSessions is the background keepalive pass. For every zarz v2
// sandbox it silently refreshes a still-valid session that is close to
// expiry — it never bootstraps and never produces a challenge (an expired
// session is simply left for an explicit user action).
//
// Flutter contract: {} or {"extension_ids":[...]} → {extID: status}.
func KeepAliveSignedSessions(payload string) string {
	ids := signedSessionMaintenanceTargets(payload)
	type outcome struct {
		id string
		m  map[string]any
	}
	ch := make(chan outcome, len(ids))
	var wg sync.WaitGroup
	for _, id := range ids {
		wg.Add(1)
		go func(extID string) {
			defer wg.Done()
			sb := signedSessionSandbox(extID)
			if sb == nil || sb.SignedSession == nil {
				ch <- outcome{extID, map[string]any{
					"authenticated": false, "refreshed": false,
					"needs_verification": false, "error": "signedSession is not configured",
				}}
				return
			}
			// SignedSessionKeepAlive serializes record mutation through the
			// session state's own locks (loadOrInit + keepalive guard), matching
			// SignedSessionStatus. The sandbox Mu is intentionally NOT held
			// across the network call (see ProvisionSignedSessions above).
			ch <- outcome{extID, sb.SignedSessionKeepAlive()}
		}(id)
	}
	wg.Wait()
	close(ch)

	results := map[string]any{}
	for o := range ch {
		results[o.id] = o.m
	}
	data, _ := json.Marshal(results)
	return string(data)
}

// signedSessionMaintenanceTargets resolves the extension ids to run a
// maintenance pass over: the payload's extension_ids when provided, otherwise
// every loaded zarz v2 sandbox (SignedSession != nil).
func signedSessionMaintenanceTargets(payload string) []string {
	var params struct {
		ExtensionIDs []string `json:"extension_ids"`
	}
	if payload != "" {
		_ = json.Unmarshal([]byte(payload), &params)
	}
	if len(params.ExtensionIDs) > 0 {
		seen := map[string]bool{}
		ids := make([]string, 0, len(params.ExtensionIDs))
		for _, id := range params.ExtensionIDs {
			if id != "" && !seen[id] {
				seen[id] = true
				ids = append(ids, id)
			}
		}
		return ids
	}
	if extRegistry == nil || extRegistry.Runtime() == nil {
		return nil
	}
	return extRegistry.Runtime().SignedSessionSandboxIDs()
}
