package spotify

import "github.com/zarz/bitly/go_backend/internal/provider"

// GetAlbum returns album metadata from Spotify.
func (c *Client) GetAlbum(id string) (*provider.AlbumResult, error) {
	type spotifyAlbum struct {
		ID          string `json:"id"`
		Name        string `json:"name"`
		ReleaseDate string `json:"release_date"`
		TotalTracks int    `json:"total_tracks"`
		Images      []struct {
			URL string `json:"url"`
		} `json:"images"`
		Artists []struct {
			ID   string `json:"id"`
			Name string `json:"name"`
		} `json:"artists"`
	}
	var album spotifyAlbum
	if err := c.doGet("/albums/"+id, nil, &album); err != nil {
		return nil, err
	}
	result := &provider.AlbumResult{
		ID:          "spotify:" + album.ID,
		Title:       album.Name,
		ReleaseDate: album.ReleaseDate,
		TrackCount:  album.TotalTracks,
		Provider:    "spotify",
	}
	if len(album.Artists) > 0 {
		result.Artist = album.Artists[0].Name
		result.ArtistID = "spotify:" + album.Artists[0].ID
	}
	if len(album.Images) > 0 {
		result.CoverURL = album.Images[0].URL
	}
	return result, nil
}

// GetArtist returns artist metadata from Spotify.
func (c *Client) GetArtist(id string) (*provider.ArtistResult, error) {
	type spotifyArtist struct {
		ID     string `json:"id"`
		Name   string `json:"name"`
		Images []struct {
			URL string `json:"url"`
		} `json:"images"`
	}
	var artist spotifyArtist
	if err := c.doGet("/artists/"+id, nil, &artist); err != nil {
		return nil, err
	}
	picURL := ""
	if len(artist.Images) > 0 {
		picURL = artist.Images[0].URL
	}
	return &provider.ArtistResult{
		ID:         "spotify:" + artist.ID,
		Name:       artist.Name,
		PictureURL: picURL,
		Provider:   "spotify",
	}, nil
}
