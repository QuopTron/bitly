package playback

import "time"

func applyAction(ps *PlaybackState, action PlaybackAction) {
	switch action.Type {
	case ActionPlay:
		if action.Track != nil {
			if ps.CurrentTrack != nil {
				addToHistory(ps, *ps.CurrentTrack)
			}
			ps.CurrentTrack = action.Track
			ps.Position = 0
			ps.Duration = int64(action.Track.Duration)
			ps.IsPlaying = true
		}

	case ActionPause:
		ps.IsPlaying = false

	case ActionResume:
		if ps.CurrentTrack != nil {
			ps.IsPlaying = true
		}

	case ActionStop:
		ps.IsPlaying = false
		ps.Position = 0

	case ActionSeek:
		if action.Position >= 0 && (ps.Duration == 0 || action.Position <= ps.Duration) {
			ps.Position = action.Position
		}

	case ActionSetQueue:
		if action.Tracks != nil {
			oldCurrentID := ""
			if ps.QueueIndex >= 0 && ps.QueueIndex < len(ps.Queue) {
				oldCurrentID = ps.Queue[ps.QueueIndex].ID
			}
			ps.Queue = action.Tracks
			ps.QueueIndex = 0
			if oldCurrentID != "" {
				for i, t := range ps.Queue {
					if t.ID == oldCurrentID {
						ps.QueueIndex = i
						break
					}
				}
			}
		}

	case ActionAddToQueue:
		if action.Tracks != nil {
			ps.Queue = append(ps.Queue, action.Tracks...)
		}

	case ActionRemoveFromQueue:
		var idx int
		if v, ok := action.Params["index"].(int); ok {
			idx = v
		} else if v, ok := action.Params["index"].(float64); ok {
			idx = int(v)
		}
		if idx >= 0 && idx < len(ps.Queue) {
			ps.Queue = append(ps.Queue[:idx], ps.Queue[idx+1:]...)
			if idx < ps.QueueIndex {
				ps.QueueIndex--
			} else if idx == ps.QueueIndex && ps.QueueIndex >= len(ps.Queue) {
				ps.QueueIndex = len(ps.Queue) - 1
			}
		}

	case ActionClearQueue:
		ps.Queue = make([]PlaybackTrack, 0)
		ps.QueueIndex = -1

	case ActionNext:
		advanceNext(ps)

	case ActionPrevious:
		goPrevious(ps)

	case ActionSetShuffle:
		if v, ok := action.Params["shuffle"].(bool); ok {
			ps.Shuffle = v
		}

	case ActionSetRepeat:
		if v, ok := action.Params["repeat_mode"].(string); ok {
			ps.RepeatMode = v
		}

	case ActionTrackCompleted:
		if ps.CurrentTrack != nil {
			addToHistory(ps, *ps.CurrentTrack)
		}
		advanceNext(ps)
	}

	ps.Timestamp = time.Now().UnixMilli()
}
