package soundcloud

import (
	"fmt"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// GetTrack returns full track metadata from SoundCloud.
func (c *Client) GetTrack(id string) (*provider.TrackResult, error) {
	if c.clientID == "" {
		return nil, fmt.Errorf("soundcloud: client_id not set")
	}
	type trackDetail struct {
		ID         int64  `json:"id"`
		Title      string `json:"title"`
		Duration   int    `json:"duration"`
		Genre      string `json:"genre"`
		ArtworkURL string `json:"artwork_url"`
		User       struct {
			ID       int64  `json:"id"`
			Username string `json:"username"`
		} `json:"user"`
	}
	var track trackDetail
	if err := c.doGet("/tracks/"+id, nil, &track); err != nil {
		return nil, fmt.Errorf("soundcloud: get track %s: %w", id, err)
	}
	return &provider.TrackResult{
		ID: fmt.Sprintf("sc:%d", track.ID), Title: track.Title,
		Artist: track.User.Username, ArtistID: fmt.Sprintf("sc:%d", track.User.ID),
		Duration: track.Duration, CoverURL: track.ArtworkURL, Provider: "soundcloud",
	}, nil
}

// GetTrackByISRC returns error — SoundCloud doesn't support ISRC lookup.
func (c *Client) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	return nil, fmt.Errorf("soundcloud: ISRC lookup not available")
}

// GetAlbum returns playlist/album metadata from SoundCloud.
func (c *Client) GetAlbum(id string) (*provider.AlbumResult, error) {
	if c.clientID == "" {
		return nil, fmt.Errorf("soundcloud: client_id not set")
	}
	type playlistDetail struct {
		ID          int64  `json:"id"`
		Title       string `json:"title"`
		ArtworkURL  string `json:"artwork_url"`
		TrackCount  int    `json:"track_count"`
		Description string `json:"description"`
		User        struct {
			ID       int64  `json:"id"`
			Username string `json:"username"`
		} `json:"user"`
	}
	var playlist playlistDetail
	if err := c.doGet("/playlists/"+id, nil, &playlist); err != nil {
		return nil, fmt.Errorf("soundcloud: get playlist %s: %w", id, err)
	}
	return &provider.AlbumResult{
		ID: fmt.Sprintf("sc:%d", playlist.ID), Title: playlist.Title,
		Artist: playlist.User.Username, ArtistID: fmt.Sprintf("sc:%d", playlist.User.ID),
		CoverURL: playlist.ArtworkURL, TrackCount: playlist.TrackCount, Provider: "soundcloud",
	}, nil
}

// GetArtist returns artist/user metadata from SoundCloud.
func (c *Client) GetArtist(id string) (*provider.ArtistResult, error) {
	if c.clientID == "" {
		return nil, fmt.Errorf("soundcloud: client_id not set")
	}
	type userDetail struct {
		ID             int64  `json:"id"`
		Username       string `json:"username"`
		AvatarURL      string `json:"avatar_url"`
		Description    string `json:"description"`
		FollowersCount int    `json:"followers_count"`
		TrackCount     int    `json:"track_count"`
	}
	var user userDetail
	if err := c.doGet("/users/"+id, nil, &user); err != nil {
		return nil, fmt.Errorf("soundcloud: get user %s: %w", id, err)
	}
	return &provider.ArtistResult{
		ID: fmt.Sprintf("sc:%d", user.ID), Name: user.Username,
		PictureURL: user.AvatarURL, Provider: "soundcloud",
	}, nil
}

// GetStreamURL returns a stream URL for a SoundCloud track via its media transcodings.
func (c *Client) GetStreamURL(id, quality string) (string, error) {
	if c.clientID == "" {
		return "", fmt.Errorf("soundcloud: client_id not set")
	}
	type mediaTranscoding struct {
		URL    string `json:"url"`
		Format struct {
			Protocol string `json:"protocol"`
		} `json:"format"`
	}
	type trackMedia struct {
		Media struct {
			Transcodings []mediaTranscoding `json:"transcodings"`
		} `json:"media"`
	}
	var track trackMedia
	if err := c.doGet("/tracks/"+id, nil, &track); err != nil {
		return "", fmt.Errorf("soundcloud: get track media %s: %w", id, err)
	}
	if len(track.Media.Transcodings) == 0 {
		return "", fmt.Errorf("soundcloud: no transcodings for track %s", id)
	}
	for _, t := range track.Media.Transcodings {
		if t.Format.Protocol == "progressive" {
			return t.URL + "?client_id=" + c.clientID, nil
		}
	}
	return track.Media.Transcodings[0].URL + "?client_id=" + c.clientID, nil
}
