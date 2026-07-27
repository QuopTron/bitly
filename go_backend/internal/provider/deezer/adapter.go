package deezer

import (
	"fmt"
	"strconv"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Methods below adapt *Client to satisfy the provider.Provider interface.
// They convert string IDs to int64 and normalize types.

func (c *Client) GetTrack(id string) (*provider.TrackResult, error) {
	n, err := strconv.ParseInt(id, 10, 64)
	if err != nil {
		return nil, fmt.Errorf("deezer: invalid track ID %s", id)
	}
	track, err := c.getTrackByID(n)
	if err != nil {
		return nil, err
	}
	return fromTrack(track), nil
}

func (c *Client) GetAlbum(id string) (*provider.AlbumResult, error) {
	n, err := strconv.ParseInt(id, 10, 64)
	if err != nil {
		return nil, fmt.Errorf("deezer: invalid album ID %s", id)
	}
	album, err := c.getAlbumByID(n)
	if err != nil {
		return nil, err
	}
	return fromAlbum(album), nil
}

func (c *Client) GetArtist(id string) (*provider.ArtistResult, error) {
	n, err := strconv.ParseInt(id, 10, 64)
	if err != nil {
		return nil, fmt.Errorf("deezer: invalid artist ID %s", id)
	}
	artist, err := c.getArtistByID(n)
	if err != nil {
		return nil, err
	}
	return &provider.ArtistResult{
		ID:         fmt.Sprintf("deezer:%d", artist.ID),
		Name:       artist.Name,
		PictureURL: artist.PictureBig,
		Provider:   "deezer",
	}, nil
}

func (c *Client) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	track, err := c.getTrackByISRC(isrc)
	if err != nil {
		return nil, err
	}
	return fromTrack(track), nil
}

func (c *Client) GetStreamURL(id, quality string) (string, error) {
	n, err := strconv.ParseInt(id, 10, 64)
	if err != nil {
		return "", fmt.Errorf("deezer: invalid track ID %s", id)
	}
	if c.arl == "" {
		return "", fmt.Errorf("deezer: ARL not set, call SetARL first")
	}
	track, err := c.getTrackByID(n)
	if err != nil {
		return "", err
	}
	if track.MD5Origin == "" {
		return "", fmt.Errorf("deezer: track %d has no MD5_ORIGIN", n)
	}
	cdn := calculateCDN(track.MD5Origin)
	return fmt.Sprintf("https://e-cdns-proxy-%s.deezer.com/mobile/1/%s", cdn, track.MD5Origin), nil
}

func (c *Client) SearchAlbums(query string, limit int) ([]provider.AlbumResult, error) {
	refs, err := c.searchAlbums(query, limit)
	if err != nil {
		return nil, err
	}
	results := make([]provider.AlbumResult, 0, len(refs))
	for _, ref := range refs {
		results = append(results, provider.AlbumResult{
			ID:       fmt.Sprintf("deezer:%d", ref.ID),
			Title:    ref.Title,
			CoverURL: ref.Cover,
			Provider: "deezer",
		})
	}
	return results, nil
}

func (c *Client) SearchPlaylists(query string, limit int) ([]provider.PlaylistResult, error) {
	type playlistSearchItem struct {
		ID          int64  `json:"id"`
		Title       string `json:"title"`
		Description string `json:"description"`
		TrackCount  int    `json:"nb_tracks"`
		Picture     string `json:"picture"`
		PictureSmall string `json:"picture_small"`
		Creator     struct {
			Name string `json:"name"`
		} `json:"creator"`
	} 
	type playlistSearchResp struct {
		Data  []playlistSearchItem `json:"data"`
		Total int                  `json:"total"`
	}
	if limit < 1 || limit > 100 {
		limit = 25
	}
	var resp playlistSearchResp
	if err := c.doGet("/search/playlist", map[string]string{
		"q": query, "limit": fmt.Sprintf("%d", limit),
	}, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.PlaylistResult, 0, len(resp.Data))
	for _, pl := range resp.Data {
		cover := pl.Picture
		if cover == "" {
			cover = pl.PictureSmall
		}
		results = append(results, provider.PlaylistResult{
			ID:          fmt.Sprintf("deezer:%d", pl.ID),
			Title:       pl.Title,
			Description: pl.Description,
			Creator:     pl.Creator.Name,
			TrackCount:  pl.TrackCount,
			CoverURL:    cover,
			Provider:    "deezer",
		})
	}
	return results, nil
}

func (c *Client) SearchArtists(query string, limit int) ([]provider.ArtistResult, error) {
	refs, err := c.searchArtists(query, limit)
	if err != nil {
		return nil, err
	}
	results := make([]provider.ArtistResult, 0, len(refs))
	for _, ref := range refs {
		results = append(results, provider.ArtistResult{
			ID:       fmt.Sprintf("deezer:%d", ref.ID),
			Name:     ref.Name,
			Provider: "deezer",
		})
	}
	return results, nil
}

func (c *Client) SearchTracks(query string, limit int) ([]provider.TrackResult, error) {
	results, err := c.searchTracks(query, limit)
	if err != nil {
		return nil, err
	}
	converted := make([]provider.TrackResult, 0, len(results))
	for _, t := range results {
		converted = append(converted, provider.TrackResult{
			ID:       fmt.Sprintf("deezer:%d", t.ID),
			Title:    t.Title,
			Artist:   t.Artist,
			ArtistID: fmt.Sprintf("deezer:%d", t.ArtistID),
			Album:    t.Album,
			AlbumID:  fmt.Sprintf("deezer:%d", t.AlbumID),
			Duration: t.Duration,
			ISRC:     t.ISRC,
			CoverURL: t.CoverURL,
			Provider: "deezer",
		})
	}
	return converted, nil
}

// Internal helpers

func fromTrack(t *Track) *provider.TrackResult {
	return &provider.TrackResult{
		ID:       fmt.Sprintf("deezer:%d", t.ID),
		Title:    t.Title,
		Artist:   t.Artist.Name,
		ArtistID: fmt.Sprintf("deezer:%d", t.Artist.ID),
		Album:    t.Album.Title,
		AlbumID:  fmt.Sprintf("deezer:%d", t.Album.ID),
		Duration: t.Duration,
		ISRC:     t.ISRC,
		CoverURL: t.Album.Cover,
		Provider: "deezer",
	}
}

func fromAlbum(a *Album) *provider.AlbumResult {
	return &provider.AlbumResult{
		ID:          fmt.Sprintf("deezer:%d", a.ID),
		Title:       a.Title,
		Artist:      a.Artist.Name,
		ArtistID:    fmt.Sprintf("deezer:%d", a.Artist.ID),
		CoverURL:    a.CoverBig,
		ReleaseDate: a.ReleaseDate,
		TrackCount:  a.TrackCount,
		Provider:    "deezer",
	}
}
