package gobackend

import (
	"encoding/json"
	"fmt"
)

func playbackErrorResponse(msg string) string {
	return fmt.Sprintf(`{"success":false,"error":"%s"}`, msg)
}

// Playback action types
const (
	PlaybackActionPlay           = "play"
	PlaybackActionPause          = "pause"
	PlaybackActionResume         = "resume"
	PlaybackActionStop           = "stop"
	PlaybackActionSeek           = "seek"
	PlaybackActionNext           = "next"
	PlaybackActionPrevious       = "previous"
	PlaybackActionSetQueue       = "set_queue"
	PlaybackActionAddToQueue     = "add_to_queue"
	PlaybackActionSetShuffle     = "set_shuffle"
	PlaybackActionSetRepeat      = "set_repeat"
	PlaybackActionTrackCompleted = "track_completed"
)

// PlaybackPlayTrack sets a track as currently playing
func PlaybackPlayTrack(trackJSON string) string {
	var track PlaybackTrack
	if err := json.Unmarshal([]byte(trackJSON), &track); err != nil {
		return playbackErrorResponse("Invalid track data: " + err.Error())
	}

	SendPlaybackAction(PlaybackAction{
		Type:  PlaybackActionPlay,
		Track: &track,
	})

	return `{"success":true,"action":"play"}`
}

// PlaybackPause pauses current playback
func PlaybackPause() string {
	SendPlaybackAction(PlaybackAction{Type: PlaybackActionPause})
	return `{"success":true,"action":"pause"}`
}

// PlaybackResume resumes playback
func PlaybackResume() string {
	SendPlaybackAction(PlaybackAction{Type: PlaybackActionResume})
	return `{"success":true,"action":"resume"}`
}

// PlaybackStop stops playback
func PlaybackStop() string {
	SendPlaybackAction(PlaybackAction{Type: PlaybackActionStop})
	return `{"success":true,"action":"stop"}`
}

// PlaybackSeek seeks to a position
func PlaybackSeek(positionMs int64) string {
	SendPlaybackAction(PlaybackAction{
		Type:     PlaybackActionSeek,
		Position: positionMs,
	})
	return fmt.Sprintf(`{"success":true,"action":"seek","position":%d}`, positionMs)
}

// PlaybackNext advances to next track
func PlaybackNext() string {
	SendPlaybackAction(PlaybackAction{Type: PlaybackActionNext})
	return `{"success":true,"action":"next"}`
}

// PlaybackPrevious goes to previous track
func PlaybackPrevious() string {
	SendPlaybackAction(PlaybackAction{Type: PlaybackActionPrevious})
	return `{"success":true,"action":"previous"}`
}

// PlaybackSetQueue sets the playback queue
func PlaybackSetQueue(tracksJSON string) string {
	var tracks []PlaybackTrack
	if err := json.Unmarshal([]byte(tracksJSON), &tracks); err != nil {
		return playbackErrorResponse("Invalid queue data: " + err.Error())
	}

	SendPlaybackAction(PlaybackAction{
		Type:   PlaybackActionSetQueue,
		Tracks: tracks,
	})

	return fmt.Sprintf(`{"success":true,"action":"set_queue","count":%d}`, len(tracks))
}

// PlaybackAddToQueue adds tracks to the queue
func PlaybackAddToQueue(tracksJSON string) string {
	var tracks []PlaybackTrack
	if err := json.Unmarshal([]byte(tracksJSON), &tracks); err != nil {
		return playbackErrorResponse("Invalid tracks data: " + err.Error())
	}

	SendPlaybackAction(PlaybackAction{
		Type:   PlaybackActionAddToQueue,
		Tracks: tracks,
	})

	return fmt.Sprintf(`{"success":true,"action":"add_to_queue","count":%d}`, len(tracks))
}

// PlaybackSetShuffle sets shuffle mode
func PlaybackSetShuffle(enabled bool) string {
	SendPlaybackAction(PlaybackAction{
		Type: PlaybackActionSetShuffle,
		Params: map[string]interface{}{
			"shuffle": enabled,
		},
	})
	return fmt.Sprintf(`{"success":true,"action":"set_shuffle","shuffle":%v}`, enabled)
}

// PlaybackSetRepeat sets repeat mode
func PlaybackSetRepeat(mode string) string {
	SendPlaybackAction(PlaybackAction{
		Type: PlaybackActionSetRepeat,
		Params: map[string]interface{}{
			"repeat_mode": mode,
		},
	})
	return fmt.Sprintf(`{"success":true,"action":"set_repeat","mode":"%s"}`, mode)
}

// PlaybackTrackCompleted marks current track as completed
func PlaybackTrackCompleted() string {
	SendPlaybackAction(PlaybackAction{Type: PlaybackActionTrackCompleted})
	return `{"success":true,"action":"track_completed"}`
}

// PlaybackGetState returns the current playback state as JSON
func PlaybackGetState() string {
	return GetPlaybackStateJSON()
}

// PlaybackGetHistory returns playback history as JSON
func PlaybackGetHistory(limit int) string {
	return GetPlaybackHistoryJSON(limit)
}

// PlaybackGetQueue returns current queue as JSON
func PlaybackGetQueue() string {
	return GetPlaybackQueueJSON()
}

// PlaybackUpdatePosition updates the current playback position
func PlaybackUpdatePosition(positionMs int64) {
	SetPlaybackPosition(positionMs)
}

// PlaybackTrackFromDownload creates a PlaybackTrack from download data
func PlaybackTrackFromDownload(requestJSON string) (*PlaybackTrack, error) {
	var req DownloadRequest
	if err := json.Unmarshal([]byte(requestJSON), &req); err != nil {
		return nil, err
	}

	return &PlaybackTrack{
		ID:         req.SpotifyID,
		Name:       req.TrackName,
		ArtistName: req.ArtistName,
		AlbumName:  req.AlbumName,
		CoverURL:   req.CoverURL,
		ISRC:       req.ISRC,
		Duration:   req.DurationMS,
		Service:    req.Service,
		Source:     req.Source,
	}, nil
}

// PlaybackRemoveFromQueue removes a track from queue by index
func PlaybackRemoveFromQueue(index int) string {
	state := GetPlaybackState()
	state.mu.Lock()
	defer state.mu.Unlock()

	if index < 0 || index >= len(state.Queue) {
		return playbackErrorResponse("Invalid queue index")
	}

	state.Queue = append(state.Queue[:index], state.Queue[index+1:]...)
	if index < state.QueueIndex {
		state.QueueIndex--
	} else if index == state.QueueIndex && state.QueueIndex >= len(state.Queue) {
		if len(state.Queue) > 0 {
			state.QueueIndex = len(state.Queue) - 1
		} else {
			state.QueueIndex = -1
		}
	}

	return `{"success":true,"action":"remove_from_queue"}`
}

// PlaybackClearQueue clears the playback queue
func PlaybackClearQueue() string {
	state := GetPlaybackState()
	state.mu.Lock()
	defer state.mu.Unlock()

	state.Queue = make([]PlaybackTrack, 0)
	state.QueueIndex = -1

	return `{"success":true,"action":"clear_queue"}`
}
