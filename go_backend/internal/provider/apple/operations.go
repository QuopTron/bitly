package apple

import (
	"fmt"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// SearchAlbums searches Apple Music for albums.
func (c *Client) SearchAlbums(query string, limit int) ([]provider.AlbumResult, error) {
	if c.token == "" {
		return nil, fmt.Errorf("apple: no developer token set")
	}
	if limit < 1 || limit > 100 {
		limit = 25
	}
	type searchResp struct {
		Results struct {
			Albums struct {
				Data []appleAlbum `json:"data"`
			} `json:"albums"`
		} `json:"results"`
	}
	var resp searchResp
	if err := c.doGet("/catalog/"+c.storefront+"/search", map[string]string{
		"term": query, "types": "albums", "limit": fmt.Sprintf("%d", limit),
	}, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.AlbumResult, 0, len(resp.Results.Albums.Data))
	for _, a := range resp.Results.Albums.Data {
		artworkURL := a.Attributes.Artwork.URL
		if artworkURL != "" {
			artworkURL = strings.Replace(artworkURL, "{w}x{h}", "300x300", 1)
		}
		results = append(results, provider.AlbumResult{
			ID: "apple:" + a.ID, Title: a.Attributes.Name,
			Artist: a.Attributes.ArtistName, ReleaseDate: a.Attributes.ReleaseDate,
			TrackCount: a.Attributes.TrackCount, CoverURL: artworkURL, Provider: "apple",
		})
	}
	return results, nil
}

// SearchPlaylists searches Apple Music for playlists.
func (c *Client) SearchPlaylists(query string, limit int) ([]provider.PlaylistResult, error) {
	if c.token == "" {
		return nil, fmt.Errorf("apple: no developer token set")
	}
	if limit < 1 || limit > 100 {
		limit = 25
	}
	type searchResp struct {
		Results struct {
			Playlists struct {
				Data []applePlaylist `json:"data"`
			} `json:"playlists"`
		} `json:"results"`
	}
	var resp searchResp
	if err := c.doGet("/catalog/"+c.storefront+"/search", map[string]string{
		"term": query, "types": "playlists", "limit": fmt.Sprintf("%d", limit),
	}, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.PlaylistResult, 0, len(resp.Results.Playlists.Data))
	for _, pl := range resp.Results.Playlists.Data {
		artworkURL := pl.Attributes.Artwork.URL
		if artworkURL != "" {
			artworkURL = strings.Replace(artworkURL, "{w}x{h}", "300x300", 1)
		}
		results = append(results, provider.PlaylistResult{
			ID: "apple:" + pl.ID, Title: pl.Attributes.Name,
			Description: pl.Attributes.Description, Creator: pl.Attributes.CuratorName,
			TrackCount: pl.Attributes.TrackCount, CoverURL: artworkURL, Provider: "apple",
		})
	}
	return results, nil
}

// SearchArtists searches Apple Music for artists.
func (c *Client) SearchArtists(query string, limit int) ([]provider.ArtistResult, error) {
	if c.token == "" {
		return nil, fmt.Errorf("apple: no developer token set")
	}
	if limit < 1 || limit > 100 {
		limit = 25
	}
	type searchResp struct {
		Results struct {
			Artists struct {
				Data []appleArtist `json:"data"`
			} `json:"artists"`
		} `json:"results"`
	}
	var resp searchResp
	if err := c.doGet("/catalog/"+c.storefront+"/search", map[string]string{
		"term": query, "types": "artists", "limit": fmt.Sprintf("%d", limit),
	}, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.ArtistResult, 0, len(resp.Results.Artists.Data))
	for _, a := range resp.Results.Artists.Data {
		pictureURL := a.Attributes.Artwork.URL
		if pictureURL != "" {
			pictureURL = strings.Replace(pictureURL, "{w}x{h}", "300x300", 1)
		}
		results = append(results, provider.ArtistResult{
			ID: "apple:" + a.ID, Name: a.Attributes.Name,
			PictureURL: pictureURL, Provider: "apple",
		})
	}
	return results, nil
}
