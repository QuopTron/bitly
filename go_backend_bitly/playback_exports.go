package gobackend

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"
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

// PlaybackSyncQueueState atomically replaces the full queue state (tracks + index + shuffle + repeat).
// This is the replacement for PlaybackSetQueue which had a bug resetting QueueIndex to 0.
func PlaybackSyncQueueState(stateJSON string) string {
	var incoming struct {
		Tracks       []PlaybackTrack `json:"tracks"`
		CurrentIndex int             `json:"current_index"`
		Shuffle      bool            `json:"shuffle"`
		RepeatMode   string          `json:"repeat_mode"`
	}
	if err := json.Unmarshal([]byte(stateJSON), &incoming); err != nil {
		return playbackErrorResponse("Invalid state data: " + err.Error())
	}

	ps := GetPlaybackState()
	ps.mu.Lock()
	defer ps.mu.Unlock()

	ps.Queue = incoming.Tracks
	ps.QueueIndex = incoming.CurrentIndex
	ps.Shuffle = incoming.Shuffle
	ps.RepeatMode = incoming.RepeatMode
	ps.Timestamp = time.Now().UnixMilli()

	GoLog("[Playback] Queue synced: %d tracks, index=%d, shuffle=%v, repeat=%s\n",
		len(incoming.Tracks), incoming.CurrentIndex, incoming.Shuffle, incoming.RepeatMode)

	return fmt.Sprintf(`{"success":true,"action":"sync_queue_state","count":%d}`, len(incoming.Tracks))
}

