package providers

import (
	"fmt"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/providers/tidal"
)

type tidalSearchAdapter struct{}

func (a *tidalSearchAdapter) ID() string   { return "tidal" }
func (a *tidalSearchAdapter) Name() string { return "Tidal" }

func (a *tidalSearchAdapter) Search(query string, limit int) ([]core.SearchResultItem, error) {
	client := tidal.GetClient()
	meta, err := client.SearchText(query)
	if err != nil || meta == nil {
		return nil, err
	}
	return []core.SearchResultItem{{
		ID:       meta.ID,
		Title:    meta.Name,
		Artist:   meta.Artists,
		Album:    meta.AlbumName,
		Duration: int64(meta.DurationMS),
		ISRC:     meta.ISRC,
		Source:   "tidal",
		CoverURL: "",
	}}, nil
}

type tidalMetadataAdapter struct{}

func (a *tidalMetadataAdapter) ID() string   { return "tidal" }
func (a *tidalMetadataAdapter) Name() string { return "Tidal" }

func (a *tidalMetadataAdapter) GetTrackMetadata(providerTrackID string) (interface{}, error) {
	client := tidal.GetClient()
	return client.GetTrackInfo(providerTrackID)
}

func (a *tidalMetadataAdapter) GetAlbumMetadata(providerAlbumID string) (interface{}, error) {
	client := tidal.GetClient()
	return client.GetAlbum(providerAlbumID)
}

type tidalDownloadAdapter struct{}

func (a *tidalDownloadAdapter) ID() string   { return "tidal" }
func (a *tidalDownloadAdapter) Name() string { return "Tidal" }

func (a *tidalDownloadAdapter) Download(trackID, quality string) ([]byte, error) {
	return nil, fmt.Errorf("tidal download not available via API; use extension provider")
}
