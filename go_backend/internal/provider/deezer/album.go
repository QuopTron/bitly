package deezer

import "fmt"

// GetAlbum returns full album metadata with tracklist.
func (c *Client) getAlbumByID(albumID int64) (*Album, error) {
	var album Album
	if err := c.doGet(fmt.Sprintf("/album/%d", albumID), nil, &album); err != nil {
		return nil, err
	}
	return &album, nil
}

// GetAlbumTracks returns the tracklist for an album.
func (c *Client) getAlbumTracksByID(albumID int64) ([]Track, error) {
	type tracksResp struct {
		Data  []Track `json:"data"`
		Total int     `json:"total"`
	}
	var resp tracksResp
	if err := c.doGet(fmt.Sprintf("/album/%d/tracks", albumID), nil, &resp); err != nil {
		return nil, err
	}
	return resp.Data, nil
}

// AlbumResult is the normalized album result for cross-provider use.
type AlbumResult struct {
	ID          int64  `json:"id"`
	Title       string `json:"title"`
	Artist      string `json:"artist"`
	ArtistID    int64  `json:"artistId"`
	CoverURL    string `json:"coverUrl"`
	ReleaseDate string `json:"releaseDate"`
	TrackCount  int    `json:"trackCount"`
	Duration    int    `json:"duration"`
}

// ToAlbumResult normalizes a Deezer Album into AlbumResult.
func (a *Album) ToAlbumResult() AlbumResult {
	return AlbumResult{
		ID:          a.ID,
		Title:       a.Title,
		Artist:      a.Artist.Name,
		ArtistID:    a.Artist.ID,
		CoverURL:    a.CoverBig,
		ReleaseDate: a.ReleaseDate,
		TrackCount:  a.TrackCount,
		Duration:    a.Duration,
	}
}