// GetSimilarTracksJSON finds similar tracks to autofill the queue when it ends.
// It searches for the artist on Deezer, fetches their top tracks,
// and returns them as a JSON array of TrackMetadata maps.
func GetSimilarTracksJSON(requestJSON string) string {
	startTime := time.Now()
	defer func() {
		GoLog("[SimilarTracks] Total time: %v\n", time.Since(startTime))
	}()

	GoLog("[SimilarTracks] <<< INCOMING REQUEST >>>\n")
	GoLog("[SimilarTracks] Request JSON: %s\n", requestJSON)

	var req struct {
		ArtistName string   `json:"artist_name"`
		TrackName  string   `json:"track_name"`
		Limit      int      `json:"limit"`
		ExcludeIDs []string `json:"exclude_ids"`
	}
	if err := json.Unmarshal([]byte(requestJSON), &req); err != nil {
		GoLog("[SimilarTracks] Failed to parse request JSON: %v\n", err)
		return playbackErrorResponse("Invalid request: " + err.Error())
	}

	if req.Limit <= 0 || req.Limit > 50 {
		req.Limit = 15
	}

	GoLog("[SimilarTracks] Parsed request: artist=%q track=%q limit=%d excludeIDs=%d\n",
		req.ArtistName, req.TrackName, req.Limit, len(req.ExcludeIDs))

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	client := GetDeezerClient()

	// Step 1: search for the artist to get Deezer artist ID
	GoLog("[SimilarTracks] Searching Deezer for artist: %s\n", req.ArtistName)
	searchResult, err := client.SearchAll(ctx, req.ArtistName, 0, 3, "artist")
	if err != nil {
		GoLog("[SimilarTracks] Deezer artist search error: %v\n", err)
	} else {
		GoLog("[SimilarTracks] Deezer found %d artists\n", len(searchResult.Artists))
		for i, a := range searchResult.Artists {
			GoLog("[SimilarTracks]   Artist[%d]: %s (ID: %s)\n", i, a.Name, a.ID)
		}
	}

	if err != nil || len(searchResult.Artists) == 0 {
		// Fallback: search tracks directly by artist name
		GoLog("[SimilarTracks] Artist search failed, falling back to track search for: %s\n", req.ArtistName)
		trackResult, trackErr := client.SearchAll(ctx, req.ArtistName, req.Limit, 0, "track")
		if trackErr != nil {
			GoLog("[SimilarTracks] Track search fallback error: %v\n", trackErr)
			return `[]`
		}
		GoLog("[SimilarTracks] Track search fallback found %d tracks\n", len(trackResult.Tracks))
		if len(trackResult.Tracks) == 0 {
			return `[]`
		}
		tracks := make([]map[string]interface{}, 0, len(trackResult.Tracks))
		for _, t := range trackResult.Tracks {
			tracks = append(tracks, similarTrackToMap(t))
		}
		enrichWithLocalAvailability(tracks)
		jsonBytes, _ := json.Marshal(tracks)
		GoLog("[SimilarTracks] Returning %d tracks from fallback, JSON size: %d bytes\n", len(tracks), len(jsonBytes))
		if len(tracks) > 0 {
			GoLog("[SimilarTracks] First fallback track keys: %v\n", getMapKeys(tracks[0]))
		}
		return string(jsonBytes)
	}

	// Use the best-matching artist
	artistID := strings.TrimPrefix(searchResult.Artists[0].ID, "deezer:")
	LogInfo("SimilarTracks", "Found artist: %s (ID: %s)", searchResult.Artists[0].Name, artistID)

	// Step 2: get top tracks for this artist
	GoLog("[SimilarTracks] Fetching top tracks for artist ID: %s (limit: %d)\n", artistID, req.Limit+5)
	topTracks, err := client.GetArtistTopTracks(ctx, artistID, req.Limit+5) // fetch extra for filtering
	if err != nil {
		GoLog("[SimilarTracks] GetArtistTopTracks error: %v\n", err)
		return `[]`
	}
	GoLog("[SimilarTracks] GetArtistTopTracks returned %d tracks from Deezer\n", len(topTracks))
	if len(topTracks) == 0 {
		GoLog("[SimilarTracks] No top tracks from Deezer, returning empty\n")
		return `[]`
	}

	// Step 3: filter out excluded tracks (current playing track)
	excludeSet := make(map[string]struct{}, len(req.ExcludeIDs))
	for _, id := range req.ExcludeIDs {
		if id != "" {
			normalized := strings.ToLower(strings.TrimSpace(id))
			excludeSet[normalized] = struct{}{}
			GoLog("[SimilarTracks] Will exclude track ID: %s\n", id)
		}
	}
	GoLog("[SimilarTracks] Exclude set has %d IDs\n", len(excludeSet))

	result := make([]map[string]interface{}, 0, req.Limit)
	excludedCount := 0
	for _, t := range topTracks {
		if len(result) >= req.Limit {
			GoLog("[SimilarTracks] Reached limit of %d, skipping remaining %d tracks\n", req.Limit, len(topTracks)-len(result))
			break
		}
		trackID := strings.ToLower(strings.TrimSpace(t.SpotifyID))
		if _, excluded := excludeSet[trackID]; excluded {
			GoLog("[SimilarTracks]   Excluded: %s - %s (ID: %s)\n", t.Artists, t.Name, t.SpotifyID)
			excludedCount++
			continue
		}
		if trackID != "" {
			excludeSet[trackID] = struct{}{}
		}
		result = append(result, similarTrackToMap(t))
	}

	GoLog("[SimilarTracks] Filtering: %d top tracks -> excluded %d -> kept %d\n", len(topTracks), excludedCount, len(result))

	if len(result) == 0 {
		GoLog("[SimilarTracks] No tracks after filtering primary artist, trying related artists...\n")
		// Fallback: look up related artists and get their top tracks
		relatedResult, relatedErr := fetchRelatedArtistsTopTracks(ctx, client, artistID, req)
		if relatedErr == nil && len(relatedResult) > 0 {
			enrichWithLocalAvailability(relatedResult)
			jsonBytes, _ := json.Marshal(relatedResult)
			LogInfo("SimilarTracks", "Returning %d tracks from related artists (JSON size: %d bytes)", len(relatedResult), len(jsonBytes))
			return string(jsonBytes)
		}
		GoLog("[SimilarTracks] Related artists also returned nothing, returning empty\n")
		return `[]`
	}

	// If fewer than 3 tracks from primary artist, supplement with related artists
	if len(result) < 3 {
		GoLog("[SimilarTracks] Only %d tracks from primary artist, supplementing with related artists...\n", len(result))
		relatedResult, relatedErr := fetchRelatedArtistsTopTracks(ctx, client, artistID, req)
		if relatedErr == nil && len(relatedResult) > 0 {
			// Mix primary artist tracks first, then supplement with related artists
			seen := make(map[string]struct{}, len(excludeSet))
			for _, m := range result {
				for k, v := range m {
					if k == "id" {
						id, _ := v.(string)
						if id != "" {
							seen[strings.ToLower(strings.TrimSpace(id))] = struct{}{}
						}
					}
				}
			}
			for _, m := range relatedResult {
				if len(result) >= req.Limit {
					break
				}
				for k, v := range m {
					if k == "id" {
						id, _ := v.(string)
						if id != "" {
							lowerID := strings.ToLower(strings.TrimSpace(id))
							if _, dup := seen[lowerID]; dup {
								GoLog("[SimilarTracks]   Skipping related duplicate: %s\n", id)
								continue
							}
							seen[lowerID] = struct{}{}
						}
					}
				}
				result = append(result, m)
			}
			GoLog("[SimilarTracks] Supplemented to %d tracks (mix of primary + related)\n", len(result))
		}
	}

	enrichWithLocalAvailability(result)
	jsonBytes, _ := json.Marshal(result)
	if len(result) > 0 {
		GoLog("[SimilarTracks] First result keys: %v\n", getMapKeys(result[0]))
		GoLog("[SimilarTracks] First result sample: %s\n", truncateJSON(result[0], 300))
	}
	LogInfo("SimilarTracks", "Returning %d similar tracks (JSON size: %d bytes)", len(result), len(jsonBytes))
	return string(jsonBytes)
}

