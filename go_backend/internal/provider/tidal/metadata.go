package tidal

import (
	"fmt"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// PlaylistSearchItem represents a Tidal playlist search result.
type PlaylistSearchItem struct {
	ID          int64  `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description"`
	Creator     struct {
		ID   int64  `json:"id"`
		Name string `json:"name"`
	} `json:"creator"`
	TrackCount int    `json:"numberOfItems"`
	Images     []struct {
		URL string `json:"url"`
	} `json:"images,omitempty"`
}

// PlaylistSearchResponse is the Tidal playlist search response.
type PlaylistSearchResponse struct {
	Items      []PlaylistSearchItem `json:"items"`
	TotalCount int                  `json:"totalNumberOfItems"`
}

// GetTrack returns track metadata by Tidal track ID.
func (c *Client) GetTrack(id string) (*provider.TrackResult, error) {
	var track Track
	if err := c.doGet("/tracks/"+id, nil, &track); err != nil {
		return nil, err
	}
	return &provider.TrackResult{
		ID: fmt.Sprintf("tidal:%d", track.ID), Title: track.Title,
		Artist: track.Artist.Name, ArtistID: fmt.Sprintf("tidal:%d", track.Artist.ID),
		Album: track.Album.Title, AlbumID: fmt.Sprintf("tidal:%d", track.Album.ID),
		Duration: track.Duration, ISRC: track.ISRC,
		CoverURL: coverURL(track.Album.Cover), Provider: "tidal",
	}, nil
}

// GetTrackByISRC looks up a track by ISRC.
func (c *Client) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	results, err := c.SearchTracks(fmt.Sprintf("isrc:%s", isrc), 1)
	if err != nil {
		return nil, err
	}
	if len(results) == 0 {
		return nil, fmt.Errorf("tidal: no track found for ISRC %s", isrc)
	}
	return &results[0], nil
}

// GetStreamURL returns the stream URL for a Tidal track.
func (c *Client) GetStreamURL(id, quality string) (string, error) {
	qualityParam := "LOSSLESS"
	switch quality {
	case "mp3", "320":
		qualityParam = "HIGH"
	case "hi-res":
		qualityParam = "HI_RES"
	}
	var resp StreamURLResponse
	if err := c.doGet("/tracks/"+id+"/streamurl",
		map[string]string{"soundQuality": qualityParam}, &resp); err != nil {
		return "", err
	}
	return resp.URL, nil
}
