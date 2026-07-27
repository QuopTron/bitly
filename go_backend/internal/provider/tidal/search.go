package tidal

import (
	"fmt"
	"strconv"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// SearchTracks searches Tidal for tracks.
func (c *Client) SearchTracks(query string, limit int) ([]provider.TrackResult, error) {
	if limit < 1 || limit > 100 {
		limit = 25
	}
	var resp SearchResponse
	if err := c.doGet("/search/tracks", map[string]string{
		"query": query, "limit": strconv.Itoa(limit),
	}, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.TrackResult, 0, len(resp.Items))
	for _, t := range resp.Items {
		results = append(results, provider.TrackResult{
			ID:       fmt.Sprintf("tidal:%d", t.ID),
			Title:    t.Title,
			Artist:   t.Artist.Name,
			ArtistID: fmt.Sprintf("tidal:%d", t.Artist.ID),
			Album:    t.Album.Title,
			AlbumID:  fmt.Sprintf("tidal:%d", t.Album.ID),
			Duration: t.Duration,
			ISRC:     t.ISRC,
			CoverURL: t.Album.Cover,
			Provider: "tidal",
		})
	}
	return results, nil
}

// SearchAlbums searches Tidal for albums.
func (c *Client) SearchAlbums(query string, limit int) ([]provider.AlbumResult, error) {
	if limit < 1 || limit > 100 {
		limit = 25
	}
	var resp AlbumSearchResponse
	if err := c.doGet("/search/albums", map[string]string{
		"query": query, "limit": strconv.Itoa(limit),
	}, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.AlbumResult, 0, len(resp.Items))
	for _, a := range resp.Items {
		results = append(results, provider.AlbumResult{
			ID:          fmt.Sprintf("tidal:%d", a.ID),
			Title:       a.Title,
			Artist:      a.Artist.Name,
			ArtistID:    fmt.Sprintf("tidal:%d", a.Artist.ID),
			ReleaseDate: a.ReleaseDate,
			TrackCount:  a.TrackCount,
			CoverURL:    a.Cover,
			Provider:    "tidal",
		})
	}
	return results, nil
}

// SearchArtists searches Tidal for artists.
// PlaylistSearchItem represents a Tidal playlist search result.
type PlaylistSearchItem struct {
	ID          int64  `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description"`
	Creator     struct {
		ID   int64  `json:"id"`
		Name string `json:"name"`
	} `json:"creator"`
	TrackCount int    `json:"numberOfItems"`
	Images     []struct {
		URL string `json:"url"`
	} `json:"images,omitempty"`
}

// PlaylistSearchResponse is the Tidal playlist search response.
type PlaylistSearchResponse struct {
	Items      []PlaylistSearchItem `json:"items"`
	TotalCount int                  `json:"totalNumberOfItems"`
}

// SearchPlaylists searches Tidal for playlists.
func (c *Client) SearchPlaylists(query string, limit int) ([]provider.PlaylistResult, error) {
	if limit < 1 || limit > 100 {
		limit = 25
	}
	var resp PlaylistSearchResponse
	if err := c.doGet("/search/playlists", map[string]string{
		"query": query, "limit": strconv.Itoa(limit),
	}, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.PlaylistResult, 0, len(resp.Items))
	for _, pl := range resp.Items {
		r := provider.PlaylistResult{
			ID:          fmt.Sprintf("tidal:%d", pl.ID),
			Title:       pl.Title,
			Description: pl.Description,
			Creator:     pl.Creator.Name,
			TrackCount:  pl.TrackCount,
			Provider:    "tidal",
		}
		if len(pl.Images) > 0 {
			r.CoverURL = pl.Images[0].URL
		}
		results = append(results, r)
	}
	return results, nil
}

func (c *Client) SearchArtists(query string, limit int) ([]provider.ArtistResult, error) {
	if limit < 1 || limit > 100 {
		limit = 25
	}
	var resp ArtistSearchResponse
	if err := c.doGet("/search/artists", map[string]string{
		"query": query, "limit": strconv.Itoa(limit),
	}, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.ArtistResult, 0, len(resp.Items))
	for _, a := range resp.Items {
		results = append(results, provider.ArtistResult{
			ID:         fmt.Sprintf("tidal:%d", a.ID),
			Name:       a.Name,
			PictureURL: a.PictureURL,
			Provider:   "tidal",
		})
	}
	return results, nil
}

// GetTrack returns track metadata by Tidal track ID.
func (c *Client) GetTrack(id string) (*provider.TrackResult, error) {
	var track Track
	if err := c.doGet("/tracks/"+id, nil, &track); err != nil {
		return nil, err
	}
	return &provider.TrackResult{
		ID:       fmt.Sprintf("tidal:%d", track.ID),
		Title:    track.Title,
		Artist:   track.Artist.Name,
		ArtistID: fmt.Sprintf("tidal:%d", track.Artist.ID),
		Album:    track.Album.Title,
		AlbumID:  fmt.Sprintf("tidal:%d", track.Album.ID),
		Duration: track.Duration,
		ISRC:     track.ISRC,
		CoverURL: track.Album.Cover,
		Provider: "tidal",
	}, nil
}

// GetTrackByISRC looks up a track by ISRC.
func (c *Client) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	results, err := c.SearchTracks(fmt.Sprintf("isrc:%s", isrc), 1)
	if err != nil {
		return nil, err
	}
	if len(results) == 0 {
		return nil, fmt.Errorf("tidal: no track found for ISRC %s", isrc)
	}
	return &results[0], nil
}

// GetStreamURL returns the stream URL for a Tidal track.
func (c *Client) GetStreamURL(id, quality string) (string, error) {
	qualityParam := "LOSSLESS"
	switch quality {
	case "mp3":
		qualityParam = "HIGH"
	case "320":
		qualityParam = "HIGH"
	case "hi-res":
		qualityParam = "HI_RES"
	}
	var resp StreamURLResponse
	if err := c.doGet("/tracks/"+id+"/streamurl",
		map[string]string{"soundQuality": qualityParam}, &resp); err != nil {
		return "", err
	}
	return resp.URL, nil
}