// similarTrackToMap converts a TrackMetadata into a flat map matching Flutter's Track.fromJson format.
// Keys must be camelCase to match the json_annotation serialization in Dart.
func similarTrackToMap(t TrackMetadata) map[string]interface{} {
	return map[string]interface{}{
		"id":           t.SpotifyID,
		"name":         t.Name,
		"artistName":   t.Artists,
		"albumName":    t.AlbumName,
		"albumArtist":  t.AlbumArtist,
		"coverUrl":     t.Images,
		"isrc":         t.ISRC,
		"duration":     t.DurationMS,
		"source":       "deezer",
		"releaseDate":  t.ReleaseDate,
		"trackNumber":  t.TrackNumber,
		"totalTracks":  t.TotalTracks,
		"discNumber":   t.DiscNumber,
		"totalDiscs":   t.TotalDiscs,
	}
}

// getMapKeys returns the keys of a map for logging/debugging purposes.
func getMapKeys(m map[string]interface{}) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}

// fetchRelatedArtistsTopTracks looks up related artists on Deezer and returns
// top tracks from up to 3 related artists. This is used as a fallback when
// the primary artist's top tracks have all been played already.
func fetchRelatedArtistsTopTracks(ctx context.Context, client *DeezerClient, artistID string, req struct {
	ArtistName string   `json:"artist_name"`
	TrackName  string   `json:"track_name"`
	Limit      int      `json:"limit"`
	ExcludeIDs []string `json:"exclude_ids"`
}) ([]map[string]interface{}, error) {
	GoLog("[SimilarTracks] fetchRelatedArtistsTopTracks: looking up related artists for ID %s\n", artistID)

	relatedArtists, err := client.GetRelatedArtists(ctx, artistID, 6)
	if err != nil {
		GoLog("[SimilarTracks] GetRelatedArtists error: %v\n", err)
		return nil, err
	}
	if len(relatedArtists) == 0 {
		GoLog("[SimilarTracks] No related artists found\n")
		return nil, fmt.Errorf("no related artists")
	}

	GoLog("[SimilarTracks] Got %d related artists:\n", len(relatedArtists))
	for i, a := range relatedArtists {
		GoLog("[SimilarTracks]   Related[%d]: %s (ID: %s)\n", i, a.Name, a.ID)
	}

	// Build the exclude set from the request
	excludeSet := make(map[string]struct{}, len(req.ExcludeIDs))
	for _, id := range req.ExcludeIDs {
		if id != "" {
			excludeSet[strings.ToLower(strings.TrimSpace(id))] = struct{}{}
		}
	}

	result := make([]map[string]interface{}, 0, req.Limit)

	// Try up to 5 related artists, fetch their top tracks
	maxArtists := 5
	if maxArtists > len(relatedArtists) {
		maxArtists = len(relatedArtists)
	}

	for i := 0; i < maxArtists && len(result) < req.Limit; i++ {
		relatedID := strings.TrimPrefix(relatedArtists[i].ID, "deezer:")
		GoLog("[SimilarTracks] Fetching top tracks for related artist[%d]: %s (ID: %s)\n", i, relatedArtists[i].Name, relatedID)

		topTracks, err := client.GetArtistTopTracks(ctx, relatedID, req.Limit)
		if err != nil {
			GoLog("[SimilarTracks]   Failed to get top tracks for related artist %s: %v\n", relatedArtists[i].Name, err)
			continue
		}

		GoLog("[SimilarTracks]   Got %d top tracks from %s\n", len(topTracks), relatedArtists[i].Name)

		for _, t := range topTracks {
			if len(result) >= req.Limit {
				break
			}
			trackID := strings.ToLower(strings.TrimSpace(t.SpotifyID))
			if _, excluded := excludeSet[trackID]; excluded {
				continue
			}
			if trackID != "" {
				excludeSet[trackID] = struct{}{}
			}
			result = append(result, similarTrackToMap(t))
		}
	}

	GoLog("[SimilarTracks] fetchRelatedArtistsTopTracks: returning %d tracks\n", len(result))
	if len(result) > 0 {
		GoLog("[SimilarTracks] Related result keys: %v\n", getMapKeys(result[0]))
	}
	return result, nil
}

