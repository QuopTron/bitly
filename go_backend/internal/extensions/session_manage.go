package extensions

import (
	"time"
)

// ListActiveSessions returns all active sessions.
func (sm *SessionManager) ListActiveSessions() []*SessionStatus {
	sm.mu.RLock()
	defer sm.mu.RUnlock()

	var result []*SessionStatus
	for extID, state := range sm.sessions {
		if state.Active {
			status := &SessionStatus{
				ExtensionID: extID,
				HasToken:    state.Token != "",
				Active:      state.Active,
				ExpiresIn:   0,
			}
			if !state.ExpiresAt.IsZero() {
				expiresIn := int(time.Until(state.ExpiresAt).Seconds())
				if expiresIn > 0 {
					status.ExpiresIn = expiresIn
				}
			}
			result = append(result, status)
		}
	}
	if result == nil {
		result = []*SessionStatus{}
	}
	return result
}

// RevokeSession revokes an extension's session and marks it inactive.
func (sm *SessionManager) RevokeSession(extID string) {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	if state, ok := sm.sessions[extID]; ok {
		state.Active = false
		state.Token = ""
		state.RefreshToken = ""
	}
}

// StoreSessionToken manually stores a session token (e.g., restored from Flutter storage).
func (sm *SessionManager) StoreSessionToken(extID, token, refreshToken string, expiresIn int) {
	expiresAt := time.Now()
	if expiresIn > 0 {
		expiresAt = time.Now().Add(time.Duration(expiresIn) * time.Second)
	}

	state := &SessionState{
		ExtensionID:  extID,
		Token:        token,
		RefreshToken: refreshToken,
		ExpiresAt:    expiresAt,
		CreatedAt:    time.Now(),
		Active:       true,
	}

	sm.mu.Lock()
	sm.sessions[extID] = state
	sm.mu.Unlock()
}
