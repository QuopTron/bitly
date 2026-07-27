package deezer

import "fmt"

// GetArtist returns full artist metadata.
func (c *Client) getArtistByID(artistID int64) (*Artist, error) {
	var artist Artist
	if err := c.doGet(fmt.Sprintf("/artist/%d", artistID), nil, &artist); err != nil {
		return nil, err
	}
	return &artist, nil
}

// GetArtistTopTracks returns the top tracks for an artist.
func (c *Client) GetArtistTopTracks(artistID int64, limit int) ([]Track, error) {
	if limit < 1 || limit > 100 {
		limit = 10
	}
	type topResp struct {
		Data  []Track `json:"data"`
		Total int     `json:"total"`
	}
	var resp topResp
	if err := c.doGet(fmt.Sprintf("/artist/%d/top", artistID),
		map[string]string{"limit": fmt.Sprintf("%d", limit)}, &resp); err != nil {
		return nil, err
	}
	return resp.Data, nil
}

// GetArtistAlbums returns albums by an artist, optionally filtered by album type.
func (c *Client) GetArtistAlbums(artistID int64, limit int) ([]Album, error) {
	if limit < 1 || limit > 100 {
		limit = 25
	}
	type albumListResp struct {
		Data  []Album `json:"data"`
		Total int     `json:"total"`
	}
	var resp albumListResp
	if err := c.doGet(fmt.Sprintf("/artist/%d/albums", artistID),
		map[string]string{"limit": fmt.Sprintf("%d", limit)}, &resp); err != nil {
		return nil, err
	}
	return resp.Data, nil
}

// GetArtistRelated returns related/similar artists.
func (c *Client) GetArtistRelated(artistID int64, limit int) ([]ArtistRef, error) {
	if limit < 1 || limit > 100 {
		limit = 10
	}
	type relatedResp struct {
		Data  []ArtistRef `json:"data"`
		Total int         `json:"total"`
	}
	var resp relatedResp
	if err := c.doGet(fmt.Sprintf("/artist/%d/related", artistID),
		map[string]string{"limit": fmt.Sprintf("%d", limit)}, &resp); err != nil {
		return nil, err
	}
	return resp.Data, nil
}
