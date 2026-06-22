package providers

import (
	"context"
	"fmt"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/providers/deezer"
)

type deezerSearchAdapter struct{}

func (a *deezerSearchAdapter) ID() string   { return "deezer" }
func (a *deezerSearchAdapter) Name() string { return "Deezer" }

func (a *deezerSearchAdapter) Search(query string, limit int) ([]core.SearchResultItem, error) {
	client := deezer.GetClient()
	result, err := client.SearchAll(context.Background(), query, limit, 5, "")
	if err != nil {
		return nil, err
	}
	items := make([]core.SearchResultItem, 0, len(result.Tracks))
	for _, t := range result.Tracks {
		items = append(items, core.SearchResultItem{
			ID:       t.SpotifyID,
			Title:    t.Name,
			Artist:   t.Artists,
			Album:    t.AlbumName,
			Duration: int64(t.DurationMS),
			ISRC:     t.ISRC,
			Source:   "deezer",
			CoverURL: t.Images,
		})
	}
	return items, nil
}

type deezerMetadataAdapter struct{}

func (a *deezerMetadataAdapter) ID() string   { return "deezer" }
func (a *deezerMetadataAdapter) Name() string { return "Deezer" }

func (a *deezerMetadataAdapter) GetTrackMetadata(providerTrackID string) (interface{}, error) {
	client := deezer.GetClient()
	return client.GetTrack(context.Background(), providerTrackID)
}

func (a *deezerMetadataAdapter) GetAlbumMetadata(providerAlbumID string) (interface{}, error) {
	client := deezer.GetClient()
	return client.GetAlbum(context.Background(), providerAlbumID)
}

type deezerDownloadAdapter struct{}

func (a *deezerDownloadAdapter) ID() string   { return "deezer" }
func (a *deezerDownloadAdapter) Name() string { return "Deezer" }

func (a *deezerDownloadAdapter) Download(trackID, quality string) ([]byte, error) {
	return nil, fmt.Errorf("deezer download not available via API; use extension provider")
}
