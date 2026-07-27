package qobuz

import (
	"fmt"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// GetAlbum returns album metadata with tracklist.
func (c *Client) GetAlbum(id string) (*provider.AlbumResult, error) {
	var album Album
	if err := c.doGet("/album/get", map[string]string{
		"album_id": id,
	}, &album); err != nil {
		return nil, err
	}
	return albumToResult(&album), nil
}

// GetArtist returns artist metadata.
func (c *Client) GetArtist(id string) (*provider.ArtistResult, error) {
	var artist Artist
	if err := c.doGet("/artist/get", map[string]string{
		"artist_id": id,
	}, &artist); err != nil {
		return nil, err
	}
	return &provider.ArtistResult{
		ID:         fmt.Sprintf("qobuz:%d", artist.ID),
		Name:       artist.Name,
		PictureURL: artist.Image.Large,
		Provider:   "qobuz",
	}, nil
}

// albumToResult normalizes a Qobuz Album into AlbumResult.
func albumToResult(a *Album) *provider.AlbumResult {
	r := &provider.AlbumResult{
		ID:          fmt.Sprintf("qobuz:%d", a.ID),
		Title:       a.Title,
		ReleaseDate: a.ReleaseDate,
		TrackCount:  a.TrackCount,
		CoverURL:    a.Image.Large,
		Provider:    "qobuz",
	}
	if a.Artist != nil {
		r.Artist = a.Artist.Name
		r.ArtistID = fmt.Sprintf("qobuz:%d", a.Artist.ID)
	}
	return r
}
