package deezer

import (
	"fmt"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// SearchAlbums searches Deezer for albums.
func (c *Client) SearchAlbums(query string, limit int) ([]provider.AlbumResult, error) {
	if limit < 1 || limit > 100 {
		limit = 25
	}
	type albumSearch struct {
		Data  []Album `json:"data"`
		Total int     `json:"total"`
	}
	var resp albumSearch
	if err := c.doGet("/search/album", map[string]string{
		"q": query, "limit": fmt.Sprintf("%d", limit),
	}, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.AlbumResult, 0, len(resp.Data))
	for _, a := range resp.Data {
		results = append(results, provider.AlbumResult{
			ID: fmt.Sprintf("deezer:%d", a.ID), Title: a.Title,
			Artist: a.Artist.Name, ArtistID: fmt.Sprintf("deezer:%d", a.Artist.ID),
			CoverURL: a.CoverBig, ReleaseDate: a.ReleaseDate,
			TrackCount: a.TrackCount, Provider: "deezer",
		})
	}
	return results, nil
}

// SearchPlaylists searches Deezer for playlists.
func (c *Client) SearchPlaylists(query string, limit int) ([]provider.PlaylistResult, error) {
	if limit < 1 || limit > 100 {
		limit = 25
	}
	type playlistSearch struct {
		Data  []Playlist `json:"data"`
		Total int        `json:"total"`
	}
	var resp playlistSearch
	if err := c.doGet("/search/playlist", map[string]string{
		"q": query, "limit": fmt.Sprintf("%d", limit),
	}, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.PlaylistResult, 0, len(resp.Data))
	for _, pl := range resp.Data {
		// Use biggest available picture: XL > Big > Medium > Small
		cover := pl.PictureXl
		if cover == "" {
			cover = pl.PictureBig
		}
		if cover == "" {
			cover = pl.PictureMedium
		}
		if cover == "" {
			cover = pl.Picture
		}
		results = append(results, provider.PlaylistResult{
			ID: fmt.Sprintf("deezer:%d", pl.ID), Title: pl.Title,
			Description: pl.Description, Creator: pl.Creator.Name,
			TrackCount: pl.TrackCount, CoverURL: cover, Provider: "deezer",
		})
	}
	return results, nil
}

// SearchArtists searches Deezer for artists.
func (c *Client) SearchArtists(query string, limit int) ([]provider.ArtistResult, error) {
	if limit < 1 || limit > 100 {
		limit = 25
	}
	type artistSearch struct {
		Data  []Artist `json:"data"`
		Total int      `json:"total"`
	}
	var resp artistSearch
	if err := c.doGet("/search/artist", map[string]string{
		"q": query, "limit": fmt.Sprintf("%d", limit),
	}, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.ArtistResult, 0, len(resp.Data))
	for _, a := range resp.Data {
		results = append(results, provider.ArtistResult{
			ID: fmt.Sprintf("deezer:%d", a.ID), Name: a.Name,
			PictureURL: a.PictureBig, Provider: "deezer",
		})
	}
	return results, nil
}

// SearchTracks searches Deezer for tracks.
func (c *Client) SearchTracks(query string, limit int) ([]provider.TrackResult, error) {
	if limit < 1 || limit > 100 {
		limit = 25
	}
	var resp SearchResponse
	if err := c.doGet("/search/track", map[string]string{
		"q": query, "limit": fmt.Sprintf("%d", limit),
	}, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.TrackResult, 0, len(resp.Data))
	for _, t := range resp.Data {
		coverURL := t.Album.Cover
		// Deezer AlbumRef.Cover is ~250x250; upgrade to 500x500 via CDN URL pattern
		if strings.Contains(coverURL, "250x250") {
			coverURL = strings.ReplaceAll(coverURL, "250x250", "500x500")
		}
		results = append(results, provider.TrackResult{
			ID: fmt.Sprintf("deezer:%d", t.ID), Title: t.Title,
			Artist: t.Artist.Name, ArtistID: fmt.Sprintf("deezer:%d", t.Artist.ID),
			Album: t.Album.Title, AlbumID: fmt.Sprintf("deezer:%d", t.Album.ID),
			Duration: t.Duration, ISRC: t.ISRC,
			CoverURL: coverURL, Provider: "deezer",
		})
	}
	return results, nil
}
