package deezer

import (
	"fmt"
)

// SearchTrackResult is the normalized result for a track search.
type SearchTrackResult struct {
	ID       int64  `json:"id"`
	Title    string `json:"title"`
	Artist   string `json:"artist"`
	ArtistID int64  `json:"artistId"`
	Album    string `json:"album"`
	AlbumID  int64  `json:"albumId"`
	Duration int    `json:"duration"`
	ISRC     string `json:"isrc"`
	Preview  string `json:"preview"`
	CoverURL string `json:"coverUrl"`
}

// SearchTracks searches Deezer for tracks matching the query.
func (c *Client) searchTracks(query string, limit int) ([]SearchTrackResult, error) {
	if limit < 1 || limit > 100 {
		limit = 25
	}
	var resp SearchResponse
	if err := c.doGet("/search", map[string]string{
		"q": query, "limit": fmt.Sprintf("%d", limit),
	}, &resp); err != nil {
		return nil, err
	}
	return normalizeSearchResults(resp.Data), nil
}

// SearchAlbums searches Deezer for albums matching the query.
// Returns raw album search results (Deezer doesn't have a dedicated album
// search type — uses /search/album endpoint).
func (c *Client) searchAlbums(query string, limit int) ([]AlbumRef, error) {
	if limit < 1 || limit > 100 {
		limit = 25
	}
	type albumSearchItem struct {
		ID    int64     `json:"id"`
		Title string    `json:"title"`
		Artist ArtistRef `json:"artist"`
		Cover string    `json:"cover"`
		Type  string    `json:"type"`
	}
	type albumSearchResp struct {
		Data  []albumSearchItem `json:"data"`
		Total int               `json:"total"`
	}
	var resp albumSearchResp
	if err := c.doGet("/search/album", map[string]string{
		"q": query, "limit": fmt.Sprintf("%d", limit),
	}, &resp); err != nil {
		return nil, err
	}
	results := make([]AlbumRef, 0, len(resp.Data))
	for _, item := range resp.Data {
		results = append(results, AlbumRef{
			ID:    item.ID,
			Title: item.Title,
			Cover: item.Cover,
		})
	}
	return results, nil
}

// SearchArtists searches Deezer for artists matching the query.
func (c *Client) searchArtists(query string, limit int) ([]ArtistRef, error) {
	if limit < 1 || limit > 100 {
		limit = 25
	}
	type artistSearchResp struct {
		Data  []ArtistRef `json:"data"`
		Total int         `json:"total"`
	}
	var resp artistSearchResp
	if err := c.doGet("/search/artist", map[string]string{
		"q": query, "limit": fmt.Sprintf("%d", limit),
	}, &resp); err != nil {
		return nil, err
	}
	return resp.Data, nil
}

// normalizeSearchResults converts raw Deezer tracks to SearchTrackResult.
func normalizeSearchResults(tracks []Track) []SearchTrackResult {
	results := make([]SearchTrackResult, 0, len(tracks))
	for _, t := range tracks {
		coverURL := ""
		if t.Album.Cover != "" {
			coverURL = t.Album.Cover
		}
		results = append(results, SearchTrackResult{
			ID:       t.ID,
			Title:    t.Title,
			Artist:   t.Artist.Name,
			ArtistID: t.Artist.ID,
			Album:    t.Album.Title,
			AlbumID:  t.Album.ID,
			Duration: t.Duration,
			ISRC:     t.ISRC,
			Preview:  t.Preview,
			CoverURL: coverURL,
		})
	}
	return results
}
