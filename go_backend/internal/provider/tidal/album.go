package tidal

import (
	"fmt"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// GetAlbum returns album metadata.
func (c *Client) GetAlbum(id string) (*provider.AlbumResult, error) {
	var album Album
	if err := c.doGet("/albums/"+id, nil, &album); err != nil {
		return nil, err
	}
	return &provider.AlbumResult{
		ID:          fmt.Sprintf("tidal:%d", album.ID),
		Title:       album.Title,
		Artist:      album.Artist.Name,
		ArtistID:    fmt.Sprintf("tidal:%d", album.Artist.ID),
		ReleaseDate: album.ReleaseDate,
		TrackCount:  album.TrackCount,
		CoverURL:    coverURL(album.Cover),
		Provider:    "tidal",
	}, nil
}

// GetArtist returns artist metadata.
func (c *Client) GetArtist(id string) (*provider.ArtistResult, error) {
	var artist Artist
	if err := c.doGet("/artists/"+id, nil, &artist); err != nil {
		return nil, err
	}
	return &provider.ArtistResult{
		ID:         fmt.Sprintf("tidal:%d", artist.ID),
		Name:       artist.Name,
		PictureURL: artist.PictureURL,
		Provider:   "tidal",
	}, nil
}
