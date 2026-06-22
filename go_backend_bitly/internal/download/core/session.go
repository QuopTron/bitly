package core

import (
	"sync"
	"time"
)

// Session tracks a single download session (for progress reporting).
type Session struct {
	ItemID     string
	Status     string // pending, downloading, completed, failed, cancelled
	Progress   float64
	BytesTotal int64
	BytesDone  int64
	Error      string
	StartedAt  time.Time
}

// SessionManager tracks multiple download sessions.
type SessionManager struct {
	mu       sync.RWMutex
	sessions map[string]*Session
}

// NewSessionManager creates a new session manager.
func NewSessionManager() *SessionManager {
	return &SessionManager{
		sessions: make(map[string]*Session),
	}
}

// StartSession begins tracking a new download.
func (sm *SessionManager) StartSession(itemID string) *Session {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	s := &Session{
		ItemID:    itemID,
		Status:    "pending",
		StartedAt: time.Now(),
	}
	sm.sessions[itemID] = s
	return s
}

// GetSession retrieves a download session.
func (sm *SessionManager) GetSession(itemID string) *Session {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	return sm.sessions[itemID]
}

// CompleteSession marks a session as completed.
func (sm *SessionManager) CompleteSession(itemID string) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	if s, ok := sm.sessions[itemID]; ok {
		s.Status = "completed"
		s.Progress = 100
	}
}

// FailSession marks a session as failed.
func (sm *SessionManager) FailSession(itemID, errMsg string) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	if s, ok := sm.sessions[itemID]; ok {
		s.Status = "failed"
		s.Error = errMsg
	}
}

// RemoveSession removes a session from tracking.
func (sm *SessionManager) RemoveSession(itemID string) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	delete(sm.sessions, itemID)
}
