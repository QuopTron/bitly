package youtube

import (
	"encoding/json"
	"fmt"
	"os/exec"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// ytdlpTrack contains fields from yt-dlp's full JSON output.
type ytdlpTrack struct {
	ID               string `json:"id"`
	Title            string `json:"title"`
	Duration         int    `json:"duration"`
	Channel          string `json:"channel"`
	ChannelID        string `json:"channel_id"`
	Thumbnail        string `json:"thumbnail"`
	PlaylistID       string `json:"playlist_id,omitempty"`
	PlaylistTitle    string `json:"playlist_title,omitempty"`
	PlaylistUploader string `json:"playlist_uploader,omitempty"`
	PlaylistCount    int    `json:"playlist_count,omitempty"`
	Track            string `json:"track,omitempty"`
	Artist           string `json:"artist,omitempty"`
	Album            string `json:"album,omitempty"`
}

// SearchAlbums searches YouTube Music for albums.
func (c *Client) SearchAlbums(query string, limit int) ([]provider.AlbumResult, error) {
	if limit < 1 || limit > 100 {
		limit = 10
	}
	searchQuery := fmt.Sprintf("ytsearch%d:%s", limit, query)
	args := []string{"--dump-json", "--no-warnings", "--flat-playlist",
		"--extract-flat", "--skip-download", searchQuery}
	cmd := exec.Command(c.ytdlpPath, args...)
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("youtube: album search failed: %w", err)
	}
	results := make([]provider.AlbumResult, 0)
	for _, line := range splitLines(string(output)) {
		var sr searchResult
		if err := json.Unmarshal([]byte(line), &sr); err != nil {
			continue
		}
		results = append(results, provider.AlbumResult{
			ID: "yt:" + sr.ID, Title: sr.Title, Artist: sr.Channel,
			CoverURL: sr.Thumbnail, Provider: "youtube",
		})
		if len(results) >= limit {
			break
		}
	}
	return results, nil
}

// SearchPlaylists searches YouTube Music for playlists.
func (c *Client) SearchPlaylists(query string, limit int) ([]provider.PlaylistResult, error) {
	if limit < 1 || limit > 100 {
		limit = 10
	}
	searchQuery := fmt.Sprintf("ytsearchpl%d:%s", limit, query)
	args := []string{"--dump-json", "--no-warnings", "--flat-playlist",
		"--extract-flat", "--skip-download", searchQuery}
	cmd := exec.Command(c.ytdlpPath, args...)
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("youtube: playlist search failed: %w", err)
	}
	results := make([]provider.PlaylistResult, 0)
	for _, line := range splitLines(string(output)) {
		var sr searchResult
		if err := json.Unmarshal([]byte(line), &sr); err != nil {
			continue
		}
		results = append(results, provider.PlaylistResult{
			ID: "yt:" + sr.ID, Title: sr.Title, Creator: sr.Channel,
			CoverURL: sr.Thumbnail, Provider: "youtube",
		})
		if len(results) >= limit {
			break
		}
	}
	return results, nil
}

// SearchArtists searches YouTube Music for artists (channels).
func (c *Client) SearchArtists(query string, limit int) ([]provider.ArtistResult, error) {
	if limit < 1 || limit > 100 {
		limit = 10
	}
	searchQuery := fmt.Sprintf("ytsearch%d:%s", limit*3, query)
	args := []string{"--dump-json", "--no-warnings", "--flat-playlist",
		"--extract-flat", "--skip-download", searchQuery}
	cmd := exec.Command(c.ytdlpPath, args...)
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("youtube: artist search failed: %w", err)
	}
	seen := make(map[string]bool)
	results := make([]provider.ArtistResult, 0)
	for _, line := range splitLines(string(output)) {
		var sr searchResult
		if err := json.Unmarshal([]byte(line), &sr); err != nil {
			continue
		}
		if sr.Channel == "" || sr.ChannelID == "" || seen[sr.ChannelID] {
			continue
		}
		seen[sr.ChannelID] = true
		results = append(results, provider.ArtistResult{
			ID: "yt:" + sr.ChannelID, Name: sr.Channel, Provider: "youtube",
		})
		if len(results) >= limit {
			break
		}
	}
	return results, nil
}
