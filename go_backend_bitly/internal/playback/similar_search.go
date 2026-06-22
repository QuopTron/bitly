package playback

import (
	"context"
	"encoding/json"
	"strings"
	"time"
)

func GetSimilarTracksJSON(requestJSON string) string {
	startTime := time.Now()
	defer func() {
		Log("[SimilarTracks] Total time: %v", time.Since(startTime))
	}()

	var req struct {
		ArtistName string   `json:"artist_name"`
		TrackName  string   `json:"track_name"`
		Limit      int      `json:"limit"`
		ExcludeIDs []string `json:"exclude_ids"`
	}
	if err := json.Unmarshal([]byte(requestJSON), &req); err != nil {
		Log("[SimilarTracks] Failed to parse request: %v", err)
		return errorResponse("Invalid request: " + err.Error())
	}

	if req.Limit <= 0 || req.Limit > 50 {
		req.Limit = 15
	}

	if deezerClient == nil {
		Log("[SimilarTracks] No Deezer client available")
		return `[]`
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	searchResult, err := deezerClient.SearchAll(ctx, req.ArtistName, 0, 3, "artist")
	if err != nil || len(searchResult.Artists) == 0 {
		trackResult, trackErr := deezerClient.SearchAll(ctx, req.ArtistName, req.Limit, 0, "track")
		if trackErr != nil || len(trackResult.Tracks) == 0 {
			return `[]`
		}
		tracks := make([]map[string]interface{}, 0, len(trackResult.Tracks))
		for _, t := range trackResult.Tracks {
			tracks = append(tracks, similarTrackToMap(t))
		}
		enrichWithLocalAvailability(tracks)
		jsonBytes, _ := json.Marshal(tracks)
		return string(jsonBytes)
	}

	artistID := strings.TrimPrefix(searchResult.Artists[0].SpotifyID, "deezer:")

	topTracks, err := deezerClient.GetArtistTopTracks(ctx, artistID, req.Limit+5)
	if err != nil || len(topTracks) == 0 {
		return `[]`
	}

	excludeSet := make(map[string]struct{}, len(req.ExcludeIDs))
	for _, id := range req.ExcludeIDs {
		if id != "" {
			excludeSet[strings.ToLower(strings.TrimSpace(id))] = struct{}{}
		}
	}

	result := make([]map[string]interface{}, 0, req.Limit)
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

	if len(result) < 3 {
		relatedResult, relatedErr := fetchRelatedArtistsTopTracks(ctx, artistID, req, excludeSet)
		if relatedErr == nil && len(relatedResult) > 0 {
			for _, m := range relatedResult {
				if len(result) >= req.Limit {
					break
				}
				id, _ := m["id"].(string)
				if id != "" {
					lowerID := strings.ToLower(strings.TrimSpace(id))
					if _, dup := excludeSet[lowerID]; dup {
						continue
					}
					excludeSet[lowerID] = struct{}{}
				}
				result = append(result, m)
			}
		}
	}

	enrichWithLocalAvailability(result)
	jsonBytes, _ := json.Marshal(result)
	return string(jsonBytes)
}
