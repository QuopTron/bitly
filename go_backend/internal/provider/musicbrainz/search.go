package musicbrainz

import (
	"fmt"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

func (c *Client) SearchTracks(query string, limit int) ([]provider.TrackResult, error) {
	if limit < 1 || limit > 100 {
		limit = 25
	}
	type recordingResp struct {
		Recordings []struct {
			ID      string `json:"id"`
			Title   string `json:"title"`
			Length  int    `json:"length"`
			ISRCs   []struct {
				ID string `json:"id"`
			} `json:"isrcs"`
			ArtistCredit []struct {
				Name  string `json:"name"`
				Artist struct {
					ID string `json:"id"`
				} `json:"artist"`
			} `json:"artist-credit"`
			Releases []struct {
				ID    string `json:"id"`
				Title string `json:"title"`
			} `json:"releases"`
		} `json:"recordings"`
	}
	var resp recordingResp
	if err := c.doGet("/recording", map[string]string{
		"query": query, "limit": fmt.Sprintf("%d", limit),
	}, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.TrackResult, 0, len(resp.Recordings))
	for _, r := range resp.Recordings {
		tr := provider.TrackResult{
			ID:       "mb:" + r.ID,
			Title:    r.Title,
			Duration: r.Length / 1000,
			Provider: "musicbrainz",
		}
		if len(r.ISRCs) > 0 {
			tr.ISRC = r.ISRCs[0].ID
		}
		if len(r.ArtistCredit) > 0 {
			tr.Artist = r.ArtistCredit[0].Name
			tr.ArtistID = "mb:" + r.ArtistCredit[0].Artist.ID
		}
		if len(r.Releases) > 0 {
			tr.Album = r.Releases[0].Title
			tr.AlbumID = "mb:" + r.Releases[0].ID
		}
		results = append(results, tr)
	}
	return results, nil
}

// GetTrack returns metadata for a MusicBrainz recording.
func (c *Client) GetTrack(id string) (*provider.TrackResult, error) {
	results, err := c.SearchTracks(fmt.Sprintf("recording:%s", id), 1)
	if err != nil {
		return nil, err
	}
	if len(results) == 0 {
		return nil, fmt.Errorf("mb: recording %s not found", id)
	}
	return &results[0], nil
}

// GetTrackByISRC looks up a track by ISRC code.
func (c *Client) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	results, err := c.SearchTracks(fmt.Sprintf("isrc:%s", isrc), 1)
	if err != nil {
		return nil, err
	}
	if len(results) == 0 {
		return nil, fmt.Errorf("mb: no recording for ISRC %s", isrc)
	}
	return &results[0], nil
}
