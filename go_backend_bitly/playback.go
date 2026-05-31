package gobackend

import (
	"encoding/json"
	"fmt"
	"sync"
	"time"
)

// PlaybackState represents the current playback state
type PlaybackState struct {
	mu sync.RWMutex

	IsPlaying    bool            `json:"is_playing"`
	CurrentTrack *PlaybackTrack  `json:"current_track,omitempty"`
	Position     int64           `json:"position_ms"` // Current position in milliseconds
	Duration     int64           `json:"duration_ms"` // Total duration in milliseconds
	Volume       float64         `json:"volume"`      // 0.0 to 1.0
	Shuffle      bool            `json:"shuffle"`
	RepeatMode   string          `json:"repeat_mode"` // "none", "all", "one"
	Queue        []PlaybackTrack `json:"queue,omitempty"`
	QueueIndex   int             `json:"queue_index"`       // Current index in queue
	History      []PlaybackTrack `json:"history,omitempty"` // Recently played (last 50)
	Timestamp    int64           `json:"timestamp"`         // Last update timestamp
}

// PlaybackTrack represents a track in playback context
type PlaybackTrack struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	ArtistName string `json:"artist_name"`
	AlbumName  string `json:"album_name,omitempty"`
	CoverURL   string `json:"cover_url,omitempty"`
	ISRC       string `json:"isrc,omitempty"`
	Duration   int    `json:"duration_ms"`
	LocalPath  string `json:"local_path,omitempty"`
	Source     string `json:"source,omitempty"`  // "local", "streaming", etc.
	Service    string `json:"service,omitempty"` // Which service provided it
}

var (
	playbackState     *PlaybackState
	playbackStateOnce sync.Once
	playbackActions   = make(chan PlaybackAction, 100)
)

// PlaybackAction represents an action to perform on playback
type PlaybackAction struct {
	Type     string                 `json:"type"`
	Track    *PlaybackTrack         `json:"track,omitempty"`
	Position int64                  `json:"position_ms,omitempty"`
	Tracks   []PlaybackTrack        `json:"tracks,omitempty"`
	Params   map[string]interface{} `json:"params,omitempty"`
}

// GetPlaybackState returns the current playback state
func GetPlaybackState() *PlaybackState {
	playbackStateOnce.Do(func() {
		playbackState = &PlaybackState{
			IsPlaying:  false,
			Volume:     1.0,
			RepeatMode: "none",
			Queue:      make([]PlaybackTrack, 0),
			History:    make([]PlaybackTrack, 0, 50),
			Timestamp:  time.Now().UnixMilli(),
		}
		// Start the playback action processor
		go playbackActionProcessor()
	})
	return playbackState
}

// playbackActionProcessor processes playback actions in sequence
func playbackActionProcessor() {
	for action := range playbackActions {
		state := GetPlaybackState()
		state.mu.Lock()

		switch action.Type {
		case "play":
			if action.Track != nil {
				// Add current to history if exists
				if state.CurrentTrack != nil {
					state.addToHistory(*state.CurrentTrack)
				}
				state.CurrentTrack = action.Track
				state.Position = 0
				state.Duration = int64(action.Track.Duration)
				state.IsPlaying = true
				GoLog("[Playback] Playing: %s - %s (local=%v)\n",
					action.Track.Name, action.Track.ArtistName,
					action.Track.LocalPath != "")
			}

		case "pause":
			state.IsPlaying = false
			GoLog("[Playback] Paused at %dms\n", state.Position)

		case "resume":
			if state.CurrentTrack != nil {
				state.IsPlaying = true
				GoLog("[Playback] Resumed at %dms\n", state.Position)
			}

		case "stop":
			state.IsPlaying = false
			state.Position = 0
			GoLog("[Playback] Stopped\n")

		case "seek":
			if action.Position >= 0 && action.Position <= state.Duration {
				state.Position = action.Position
				GoLog("[Playback] Seek to %dms\n", action.Position)
			}

		case "set_queue":
			if action.Tracks != nil {
				state.Queue = action.Tracks
				state.QueueIndex = 0
				GoLog("[Playback] Queue set with %d tracks\n", len(action.Tracks))
			}

		case "add_to_queue":
			if action.Tracks != nil {
				state.Queue = append(state.Queue, action.Tracks...)
				GoLog("[Playback] Added %d tracks to queue\n", len(action.Tracks))
			}

		case "next":
			state.advanceNext()

		case "previous":
			state.goPrevious()

		case "set_shuffle":
			if v, ok := action.Params["shuffle"].(bool); ok {
				state.Shuffle = v
				GoLog("[Playback] Shuffle: %v\n", v)
			}

		case "set_repeat":
			if v, ok := action.Params["repeat_mode"].(string); ok {
				state.RepeatMode = v
				GoLog("[Playback] Repeat: %s\n", v)
			}

		case "remove_from_queue":
			if idx, ok := action.Params["index"].(int); ok && idx >= 0 && idx < len(state.Queue) {
				state.Queue = append(state.Queue[:idx], state.Queue[idx+1:]...)
				if idx < state.QueueIndex {
					state.QueueIndex--
				} else if idx == state.QueueIndex && state.QueueIndex >= len(state.Queue) {
					state.QueueIndex = len(state.Queue) - 1
				}
			}

		case "clear_queue":
			state.Queue = make([]PlaybackTrack, 0)
			state.QueueIndex = -1
			GoLog("[Playback] Queue cleared\n")

		case "track_completed":
			if state.CurrentTrack != nil {
				state.addToHistory(*state.CurrentTrack)
			}
			state.advanceNext()
		}

		state.Timestamp = time.Now().UnixMilli()
		state.mu.Unlock()
	}
}

