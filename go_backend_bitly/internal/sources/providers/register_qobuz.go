package providers

import (
	"fmt"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/providers/qobuz"
)

type qobuzSearchAdapter struct{}

func (a *qobuzSearchAdapter) ID() string   { return "qobuz" }
func (a *qobuzSearchAdapter) Name() string { return "Qobuz" }

func (a *qobuzSearchAdapter) Search(query string, limit int) ([]core.SearchResultItem, error) {
	client := qobuz.GetClient()
	tracks, err := client.SearchTracks(query, limit)
	if err != nil {
		return nil, err
	}
	items := make([]core.SearchResultItem, 0, len(tracks))
	for _, t := range tracks {
		items = append(items, core.SearchResultItem{
			ID:       t.ID,
			Title:    t.Name,
			Artist:   t.Artists,
			Album:    t.AlbumName,
			Duration: int64(t.DurationMS),
			ISRC:     t.ISRC,
			Source:   "qobuz",
			CoverURL: "",
		})
	}
	return items, nil
}

type qobuzMetadataAdapter struct{}

func (a *qobuzMetadataAdapter) ID() string   { return "qobuz" }
func (a *qobuzMetadataAdapter) Name() string { return "Qobuz" }

func (a *qobuzMetadataAdapter) GetTrackMetadata(providerTrackID string) (interface{}, error) {
	client := qobuz.GetClient()
	tid, err := client.SearchByISRC(providerTrackID)
	if err == nil && tid != "" {
		return map[string]string{"id": tid, "source": "qobuz"}, nil
	}
	tracks, err := client.SearchTracks(providerTrackID, 1)
	if err != nil || len(tracks) == 0 {
		return nil, fmt.Errorf("qobuz: track not found: %s", providerTrackID)
	}
	return tracks[0], nil
}

func (a *qobuzMetadataAdapter) GetAlbumMetadata(providerAlbumID string) (interface{}, error) {
	client := qobuz.GetClient()
	return client.GetAlbum(providerAlbumID)
}

type qobuzDownloadAdapter struct{}

func (a *qobuzDownloadAdapter) ID() string   { return "qobuz" }
func (a *qobuzDownloadAdapter) Name() string { return "Qobuz" }

func (a *qobuzDownloadAdapter) Download(trackID, quality string) ([]byte, error) {
	return nil, fmt.Errorf("qobuz download not available via API; use extension provider")
}
