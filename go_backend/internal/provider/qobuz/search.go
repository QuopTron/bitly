package qobuz

import (
	"fmt"
	"strconv"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// SearchTracks searches Qobuz for tracks matching the query.
func (c *Client) SearchTracks(query string, limit int) ([]provider.TrackResult, error) {
	if limit < 1 || limit > 100 {
		limit = 25
	}
	var resp SearchResponse
	if err := c.doGet("/catalog/search", map[string]string{
		"query": query, "limit": strconv.Itoa(limit), "type": "tracks",
	}, &resp); err != nil {
		return nil, err
	}
	if resp.Tracks == nil {
		return nil, nil
	}
	results := make([]provider.TrackResult, 0, len(resp.Tracks.Items))
	for _, t := range resp.Tracks.Items {
		result := provider.TrackResult{
			ID:       fmt.Sprintf("qobuz:%d", t.ID),
			Title:    t.Title,
			Duration: t.Duration,
			ISRC:     t.ISRC,
			Provider: "qobuz",
		}
		if t.Album != nil {
			result.Album = t.Album.Title
			result.AlbumID = fmt.Sprintf("qobuz:%d", t.Album.ID)
			result.CoverURL = t.Album.Image.Large
		}
		if t.Performer != nil {
			result.Artist = t.Performer.Name
			result.ArtistID = fmt.Sprintf("qobuz:%d", t.Performer.ID)
		}
		results = append(results, result)
	}
	return results, nil
}

// SearchAlbums searches Qobuz for albums.
func (c *Client) SearchAlbums(query string, limit int) ([]provider.AlbumResult, error) {
	if limit < 1 || limit > 100 {
		limit = 25
	}
	var resp SearchResponse
	if err := c.doGet("/catalog/search", map[string]string{
		"query": query, "limit": strconv.Itoa(limit), "type": "albums",
	}, &resp); err != nil {
		return nil, err
	}
	if resp.Albums == nil {
		return nil, nil
	}
	results := make([]provider.AlbumResult, 0, len(resp.Albums.Items))
	for _, a := range resp.Albums.Items {
		al := provider.AlbumResult{
			ID:         fmt.Sprintf("qobuz:%d", a.ID),
			Title:      a.Title,
			ReleaseDate: a.ReleaseDate,
			TrackCount: a.TrackCount,
			CoverURL:   a.Image.Large,
			Provider:   "qobuz",
		}
		if a.Artist != nil {
			al.Artist = a.Artist.Name
			al.ArtistID = fmt.Sprintf("qobuz:%d", a.Artist.ID)
		}
		results = append(results, al)
	}
	return results, nil
}

// SearchPlaylists searches Qobuz for playlists.
// Qobuz does not have a dedicated playlist search endpoint.
func (c *Client) SearchPlaylists(query string, limit int) ([]provider.PlaylistResult, error) {
	return nil, nil
}

// SearchArtists searches Qobuz for artists.
func (c *Client) SearchArtists(query string, limit int) ([]provider.ArtistResult, error) {
	if limit < 1 || limit > 100 {
		limit = 25
	}
	var resp SearchResponse
	if err := c.doGet("/catalog/search", map[string]string{
		"query": query, "limit": strconv.Itoa(limit), "type": "artists",
	}, &resp); err != nil {
		return nil, err
	}
	if resp.Artists == nil {
		return nil, nil
	}
	results := make([]provider.ArtistResult, 0, len(resp.Artists.Items))
	for _, a := range resp.Artists.Items {
		results = append(results, provider.ArtistResult{
			ID:         fmt.Sprintf("qobuz:%d", a.ID),
			Name:       a.Name,
			PictureURL: a.Image.Large,
			Provider:   "qobuz",
		})
	}
	return results, nil
}
