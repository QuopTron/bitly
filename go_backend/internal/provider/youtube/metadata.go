package youtube

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// GetTrack returns detailed track metadata by YouTube video ID.
func (c *Client) GetTrack(id string) (*provider.TrackResult, error) {
	videoID := strings.TrimPrefix(id, "yt:")
	url := fmt.Sprintf("https://music.youtube.com/watch?v=%s", videoID)
	args := []string{"--dump-json", "--no-warnings", "--skip-download", url}
	cmd := exec.Command(c.ytdlpPath, args...)
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("youtube: get track failed: %w", err)
	}
	line := firstJSONLine(string(output))
	var track ytdlpTrack
	if err := json.Unmarshal([]byte(line), &track); err != nil {
		return nil, fmt.Errorf("youtube: parse track failed: %w", err)
	}
	artist := nonEmpty(track.Artist, track.Channel)
	return &provider.TrackResult{
		ID: "yt:" + track.ID, Title: track.Title, Artist: artist,
		Duration: track.Duration, CoverURL: track.Thumbnail,
		Provider: "youtube", Album: track.Album,
	}, nil
}

// GetTrackByISRC is not available on YouTube.
func (c *Client) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	return nil, fmt.Errorf("youtube: ISRC lookup not supported")
}

// GetAlbum returns album metadata from a YouTube Music playlist.
func (c *Client) GetAlbum(id string) (*provider.AlbumResult, error) {
	playlistID := strings.TrimPrefix(id, "yt:")
	url := fmt.Sprintf("https://music.youtube.com/playlist?list=%s", playlistID)
	args := []string{"--dump-json", "--no-warnings", "--skip-download", "--playlist-end", "1", url}
	cmd := exec.Command(c.ytdlpPath, args...)
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("youtube: get album failed: %w", err)
	}
	line := firstJSONLine(string(output))
	var info ytdlpTrack
	if err := json.Unmarshal([]byte(line), &info); err != nil {
		return nil, fmt.Errorf("youtube: parse album failed: %w", err)
	}
	title := nonEmpty(info.PlaylistTitle, info.Title)
	artist := nonEmpty(info.PlaylistUploader, info.Channel)
	return &provider.AlbumResult{
		ID: id, Title: title, Artist: artist,
		CoverURL: info.Thumbnail, TrackCount: info.PlaylistCount, Provider: "youtube",
	}, nil
}

// GetArtist returns artist metadata from a YouTube channel.
func (c *Client) GetArtist(id string) (*provider.ArtistResult, error) {
	channelID := strings.TrimPrefix(id, "yt:")
	url := fmt.Sprintf("https://www.youtube.com/channel/%s", channelID)
	args := []string{"--dump-json", "--no-warnings", "--skip-download", "--playlist-end", "1", url}
	cmd := exec.Command(c.ytdlpPath, args...)
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("youtube: get artist failed: %w", err)
	}
	line := firstJSONLine(string(output))
	var info ytdlpTrack
	if err := json.Unmarshal([]byte(line), &info); err != nil {
		return nil, fmt.Errorf("youtube: parse artist failed: %w", err)
	}
	return &provider.ArtistResult{
		ID: id, Name: info.Channel, PictureURL: info.Thumbnail, Provider: "youtube",
	}, nil
}

// GetStreamURL returns a direct stream URL using yt-dlp -g.
func (c *Client) GetStreamURL(id, quality string) (string, error) {
	videoID := strings.TrimPrefix(id, "yt:")
	url := fmt.Sprintf("https://www.youtube.com/watch?v=%s", videoID)
	format := "bestaudio/best"
	switch quality {
	case "128":
		format = "bestaudio[abr<=128]/bestaudio/best"
	case "192":
		format = "bestaudio[abr<=192]/bestaudio/best"
	case "256":
		format = "bestaudio[abr<=256]/bestaudio/best"
	case "320":
		format = "bestaudio[abr<=320]/bestaudio/best"
	}
	args := []string{"-g", "-f", format, "--no-warnings", url}
	cmd := exec.Command(c.ytdlpPath, args...)
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("youtube: get stream URL failed: %w", err)
	}
	streamURL := strings.TrimSpace(string(output))
	if streamURL == "" {
		return "", fmt.Errorf("youtube: no stream URL returned for %s", videoID)
	}
	return streamURL, nil
}
