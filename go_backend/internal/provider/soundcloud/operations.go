package soundcloud

import (
	"fmt"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// SearchAlbums searches SoundCloud for playlists/albums.
func (c *Client) SearchAlbums(query string, limit int) ([]provider.AlbumResult, error) {
	if c.clientID == "" {
		return nil, fmt.Errorf("soundcloud: client_id not set")
	}
	if limit < 1 || limit > 100 {
		limit = 25
	}
	type playlistItem struct {
		ID         int64  `json:"id"`
		Title      string `json:"title"`
		ArtworkURL string `json:"artwork_url"`
		TrackCount int    `json:"track_count"`
		User       struct {
			ID       int64  `json:"id"`
			Username string `json:"username"`
		} `json:"user"`
		IsAlbum bool `json:"is_album"`
	}
	type playlistSearchResp struct {
		Collection []playlistItem `json:"collection"`
	}
	params := map[string]string{
		"q": query, "limit": fmt.Sprintf("%d", limit), "client_id": c.clientID,
	}
	var resp playlistSearchResp
	if err := c.doGet("/search/playlists", params, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.AlbumResult, 0, len(resp.Collection))
	for _, p := range resp.Collection {
		if !p.IsAlbum {
			continue
		}
		results = append(results, provider.AlbumResult{
			ID: fmt.Sprintf("sc:%d", p.ID), Title: p.Title,
			Artist: p.User.Username, ArtistID: fmt.Sprintf("sc:%d", p.User.ID),
			CoverURL: p.ArtworkURL, TrackCount: p.TrackCount, Provider: "soundcloud",
		})
	}
	return results, nil
}

// SearchPlaylists searches SoundCloud for playlists (non-album).
func (c *Client) SearchPlaylists(query string, limit int) ([]provider.PlaylistResult, error) {
	if c.clientID == "" {
		return nil, fmt.Errorf("soundcloud: client_id not set")
	}
	if limit < 1 || limit > 100 {
		limit = 25
	}
	type playlistItem struct {
		ID          int64  `json:"id"`
		Title       string `json:"title"`
		Description string `json:"description"`
		ArtworkURL  string `json:"artwork_url"`
		TrackCount  int    `json:"track_count"`
		User        struct {
			ID       int64  `json:"id"`
			Username string `json:"username"`
		} `json:"user"`
	}
	type playlistSearchResp struct {
		Collection []playlistItem `json:"collection"`
	}
	params := map[string]string{
		"q": query, "limit": fmt.Sprintf("%d", limit), "client_id": c.clientID,
	}
	var resp playlistSearchResp
	if err := c.doGet("/search/playlists", params, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.PlaylistResult, 0, len(resp.Collection))
	for _, pl := range resp.Collection {
		results = append(results, provider.PlaylistResult{
			ID: fmt.Sprintf("sc:%d", pl.ID), Title: pl.Title,
			Description: pl.Description, Creator: pl.User.Username,
			TrackCount: pl.TrackCount, CoverURL: pl.ArtworkURL, Provider: "soundcloud",
		})
	}
	return results, nil
}

// SearchArtists searches SoundCloud for users/artists.
func (c *Client) SearchArtists(query string, limit int) ([]provider.ArtistResult, error) {
	if c.clientID == "" {
		return nil, fmt.Errorf("soundcloud: client_id not set")
	}
	if limit < 1 || limit > 100 {
		limit = 25
	}
	type userItem struct {
		ID        int64  `json:"id"`
		Username  string `json:"username"`
		AvatarURL string `json:"avatar_url"`
	}
	type userSearchResp struct {
		Collection []userItem `json:"collection"`
	}
	params := map[string]string{
		"q": query, "limit": fmt.Sprintf("%d", limit), "client_id": c.clientID,
	}
	var resp userSearchResp
	if err := c.doGet("/search/users", params, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.ArtistResult, 0, len(resp.Collection))
	for _, u := range resp.Collection {
		results = append(results, provider.ArtistResult{
			ID: fmt.Sprintf("sc:%d", u.ID), Name: u.Username,
			PictureURL: u.AvatarURL, Provider: "soundcloud",
		})
	}
	return results, nil
}
