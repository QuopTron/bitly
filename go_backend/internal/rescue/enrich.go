package rescue

import (
	"fmt"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Enricher enhances track metadata after download using MusicBrainz and other sources.
type Enricher struct {
	registry *provider.Registry
}

// NewEnricher creates a metadata enricher.
func NewEnricher(reg *provider.Registry) *Enricher {
	return &Enricher{registry: reg}
}

// EnrichResult holds enriched metadata.
type EnrichResult struct {
	ISRC        string   `json:"isrc,omitempty"`
	Genre       string   `json:"genre,omitempty"`
	Year        int      `json:"year,omitempty"`
	Label       string   `json:"label,omitempty"`
	BPM         int      `json:"bpm,omitempty"`
	AlbumArtist string   `json:"albumArtist,omitempty"`
	Composer    string   `json:"composer,omitempty"`
	Tags        []string `json:"tags,omitempty"`
}

// EnrichFromISRC attempts to enrich metadata using the ISRC code.
// Uses MusicBrainz first, then other providers.
func (e *Enricher) EnrichFromISRC(isrc string) (*EnrichResult, error) {
	result := &EnrichResult{ISRC: isrc}

	// Try MusicBrainz for genre/artist info
	mb := e.registry.Get("musicbrainz")
	if mb != nil {
		track, err := mb.GetTrackByISRC(isrc)
		if err == nil && track != nil {
			result.AlbumArtist = track.Artist
			if track.Album != "" {
				result.Tags = append(result.Tags, "from:"+track.Album)
			}
		}
	}

	// Try Deezer for genre/ISRC confirmation
	dz := e.registry.Get("deezer")
	if dz != nil {
		track, err := dz.GetTrackByISRC(isrc)
		if err == nil && track != nil {
			result.AlbumArtist = track.Artist
		}
	}

	if result.AlbumArtist == "" {
		return nil, fmt.Errorf("enrich: no metadata found for ISRC %s", isrc)
	}

	return result, nil
}
