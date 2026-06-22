package playback

import (
	"context"
	"fmt"
	"strings"
)

func fetchRelatedArtistsTopTracks(ctx context.Context, artistID string, req struct {
	ArtistName string   `json:"artist_name"`
	TrackName  string   `json:"track_name"`
	Limit      int      `json:"limit"`
	ExcludeIDs []string `json:"exclude_ids"`
}, excludeSet map[string]struct{}) ([]map[string]interface{}, error) {
	if deezerClient == nil {
		return nil, fmt.Errorf("no Deezer client")
	}

	relatedArtists, err := deezerClient.GetRelatedArtists(ctx, artistID, 6)
	if err != nil || len(relatedArtists) == 0 {
		return nil, fmt.Errorf("no related artists")
	}

	maxArtists := 5
	if maxArtists > len(relatedArtists) {
		maxArtists = len(relatedArtists)
	}

	result := make([]map[string]interface{}, 0, req.Limit)
	for i := 0; i < maxArtists && len(result) < req.Limit; i++ {
		relatedID := strings.TrimPrefix(relatedArtists[i].SpotifyID, "deezer:")

		topTracks, err := deezerClient.GetArtistTopTracks(ctx, relatedID, req.Limit)
		if err != nil {
			continue
		}

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
	return result, nil
}
