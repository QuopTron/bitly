package musicbrainz

import (
	"fmt"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// ─── API response types ──────────────────────────────────────────

type mbRelease struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	Date        string `json:"date"`
	TrackCount  int    `json:"track-count"`
	ArtistCredit []struct {
		Name   string `json:"name"`
		Artist struct {
			ID string `json:"id"`
		} `json:"artist"`
	} `json:"artist-credit"`
}

type mbArtist struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

// ─── SearchAlbums ────────────────────────────────────────────────

// SearchAlbums searches MusicBrainz for releases (albums).
func (c *Client) SearchAlbums(query string, limit int) ([]provider.AlbumResult, error) {
	if limit < 1 || limit > 100 {
		limit = 25
	}
	type searchResp struct {
		Releases []mbRelease `json:"releases"`
	}
	var resp searchResp
	if err := c.doGet("/release", map[string]string{
		"query": query, "limit": fmt.Sprintf("%d", limit),
	}, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.AlbumResult, 0, len(resp.Releases))
	for _, r := range resp.Releases {
		ar := provider.AlbumResult{
			ID:          "mb:" + r.ID,
			Title:       r.Title,
			ReleaseDate: r.Date,
			TrackCount:  r.TrackCount,
			Provider:    "musicbrainz",
		}
		if len(r.ArtistCredit) > 0 {
			ar.Artist = r.ArtistCredit[0].Name
			ar.ArtistID = "mb:" + r.ArtistCredit[0].Artist.ID
		}
		results = append(results, ar)
	}
	return results, nil
}

// ─── SearchArtists ───────────────────────────────────────────────

// SearchArtists searches MusicBrainz for artists.
func (c *Client) SearchArtists(query string, limit int) ([]provider.ArtistResult, error) {
	if limit < 1 || limit > 100 {
		limit = 25
	}
	type searchResp struct {
		Artists []mbArtist `json:"artists"`
	}
	var resp searchResp
	if err := c.doGet("/artist", map[string]string{
		"query": query, "limit": fmt.Sprintf("%d", limit),
	}, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.ArtistResult, 0, len(resp.Artists))
	for _, a := range resp.Artists {
		results = append(results, provider.ArtistResult{
			ID:       "mb:" + a.ID,
			Name:     a.Name,
			Provider: "musicbrainz",
		})
	}
	return results, nil
}

// ─── GetAlbum ────────────────────────────────────────────────────

// GetAlbum returns album metadata for a MusicBrainz release.
func (c *Client) GetAlbum(id string) (*provider.AlbumResult, error) {
	var resp mbRelease
	if err := c.doGet("/release/"+id, nil, &resp); err != nil {
		return nil, err
	}
	ar := &provider.AlbumResult{
		ID:          "mb:" + resp.ID,
		Title:       resp.Title,
		ReleaseDate: resp.Date,
		TrackCount:  resp.TrackCount,
		Provider:    "musicbrainz",
	}
	if len(resp.ArtistCredit) > 0 {
		ar.Artist = resp.ArtistCredit[0].Name
		ar.ArtistID = "mb:" + resp.ArtistCredit[0].Artist.ID
	}
	return ar, nil
}

// ─── GetArtist ───────────────────────────────────────────────────

// GetArtist returns artist metadata from MusicBrainz.
func (c *Client) GetArtist(id string) (*provider.ArtistResult, error) {
	var resp mbArtist
	if err := c.doGet("/artist/"+id, nil, &resp); err != nil {
		return nil, err
	}
	return &provider.ArtistResult{
		ID:       "mb:" + resp.ID,
		Name:     resp.Name,
		Provider: "musicbrainz",
	}, nil
}

// ─── GetStreamURL ────────────────────────────────────────────────

// GetStreamURL returns an error — MusicBrainz is metadata-only.
func (c *Client) GetStreamURL(id, quality string) (string, error) {
	return "", fmt.Errorf("musicbrainz: metadata only, no stream URLs")
}