// addToHistory adds a track to playback history (keep last 50)
func (s *PlaybackState) addToHistory(track PlaybackTrack) {
	// Don't add if it's the same as the most recent
	if len(s.History) > 0 && s.History[len(s.History)-1].ID == track.ID {
		return
	}

	s.History = append(s.History, track)
	if len(s.History) > 50 {
		s.History = s.History[len(s.History)-50:]
	}
}

// advanceNext moves to next track in queue
func (s *PlaybackState) advanceNext() {
	if len(s.Queue) == 0 {
		if s.CurrentTrack != nil {
			s.addToHistory(*s.CurrentTrack)
		}
		s.CurrentTrack = nil
		s.IsPlaying = false
		GoLog("[Playback] End of queue\n")
		return
	}

	if s.RepeatMode == "one" && s.CurrentTrack != nil {
		// Replay same track
		GoLog("[Playback] Repeating: %s\n", s.CurrentTrack.Name)
		return
	}

	// Move current to history
	if s.CurrentTrack != nil {
		s.addToHistory(*s.CurrentTrack)
	}

	if s.Shuffle {
		if len(s.Queue) > 0 {
			idx := 0
			if len(s.Queue) > 1 && s.CurrentTrack != nil {
				for {
					idx = int(time.Now().UnixNano() % int64(len(s.Queue)))
					if s.Queue[idx].ID != s.CurrentTrack.ID {
						break
					}
				}
			}
			s.QueueIndex = idx
			s.CurrentTrack = &s.Queue[idx]
			s.Position = 0
			s.Duration = int64(s.CurrentTrack.Duration)
			s.IsPlaying = true
			GoLog("[Playback] Shuffle next: %s - %s\n",
				s.CurrentTrack.Name, s.CurrentTrack.ArtistName)
		}
	} else {
		// Sequential
		if s.QueueIndex < len(s.Queue)-1 {
			s.QueueIndex++
			s.CurrentTrack = &s.Queue[s.QueueIndex]
			s.Position = 0
			s.Duration = int64(s.CurrentTrack.Duration)
			s.IsPlaying = true
			GoLog("[Playback] Next: %s - %s\n",
				s.CurrentTrack.Name, s.CurrentTrack.ArtistName)
		} else if s.RepeatMode == "all" {
			// Wrap to beginning
			s.QueueIndex = 0
			s.CurrentTrack = &s.Queue[0]
			s.Position = 0
			s.Duration = int64(s.CurrentTrack.Duration)
			s.IsPlaying = true
			GoLog("[Playback] Repeat all, starting: %s - %s\n",
				s.CurrentTrack.Name, s.CurrentTrack.ArtistName)
		} else {
			// End of queue
			s.CurrentTrack = nil
			s.IsPlaying = false
			GoLog("[Playback] End of queue\n")
		}
	}
}

// goPrevious goes to previous track (from history or queue)
func (s *PlaybackState) goPrevious() {
	if len(s.History) == 0 {
		if s.QueueIndex > 0 && len(s.Queue) > 0 {
			s.QueueIndex--
			s.CurrentTrack = &s.Queue[s.QueueIndex]
			s.Position = 0
			s.Duration = int64(s.CurrentTrack.Duration)
			s.IsPlaying = true
			GoLog("[Playback] Previous (queue): %s\n", s.CurrentTrack.Name)
		}
		return
	}

	// Get last from history
	prevTrack := s.History[len(s.History)-1]
	s.History = s.History[:len(s.History)-1]

	// If we have a current track, add it back to queue at current position
	if s.CurrentTrack != nil {
		// Put current track back into queue if it's not already there
		found := false
		for _, t := range s.Queue {
			if t.ID == s.CurrentTrack.ID {
				found = true
				break
			}
		}
		if !found {
			s.Queue = append(s.Queue[:s.QueueIndex], append([]PlaybackTrack{*s.CurrentTrack}, s.Queue[s.QueueIndex:]...)...)
		}
	}

	// Set previous as current
	for i, t := range s.Queue {
		if t.ID == prevTrack.ID {
			s.QueueIndex = i
			break
		}
	}

	s.CurrentTrack = &prevTrack
	s.Position = 0
	s.Duration = int64(prevTrack.Duration)
	s.IsPlaying = true
	GoLog("[Playback] Previous (history): %s - %s\n",
		prevTrack.Name, prevTrack.ArtistName)
}

