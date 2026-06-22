package playback

import (
	"encoding/json"
	"fmt"
)

func errorResponse(msg string) string {
	return fmt.Sprintf(`{"success":false,"error":"%s"}`, msg)
}

func PlayTrack(trackJSON string) string {
	var track PlaybackTrack
	if err := json.Unmarshal([]byte(trackJSON), &track); err != nil {
		return errorResponse("Invalid track data: " + err.Error())
	}
	SendAction(PlaybackAction{Type: ActionPlay, Track: &track})
	return `{"success":true,"action":"play"}`
}

func Pause() string {
	SendAction(PlaybackAction{Type: ActionPause})
	return `{"success":true,"action":"pause"}`
}

func Resume() string {
	SendAction(PlaybackAction{Type: ActionResume})
	return `{"success":true,"action":"resume"}`
}

func Stop() string {
	SendAction(PlaybackAction{Type: ActionStop})
	return `{"success":true,"action":"stop"}`
}

func Seek(positionMs int64) string {
	SendAction(PlaybackAction{Type: ActionSeek, Position: positionMs})
	return fmt.Sprintf(`{"success":true,"action":"seek","position":%d}`, positionMs)
}

func Next() string {
	SendAction(PlaybackAction{Type: ActionNext})
	return `{"success":true,"action":"next"}`
}

func Previous() string {
	SendAction(PlaybackAction{Type: ActionPrevious})
	return `{"success":true,"action":"previous"}`
}

func SetQueue(tracksJSON string) string {
	var tracks []PlaybackTrack
	if err := json.Unmarshal([]byte(tracksJSON), &tracks); err != nil {
		return errorResponse("Invalid queue data: " + err.Error())
	}
	SendAction(PlaybackAction{Type: ActionSetQueue, Tracks: tracks})
	return fmt.Sprintf(`{"success":true,"action":"set_queue","count":%d}`, len(tracks))
}

func AddToQueue(tracksJSON string) string {
	var tracks []PlaybackTrack
	if err := json.Unmarshal([]byte(tracksJSON), &tracks); err != nil {
		return errorResponse("Invalid tracks data: " + err.Error())
	}
	SendAction(PlaybackAction{Type: ActionAddToQueue, Tracks: tracks})
	return fmt.Sprintf(`{"success":true,"action":"add_to_queue","count":%d}`, len(tracks))
}

func RemoveFromQueue(index int) string {
	if index < 0 {
		return errorResponse("Invalid queue index")
	}
	SendAction(PlaybackAction{
		Type:   ActionRemoveFromQueue,
		Params: map[string]interface{}{"index": index},
	})
	return `{"success":true,"action":"remove_from_queue"}`
}

func ClearQueue() string {
	SendAction(PlaybackAction{Type: ActionClearQueue})
	return `{"success":true,"action":"clear_queue"}`
}

func SetShuffle(enabled bool) string {
	SendAction(PlaybackAction{
		Type:   ActionSetShuffle,
		Params: map[string]interface{}{"shuffle": enabled},
	})
	return fmt.Sprintf(`{"success":true,"action":"set_shuffle","shuffle":%v}`, enabled)
}

func SetRepeat(mode string) string {
	SendAction(PlaybackAction{
		Type:   ActionSetRepeat,
		Params: map[string]interface{}{"repeat_mode": mode},
	})
	return fmt.Sprintf(`{"success":true,"action":"set_repeat","mode":"%s"}`, mode)
}

func TrackCompleted() string {
	SendAction(PlaybackAction{Type: ActionTrackCompleted})
	return `{"success":true,"action":"track_completed"}`
}
