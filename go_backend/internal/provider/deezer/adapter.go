package deezer

import (
	"fmt"
	"strconv"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

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
		ID: fmt.Sprintf("deezer:%d", artist.ID), Name: artist.Name,
		PictureURL: artist.PictureBig, Provider: "deezer",
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

func fromTrack(t *Track) *provider.TrackResult {
	return &provider.TrackResult{
		ID: fmt.Sprintf("deezer:%d", t.ID), Title: t.Title,
		Artist: t.Artist.Name, ArtistID: fmt.Sprintf("deezer:%d", t.Artist.ID),
		Album: t.Album.Title, AlbumID: fmt.Sprintf("deezer:%d", t.Album.ID),
		Duration: t.Duration, ISRC: t.ISRC,
		CoverURL: t.Album.Cover, Provider: "deezer",
	}
}

func fromAlbum(a *Album) *provider.AlbumResult {
	return &provider.AlbumResult{
		ID: fmt.Sprintf("deezer:%d", a.ID), Title: a.Title,
		Artist: a.Artist.Name, ArtistID: fmt.Sprintf("deezer:%d", a.Artist.ID),
		CoverURL: a.CoverBig, ReleaseDate: a.ReleaseDate,
		TrackCount: a.TrackCount, Provider: "deezer",
	}
}
