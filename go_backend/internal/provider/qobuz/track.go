package qobuz

import (
	"fmt"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// GetTrack returns track metadata by Qobuz track ID.
func (c *Client) GetTrack(id string) (*provider.TrackResult, error) {
	track, err := c.getTrackRaw(id)
	if err != nil {
		return nil, err
	}
	return trackToResult(track), nil
}

// getTrackRaw fetches raw track from the API.
func (c *Client) getTrackRaw(id string) (*Track, error) {
	var track Track
	if err := c.doGet("/track/get", map[string]string{
		"track_id": id,
	}, &track); err != nil {
		return nil, err
	}
	return &track, nil
}

// GetTrackByISRC looks up a track by ISRC via search.
func (c *Client) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	results, err := c.SearchTracks(fmt.Sprintf("isrc:%s", isrc), 1)
	if err != nil {
		return nil, err
	}
	if len(results) == 0 {
		return nil, fmt.Errorf("qobuz: no track found for ISRC %s", isrc)
	}
	return &results[0], nil
}

// GetStreamURL returns the stream URL for a Qobuz track.
// Requires the client to be authenticated via Login().
func (c *Client) GetStreamURL(id, quality string) (string, error) {
	if c.userAuth == nil {
		return "", fmt.Errorf("qobuz: not authenticated, call Login() first")
	}
	formatID := "5" // default FLAC
	switch quality {
	case "mp3":
		formatID = "6"
	case "320":
		formatID = "5"
	case "lossless":
		formatID = "5"
	case "hi-res":
		formatID = "7"
	}
	var resp TrackFileURLResponse
	// The track_file_url endpoint returns a direct download URL
	err := c.doGet("/track/getFileUrl", map[string]string{
		"track_id":  id,
		"format_id": formatID,
		"intent":    "stream",
	}, &resp)
	if err != nil {
		return "", err
	}
	return resp.URL, nil
}

// trackToResult normalizes a Qobuz Track into TrackResult.
func trackToResult(t *Track) *provider.TrackResult {
	r := &provider.TrackResult{
		ID:       fmt.Sprintf("qobuz:%d", t.ID),
		Title:    t.Title,
		Duration: t.Duration,
		ISRC:     t.ISRC,
		Provider: "qobuz",
	}
	if t.Performer != nil {
		r.Artist = t.Performer.Name
		r.ArtistID = fmt.Sprintf("qobuz:%d", t.Performer.ID)
	}
	if t.Album != nil {
		r.Album = t.Album.Title
		r.AlbumID = fmt.Sprintf("qobuz:%d", t.Album.ID)
		r.CoverURL = t.Album.Image.Large
	}
	return r
}
