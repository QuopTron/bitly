package spotify

import (
	"fmt"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// spotifySearchPlaylist represents a playlist from Spotify search.
type spotifySearchPlaylist struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Tracks      struct {
		Total int `json:"total"`
	} `json:"tracks"`
	Images []struct {
		URL string `json:"url"`
	} `json:"images"`
	Owner struct {
		DisplayName string `json:"display_name"`
	} `json:"owner"`
}

// SearchPlaylists searches Spotify for playlists.
func (c *Client) SearchPlaylists(query string, limit int) ([]provider.PlaylistResult, error) {
	if limit < 1 || limit > 100 {
		limit = 20
	}
	type searchResp struct {
		Playlists struct {
			Items []spotifySearchPlaylist `json:"items"`
		} `json:"playlists"`
	}
	var resp searchResp
	if err := c.doGet("/search", map[string]string{
		"q": query, "type": "playlist", "limit": fmt.Sprintf("%d", limit),
	}, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.PlaylistResult, 0, len(resp.Playlists.Items))
	for _, pl := range resp.Playlists.Items {
		r := provider.PlaylistResult{
			ID: "spotify:" + pl.ID, Title: pl.Name,
			Description: pl.Description, Creator: pl.Owner.DisplayName,
			TrackCount: pl.Tracks.Total, Provider: "spotify",
		}
		if len(pl.Images) > 0 {
			r.CoverURL = pl.Images[0].URL
		}
		results = append(results, r)
	}
	return results, nil
}
