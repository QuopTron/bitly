package youtube

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// ytdlpTrack contains fields from yt-dlp's full JSON output for a video/playlist entry.
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

// SearchAlbums searches YouTube Music for albums (playlists).
// Note: Results use video IDs, not playlist IDs (flat yt-dlp search).
// GetAlbum() on these IDs will fail — they are display/search results only.
func (c *Client) SearchAlbums(query string, limit int) ([]provider.AlbumResult, error) {
	if limit < 1 || limit > 100 {
		limit = 10
	}
	searchQuery := fmt.Sprintf("ytsearch%d:%s", limit, query)
	args := []string{
		"--dump-json", "--no-warnings", "--flat-playlist",
		"--extract-flat", "--skip-download",
		searchQuery,
	}
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
			ID:        "yt:" + sr.ID,
			Title:     sr.Title,
			Artist:    sr.Channel,
			CoverURL:  sr.Thumbnail,
			Provider:  "youtube",
		})
		if len(results) >= limit {
			break
		}
	}
	return results, nil
}

// SearchPlaylists searches YouTube Music for playlists using yt-dlp.
func (c *Client) SearchPlaylists(query string, limit int) ([]provider.PlaylistResult, error) {
	if limit < 1 || limit > 100 {
		limit = 10
	}
	searchQuery := fmt.Sprintf("ytsearchpl%d:%s", limit, query)
	args := []string{
		"--dump-json", "--no-warnings", "--flat-playlist",
		"--extract-flat", "--skip-download",
		searchQuery,
	}
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
			ID:         "yt:" + sr.ID,
			Title:      sr.Title,
			Creator:    sr.Channel,
			CoverURL:   sr.Thumbnail,
			Provider:   "youtube",
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
	// Request more results to account for deduplication
	searchQuery := fmt.Sprintf("ytsearch%d:%s", limit*3, query)
	args := []string{
		"--dump-json", "--no-warnings", "--flat-playlist",
		"--extract-flat", "--skip-download",
		searchQuery,
	}
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
		// Deduplicate by channel ID, skip entries with no channel name
		if sr.Channel == "" || sr.ChannelID == "" || seen[sr.ChannelID] {
			continue
		}
		seen[sr.ChannelID] = true
		results = append(results, provider.ArtistResult{
			ID:       "yt:" + sr.ChannelID,
			Name:     sr.Channel,
			Provider: "youtube",
		})
		if len(results) >= limit {
			break
		}
	}
	return results, nil
}

// GetTrack returns detailed track metadata by YouTube video ID.
func (c *Client) GetTrack(id string) (*provider.TrackResult, error) {
	videoID := strings.TrimPrefix(id, "yt:")
	url := fmt.Sprintf("https://music.youtube.com/watch?v=%s", videoID)
	args := []string{
		"--dump-json", "--no-warnings", "--skip-download",
		url,
	}
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
		ID:       "yt:" + track.ID,
		Title:    track.Title,
		Artist:   artist,
		Duration: track.Duration,
		CoverURL: track.Thumbnail,
		Provider: "youtube",
		Album:    track.Album,
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
	args := []string{
		"--dump-json", "--no-warnings", "--skip-download",
		"--playlist-end", "1",
		url,
	}
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

	// Prefer playlist-level metadata, fall back to entry fields
	title := nonEmpty(info.PlaylistTitle, info.Title)
	artist := nonEmpty(info.PlaylistUploader, info.Channel)

	return &provider.AlbumResult{
		ID:         id,
		Title:      title,
		Artist:     artist,
		CoverURL:   info.Thumbnail,
		TrackCount: info.PlaylistCount,
		Provider:   "youtube",
	}, nil
}

// GetArtist returns artist metadata from a YouTube channel.
func (c *Client) GetArtist(id string) (*provider.ArtistResult, error) {
	channelID := strings.TrimPrefix(id, "yt:")
	url := fmt.Sprintf("https://www.youtube.com/channel/%s", channelID)
	args := []string{
		"--dump-json", "--no-warnings", "--skip-download",
		"--playlist-end", "1",
		url,
	}
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
		ID:        id,
		Name:      info.Channel,
		PictureURL: info.Thumbnail,
		Provider:  "youtube",
	}, nil
}

// GetStreamURL returns a direct stream URL using yt-dlp -g.
// The URL is temporary (expires after hours).
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

	args := []string{
		"-g", "-f", format,
		"--no-warnings",
		url,
	}
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

// splitLines splits NDJSON output into non-empty lines.
func splitLines(out string) []string {
	lines := strings.Split(out, "\n")
	result := make([]string, 0, len(lines))
	for _, l := range lines {
		if trimmed := strings.TrimSpace(l); trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}

// firstJSONLine extracts the first JSON line from yt-dlp output (may contain warnings).
func firstJSONLine(out string) string {
	for _, line := range splitLines(out) {
		if strings.HasPrefix(line, "{") {
			return line
		}
	}
	return ""
}

// nonEmpty returns the first non-empty string.
func nonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}
