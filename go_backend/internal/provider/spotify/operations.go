package spotify

import (
	"fmt"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// spotifySearchAlbum represents an album from Spotify search.
type spotifySearchAlbum struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	ReleaseDate string `json:"release_date"`
	TotalTracks int    `json:"total_tracks"`
	Images      []struct {
		URL string `json:"url"`
	} `json:"images"`
	Artists []struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	} `json:"artists"`
}

// spotifySearchArtist represents an artist from Spotify search.
type spotifySearchArtist struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	Images    []struct {
		URL string `json:"url"`
	} `json:"images"`
	Followers struct {
		Total int `json:"total"`
	} `json:"followers"`
}

// SearchAlbums searches Spotify for albums.
func (c *Client) SearchAlbums(query string, limit int) ([]provider.AlbumResult, error) {
	if limit < 1 || limit > 100 {
		limit = 20
	}
	type searchResp struct {
		Albums struct {
			Items []spotifySearchAlbum `json:"items"`
		} `json:"albums"`
	}
	var resp searchResp
	if err := c.doGet("/search", map[string]string{
		"q": query, "type": "album", "limit": fmt.Sprintf("%d", limit),
	}, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.AlbumResult, 0, len(resp.Albums.Items))
	for _, a := range resp.Albums.Items {
		r := provider.AlbumResult{
			ID: "spotify:" + a.ID, Title: a.Name,
			ReleaseDate: a.ReleaseDate, TrackCount: a.TotalTracks, Provider: "spotify",
		}
		if len(a.Artists) > 0 {
			r.Artist = a.Artists[0].Name
			r.ArtistID = "spotify:" + a.Artists[0].ID
		}
		if len(a.Images) > 0 {
			r.CoverURL = a.Images[0].URL
		}
		results = append(results, r)
	}
	return results, nil
}

// SearchArtists searches Spotify for artists.
func (c *Client) SearchArtists(query string, limit int) ([]provider.ArtistResult, error) {
	if limit < 1 || limit > 100 {
		limit = 20
	}
	type searchResp struct {
		Artists struct {
			Items []spotifySearchArtist `json:"items"`
		} `json:"artists"`
	}
	var resp searchResp
	if err := c.doGet("/search", map[string]string{
		"q": query, "type": "artist", "limit": fmt.Sprintf("%d", limit),
	}, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.ArtistResult, 0, len(resp.Artists.Items))
	for _, a := range resp.Artists.Items {
		r := provider.ArtistResult{
			ID: "spotify:" + a.ID, Name: a.Name,
			Fans: a.Followers.Total, Provider: "spotify",
		}
		if len(a.Images) > 0 {
			r.PictureURL = a.Images[0].URL
		}
		results = append(results, r)
	}
	return results, nil
}

// GetStreamURL returns an error — Spotify does not provide stream/download URLs.
func (c *Client) GetStreamURL(id, quality string) (string, error) {
	return "", fmt.Errorf("spotify: does not provide stream URLs")
}