// enrichWithLocalAvailability checks the local DB for each track result and adds
// local_path and is_available_offline fields if a local copy exists (download or local_scan).
func enrichWithLocalAvailability(tracks []map[string]interface{}) {
	if len(tracks) == 0 {
		return
	}

	db, err := GetMasterDB()
	if err != nil {
		GoLog("[SimilarTracks] enrichWithLocalAvailability: DB not available: %v\n", err)
		return
	}

	foundCount := 0
	for i, track := range tracks {
		// Try by ISRC first (most reliable, avoids false positives)
		isrc := ""
		if v, ok := track["isrc"].(string); ok {
			isrc = v
		}

		var filePath string
		if isrc != "" {
			err := db.QueryRow(`
				SELECT f.file_path FROM files f
				JOIN metadata m ON f.metadata_id = m.id
				WHERE m.isrc = ? AND f.source IN ('download', 'local_scan')
				LIMIT 1`, isrc).Scan(&filePath)
			if err == nil && filePath != "" {
				tracks[i]["local_path"] = filePath
				tracks[i]["is_available_offline"] = true
				foundCount++
				GoLog("[SimilarTracks]   [%d] Local by ISRC: %s -> %s\n", i, isrc, filePath)
				continue
			}
		}

		// Fallback: try by track name + artist name (case-insensitive)
		name := ""
		artistName := ""
		if v, ok := track["name"].(string); ok {
			name = v
		}
		if v, ok := track["artistName"].(string); ok {
			artistName = v
		}

		if name != "" && artistName != "" {
			err := db.QueryRow(`
				SELECT f.file_path FROM files f
				JOIN metadata m ON f.metadata_id = m.id
				WHERE LOWER(m.track_name) = LOWER(?) AND LOWER(m.artist_name) = LOWER(?)
				AND f.source IN ('download', 'local_scan')
				LIMIT 1`, name, artistName).Scan(&filePath)
			if err == nil && filePath != "" {
				tracks[i]["local_path"] = filePath
				tracks[i]["is_available_offline"] = true
				foundCount++
				GoLog("[SimilarTracks]   [%d] Local by name: %s - %s -> %s\n", i, artistName, name, filePath)
			}
		}
	}

	GoLog("[SimilarTracks] enrichWithLocalAvailability: %d / %d tracks have local copies\n", foundCount, len(tracks))
}

// truncateJSON converts a map to JSON and truncates it to maxLen chars for logging.
func truncateJSON(m map[string]interface{}, maxLen int) string {
	b, _ := json.Marshal(m)
	s := string(b)
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
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
