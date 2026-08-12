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
			ID: fmt.Sprintf("tidal:%d", t.ID), Title: t.Title,
			Artist: t.Artist.Name, ArtistID: fmt.Sprintf("tidal:%d", t.Artist.ID),
			Album: t.Album.Title, AlbumID: fmt.Sprintf("tidal:%d", t.Album.ID),
			Duration: t.Duration, ISRC: t.ISRC,
			CoverURL: coverURL(t.Album.Cover), Provider: "tidal",
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
			ID: fmt.Sprintf("tidal:%d", a.ID), Title: a.Title,
			Artist: a.Artist.Name, ArtistID: fmt.Sprintf("tidal:%d", a.Artist.ID),
			ReleaseDate: a.ReleaseDate, TrackCount: a.TrackCount,
			CoverURL: coverURL(a.Cover), Provider: "tidal",
		})
	}
	return results, nil
}

// SearchArtists searches Tidal for artists.
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
			ID: fmt.Sprintf("tidal:%d", a.ID), Name: a.Name,
			PictureURL: a.PictureURL, Provider: "tidal",
		})
	}
	return results, nil
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
			ID: fmt.Sprintf("tidal:%d", pl.ID), Title: pl.Title,
			Description: pl.Description, Creator: pl.Creator.Name,
			TrackCount: pl.TrackCount, Provider: "tidal",
		}
		if len(pl.Images) > 0 {
			r.CoverURL = coverURL(pl.Images[0].URL)
		}
		results = append(results, r)
	}
	return results, nil
}
