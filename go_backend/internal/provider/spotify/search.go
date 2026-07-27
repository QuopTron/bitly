package spotify

import (
	"fmt"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Spotify API types for search results.
type spotifyTrack struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Duration int    `json:"duration_ms"`
	Explicit bool   `json:"explicit"`
	Artists  []struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	} `json:"artists"`
	Album struct {
		ID     string `json:"id"`
		Name   string `json:"name"`
		Images []struct {
			URL string `json:"url"`
		} `json:"images"`
	} `json:"album"`
	ExternalIDs struct {
		ISRC string `json:"isrc"`
	} `json:"external_ids"`
}

// SearchTracks searches Spotify for tracks.
func (c *Client) SearchTracks(query string, limit int) ([]provider.TrackResult, error) {
	if limit < 1 || limit > 100 {
		limit = 20
	}
	type searchResp struct {
		Tracks struct {
			Items []spotifyTrack `json:"items"`
		} `json:"tracks"`
	}
	var resp searchResp
	if err := c.doGet("/search", map[string]string{
		"q": query, "type": "track", "limit": fmt.Sprintf("%d", limit),
	}, &resp); err != nil {
		return nil, err
	}
	return normalizeTracks(resp.Tracks.Items), nil
}

// GetTrack returns track metadata by Spotify track ID.
func (c *Client) GetTrack(id string) (*provider.TrackResult, error) {
	var track spotifyTrack
	if err := c.doGet("/tracks/"+id, nil, &track); err != nil {
		return nil, err
	}
	results := normalizeTracks([]spotifyTrack{track})
	if len(results) == 0 {
		return nil, fmt.Errorf("spotify: track %s not found", id)
	}
	return &results[0], nil
}

// GetTrackByISRC looks up a track by ISRC via Spotify search.
func (c *Client) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	results, err := c.SearchTracks("isrc:"+isrc, 1)
	if err != nil {
		return nil, err
	}
	if len(results) == 0 {
		return nil, fmt.Errorf("spotify: no track for ISRC %s", isrc)
	}
	return &results[0], nil
}

func normalizeTracks(tracks []spotifyTrack) []provider.TrackResult {
	results := make([]provider.TrackResult, 0, len(tracks))
	for _, t := range tracks {
		tr := provider.TrackResult{
			ID:       "spotify:" + t.ID,
			Title:    t.Name,
			Duration: t.Duration,
			ISRC:     t.ExternalIDs.ISRC,
			Provider: "spotify",
		}
		if len(t.Artists) > 0 {
			tr.Artist = t.Artists[0].Name
			tr.ArtistID = "spotify:" + t.Artists[0].ID
		}
		tr.Album = t.Album.Name
		tr.AlbumID = "spotify:" + t.Album.ID
		if len(t.Album.Images) > 0 {
			tr.CoverURL = t.Album.Images[0].URL
		}
		results = append(results, tr)
	}
	return results
}