// SendPlaybackAction sends an action to the playback processor
func SendPlaybackAction(action PlaybackAction) {
	select {
	case playbackActions <- action:
	default:
		// Channel full, process synchronously
		processPlaybackActionSync(action)
	}
}

func processPlaybackActionSync(action PlaybackAction) {
	state := GetPlaybackState()
	state.mu.Lock()
	defer state.mu.Unlock()

	// Same logic as playbackActionProcessor but synchronous
	switch action.Type {
	case "play":
		if action.Track != nil {
			if state.CurrentTrack != nil {
				state.addToHistory(*state.CurrentTrack)
			}
			state.CurrentTrack = action.Track
			state.Position = 0
			state.Duration = int64(action.Track.Duration)
			state.IsPlaying = true
		}
	case "pause":
		state.IsPlaying = false
	case "resume":
		if state.CurrentTrack != nil {
			state.IsPlaying = true
		}
	case "stop":
		state.IsPlaying = false
		state.Position = 0
	case "seek":
		if action.Position >= 0 && action.Position <= state.Duration {
			state.Position = action.Position
		}
	case "set_queue":
		if action.Tracks != nil {
			state.Queue = action.Tracks
			state.QueueIndex = 0
		}
	case "add_to_queue":
		if action.Tracks != nil {
			state.Queue = append(state.Queue, action.Tracks...)
		}
	case "next":
		state.advanceNext()
	case "previous":
		state.goPrevious()
	case "set_shuffle":
		if v, ok := action.Params["shuffle"].(bool); ok {
			state.Shuffle = v
		}
	case "set_repeat":
		if v, ok := action.Params["repeat_mode"].(string); ok {
			state.RepeatMode = v
		}
	case "track_completed":
		if state.CurrentTrack != nil {
			state.addToHistory(*state.CurrentTrack)
		}
		state.advanceNext()
	}
	state.Timestamp = time.Now().UnixMilli()
}

// GetPlaybackStateJSON returns the current state as JSON
func GetPlaybackStateJSON() string {
	state := GetPlaybackState()
	state.mu.RLock()
	defer state.mu.RUnlock()

	jsonBytes, err := json.Marshal(state)
	if err != nil {
		return fmt.Sprintf(`{"error":"%s"}`, err.Error())
	}
	return string(jsonBytes)
}

// GetPlaybackHistoryJSON returns playback history as JSON
func GetPlaybackHistoryJSON(limit int) string {
	state := GetPlaybackState()
	state.mu.RLock()
	defer state.mu.RUnlock()

	if limit <= 0 || limit > len(state.History) {
		limit = len(state.History)
	}

	// Return reversed (most recent first)
	reversed := make([]PlaybackTrack, limit)
	for i := 0; i < limit; i++ {
		reversed[i] = state.History[len(state.History)-1-i]
	}

	jsonBytes, err := json.Marshal(map[string]interface{}{
		"history":  reversed,
		"total":    len(state.History),
		"returned": limit,
	})
	if err != nil {
		return fmt.Sprintf(`{"error":"%s"}`, err.Error())
	}
	return string(jsonBytes)
}

// GetPlaybackQueueJSON returns the current queue as JSON
func GetPlaybackQueueJSON() string {
	state := GetPlaybackState()
	state.mu.RLock()
	defer state.mu.RUnlock()

	jsonBytes, err := json.Marshal(map[string]interface{}{
		"queue":       state.Queue,
		"queue_index": state.QueueIndex,
		"current":     state.CurrentTrack,
	})
	if err != nil {
		return fmt.Sprintf(`{"error":"%s"}`, err.Error())
	}
	return string(jsonBytes)
}

// SetPlaybackPosition updates the current position
func SetPlaybackPosition(positionMs int64) {
	state := GetPlaybackState()
	state.mu.Lock()
	defer state.mu.Unlock()
	state.Position = positionMs
	state.Timestamp = time.Now().UnixMilli()
}
