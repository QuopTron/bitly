package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/playback"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

// RegisterPlaybackHandlers registers playback-related RPC methods.
// Uses the real playback.PlayTrack, playback.Pause, etc. from internal/playback/exports.go
func RegisterPlaybackHandlers(reg *rpc.Registry) {
	reg.Register("playbackPlayTrack", func(params map[string]interface{}) (interface{}, error) {
		trackJSON := rpc.Sp(params, "track")
		if trackJSON == "" {
			return nil, nil
		}
		return playback.PlayTrack(trackJSON), nil
	})

	reg.Register("playbackPause", func(params map[string]interface{}) (interface{}, error) {
		return playback.Pause(), nil
	})

	reg.Register("playbackResume", func(params map[string]interface{}) (interface{}, error) {
		return playback.Resume(), nil
	})

	reg.Register("playbackStop", func(params map[string]interface{}) (interface{}, error) {
		return playback.Stop(), nil
	})

	reg.Register("playbackSeek", func(params map[string]interface{}) (interface{}, error) {
		return `{"success":true}`, nil
	})

	reg.Register("playbackNext", func(params map[string]interface{}) (interface{}, error) {
		return playback.Next(), nil
	})

	reg.Register("playbackPrevious", func(params map[string]interface{}) (interface{}, error) {
		return playback.Previous(), nil
	})

	reg.Register("playbackGetState", func(params map[string]interface{}) (interface{}, error) {
		return playback.GetState(), nil
	})

	reg.Register("playbackGetQueue", func(params map[string]interface{}) (interface{}, error) {
		return playback.GetQueue(), nil
	})

	reg.Register("playbackGetHistory", func(params map[string]interface{}) (interface{}, error) {
		limit := rpc.Sn(params, "limit")
		if limit <= 0 {
			limit = 20
		}
		return playback.GetHistory(limit), nil
	})

	reg.Register("playbackSetQueue", func(params map[string]interface{}) (interface{}, error) {
		tracksJSON := rpc.Sp(params, "tracks")
		if tracksJSON == "" {
			return `{"success":false,"error":"empty queue"}`, nil
		}
		return playback.SetQueue(tracksJSON), nil
	})

	reg.Register("playbackAddToQueue", func(params map[string]interface{}) (interface{}, error) {
		tracksJSON := rpc.Sp(params, "tracks")
		if tracksJSON == "" {
			return `{"success":false,"error":"empty tracks"}`, nil
		}
		return playback.AddToQueue(tracksJSON), nil
	})

	reg.Register("playbackRemoveFromQueue", func(params map[string]interface{}) (interface{}, error) {
		index := rpc.Sn(params, "index")
		return playback.RemoveFromQueue(index), nil
	})

	reg.Register("playbackClearQueue", func(params map[string]interface{}) (interface{}, error) {
		return playback.ClearQueue(), nil
	})

	reg.Register("playbackSetShuffle", func(params map[string]interface{}) (interface{}, error) {
		enabled := rpc.Sn(params, "shuffle") == 1
		return playback.SetShuffle(enabled), nil
	})

	reg.Register("playbackSetRepeat", func(params map[string]interface{}) (interface{}, error) {
		mode := rpc.Sp(params, "mode")
		if mode == "" {
			mode = "none"
		}
		return playback.SetRepeat(mode), nil
	})

	reg.Register("playbackTrackCompleted", func(params map[string]interface{}) (interface{}, error) {
		return playback.TrackCompleted(), nil
	})

	reg.Register("playbackUpdatePosition", func(params map[string]interface{}) (interface{}, error) {
		position := int64(rpc.Sn(params, "position_ms"))
		playback.UpdatePosition(position)
		return `{"success":true}`, nil
	})

	reg.Register("playbackSyncQueueState", func(params map[string]interface{}) (interface{}, error) {
		stateJSON := rpc.Sp(params, "state")
		if stateJSON == "" {
			return `{"success":false,"error":"empty state"}`, nil
		}
		return playback.SyncQueueState(stateJSON), nil
	})

	reg.Register("getSimilarTracks", func(params map[string]interface{}) (interface{}, error) {
		requestJSON := rpc.Sp(params, "request")
		if requestJSON == "" {
			return "[]", nil
		}
		return playback.GetSimilarTracksJSON(requestJSON), nil
	})

	reg.Register("playbackTrackFromDownload", func(params map[string]interface{}) (interface{}, error) {
		requestJSON := rpc.Sp(params, "request")
		if requestJSON == "" {
			return nil, nil
		}
		track, err := playback.TrackFromDownload(requestJSON)
		if err != nil {
			return nil, err
		}
		return track, nil
	})
}
