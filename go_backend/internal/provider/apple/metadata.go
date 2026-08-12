package apple

import (
	"fmt"
	"net/url"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// GetTrack returns track metadata from Apple Music.
func (c *Client) GetTrack(id string) (*provider.TrackResult, error) {
	if c.token == "" {
		return nil, fmt.Errorf("apple: no developer token set")
	}
	type songResp struct {
		Data []appleSong `json:"data"`
	}
	var resp songResp
	if err := c.doGet("/catalog/"+c.storefront+"/songs/"+id, nil, &resp); err != nil {
		return nil, err
	}
	if len(resp.Data) == 0 {
		return nil, fmt.Errorf("apple: track %s not found", id)
	}
	s := resp.Data[0]
	artworkURL := s.Attributes.Artwork.URL
	if artworkURL != "" {
		artworkURL = strings.Replace(artworkURL, "{w}x{h}", "300x300", 1)
	}
	return &provider.TrackResult{
		ID: "apple:" + s.ID, Title: s.Attributes.Name,
		Artist: s.Attributes.ArtistName, Album: s.Attributes.AlbumName,
		Duration: s.Attributes.DurationInMs, ISRC: s.Attributes.ISRC,
		CoverURL: artworkURL, Provider: "apple",
	}, nil
}

// GetTrackByISRC looks up a track by ISRC via catalog search.
func (c *Client) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	if c.token == "" {
		return nil, fmt.Errorf("apple: no developer token set")
	}
	results, err := c.SearchTracks(isrc, 5)
	if err != nil {
		return nil, err
	}
	for _, t := range results {
		if t.ISRC == isrc {
			return &t, nil
		}
	}
	if len(results) > 0 {
		return &results[0], nil
	}
	return nil, fmt.Errorf("apple: no track found for ISRC %s", isrc)
}

// GetAlbum returns album metadata with tracklist from Apple Music.
func (c *Client) GetAlbum(id string) (*provider.AlbumResult, error) {
	if c.token == "" {
		return nil, fmt.Errorf("apple: no developer token set")
	}
	type albumResp struct {
		Data []appleAlbum `json:"data"`
	}
	var resp albumResp
	if err := c.doGet("/catalog/"+c.storefront+"/albums/"+url.PathEscape(id), nil, &resp); err != nil {
		return nil, err
	}
	if len(resp.Data) == 0 {
		return nil, fmt.Errorf("apple: album %s not found", id)
	}
	a := resp.Data[0]
	artworkURL := a.Attributes.Artwork.URL
	if artworkURL != "" {
		artworkURL = strings.Replace(artworkURL, "{w}x{h}", "300x300", 1)
	}
	return &provider.AlbumResult{
		ID: "apple:" + a.ID, Title: a.Attributes.Name,
		Artist: a.Attributes.ArtistName, ReleaseDate: a.Attributes.ReleaseDate,
		TrackCount: a.Attributes.TrackCount, CoverURL: artworkURL, Provider: "apple",
	}, nil
}

// GetArtist returns artist metadata from Apple Music.
func (c *Client) GetArtist(id string) (*provider.ArtistResult, error) {
	if c.token == "" {
		return nil, fmt.Errorf("apple: no developer token set")
	}
	type artistResp struct {
		Data []appleArtist `json:"data"`
	}
	var resp artistResp
	if err := c.doGet("/catalog/"+c.storefront+"/artists/"+url.PathEscape(id), nil, &resp); err != nil {
		return nil, err
	}
	if len(resp.Data) == 0 {
		return nil, fmt.Errorf("apple: artist %s not found", id)
	}
	a := resp.Data[0]
	pictureURL := a.Attributes.Artwork.URL
	if pictureURL != "" {
		pictureURL = strings.Replace(pictureURL, "{w}x{h}", "300x300", 1)
	}
	return &provider.ArtistResult{
		ID: "apple:" + a.ID, Name: a.Attributes.Name,
		PictureURL: pictureURL, Provider: "apple",
	}, nil
}

// GetStreamURL returns an error — Apple Music streams are DRM-protected.
func (c *Client) GetStreamURL(id, quality string) (string, error) {
	return "", fmt.Errorf("apple: stream URLs not available (FairPlay DRM)")
}
