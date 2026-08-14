package extensions

import (
	"net/http"
	"sync"
	"time"
)

// SignedSessionConfig defines how an extension obtains a Cloudflare signed session.
type SignedSessionConfig struct {
	Namespace         string `json:"namespace,omitempty"`
	BaseURL           string `json:"baseUrl,omitempty"`
	CallbackURL       string `json:"callbackUrl,omitempty"`
	AppVersion        string `json:"appVersion,omitempty"`
	Platform          string `json:"platform,omitempty"`
	SchemeLabel       string `json:"schemeLabel,omitempty"`
	Scheme            string `json:"scheme,omitempty"`
	HeaderPrefix      string `json:"headerPrefix,omitempty"`
	TimeWindowSeconds int    `json:"timeWindowSeconds,omitempty"`
	Endpoints         struct {
		Bootstrap string `json:"bootstrap,omitempty"`
		Challenge string `json:"challenge,omitempty"`
		Exchange  string `json:"exchange,omitempty"`
		Refresh   string `json:"refresh,omitempty"`
	} `json:"endpoints,omitempty"`
}

// SessionState represents a single signed session for an extension.
type SessionState struct {
	ExtensionID  string    `json:"extensionId"`
	Token        string    `json:"token"`
	RefreshToken string    `json:"refreshToken,omitempty"`
	ExpiresAt    time.Time `json:"expiresAt"`
	CreatedAt    time.Time `json:"createdAt"`
	Active       bool      `json:"active"`
}

// SessionStatus is returned to Flutter.
type SessionStatus struct {
	ExtensionID string `json:"extensionId"`
	HasToken    bool   `json:"hasToken"`
	Active      bool   `json:"active"`
	ExpiresIn   int    `json:"expiresIn"`
}

// SessionManager handles Cloudflare signed session lifecycle for extensions.
type SessionManager struct {
	mu       sync.RWMutex
	sessions map[string]*SessionState
	client   *http.Client
}

// NewSessionManager creates a new session manager.
func NewSessionManager() *SessionManager {
	return &SessionManager{
		sessions: make(map[string]*SessionState),
		client:   &http.Client{Timeout: 30 * time.Second},
	}
}

// GetSessionToken returns the current token for an extension session.
func (sm *SessionManager) GetSessionToken(extID string, config *SignedSessionConfig) (string, error) {
	sm.mu.RLock()
	state := sm.sessions[extID]
	sm.mu.RUnlock()

	if state == nil {
		return "", nil
	}
	if !state.Active {
		return "", nil
	}
	if time.Until(state.ExpiresAt) < 5*time.Minute {
		if state.RefreshToken != "" {
			newState, err := sm.RefreshSession(extID, config)
			if err == nil {
				return newState.Token, nil
			}
		}
	}
	token := state.Token
	if config != nil && config.HeaderPrefix != "" {
		token = config.HeaderPrefix + " " + token
	}
	return token, nil
}

// GetSessionStatus returns the status of an extension's session.
func (sm *SessionManager) GetSessionStatus(extID string) *SessionStatus {
	sm.mu.RLock()
	state := sm.sessions[extID]
	sm.mu.RUnlock()

	status := &SessionStatus{
		ExtensionID: extID,
		HasToken:    false,
		Active:      false,
		ExpiresIn:   0,
	}
	if state == nil {
		return status
	}
	status.HasToken = state.Token != ""
	status.Active = state.Active
	if state.Active && !state.ExpiresAt.IsZero() {
		expiresIn := int(time.Until(state.ExpiresAt).Seconds())
		if expiresIn > 0 {
			status.ExpiresIn = expiresIn
		}
	}
	return status
}
