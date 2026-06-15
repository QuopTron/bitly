//go:build !android
// +build !android

package gobackend

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"

	kkdai "github.com/kkdai/youtube/v2"
)

// ytDlpSearchTimeout is the max time allowed for yt-dlp to resolve a stream URL.
const ytDlpSearchTimeout = 30 * time.Second

// ytDlpDownloadTimeout is the max time allowed for yt-dlp to download a video.
const ytDlpDownloadTimeout = 5 * time.Minute

var globalSearchTimeout = 15 * time.Second

// searchFailureCache caches failed search queries to avoid retrying the same
// track repeatedly when YouTube is rate-limiting or videos aren't found.
var searchFailureCache sync.Map

const searchFailureCacheTTL = 5 * time.Minute

type searchFailureEntry struct {
	expiresAt time.Time
}

type innertubeClient struct {
	Name    string `json:"clientName"`
	Version string `json:"clientVersion"`
}

type innertubeContext struct {
	Client innertubeClient `json:"client"`
}

type searchPayload struct {
	Context innertubeContext `json:"context"`
	Query   string           `json:"query"`
}

type searchClient struct {
	Name    string
	Version string
	Key     string
}

var searchClients = []searchClient{
	{Name: "WEB", Version: "2.20220801.00.00", Key: "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"},
	{Name: "WEB_REMIX", Version: "1.20250227.01.00", Key: "AIzaSyC9XL3ZjB78yOKwTtGZ1l2M2Gc0xTpU7S4"},
	{Name: "ANDROID_VR", Version: "1.65.10", Key: "AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w"},
	{Name: "ANDROID", Version: "20.10.38", Key: "AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w"},
	{Name: "IOS", Version: "19.45.4", Key: "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"},
}

var httpClient = &http.Client{
	Timeout:   10 * time.Second,
	Transport: &http.Transport{
		DisableKeepAlives: true,
	},
}

// SearchYouTubeVideo searches for a YouTube video stream URL.
// First checks the lightweight URL cache (SQLite, TTL 24h), then tries yt-dlp,
// then falls back to InnerTube API. Found URLs are cached for next time.
func SearchYouTubeVideo(trackName, artistName string) (string, error) {
	// 1. Check URL cache first
	cachedURL, err := GetVideoURLCache(trackName, artistName)
	if err == nil && cachedURL != "" {
		GoLog("[YTSearch] Using cached video URL for: %s - %s\n", artistName, trackName)
		return cachedURL, nil
	}

	// 2. Ensure yt-dlp binary is available
	if err := EnsureYtDlp(); err != nil {
		GoLog("[YTSearch] Failed to ensure yt-dlp: %v\n", err)
		// Continue to InnerTube fallback
		if url, innerErr := searchInnerTube(trackName, artistName); innerErr == nil && url != "" {
			SetVideoURLCache(trackName, artistName, url)
			return url, nil
		}
		return "", err
	}

	// 3. Try yt-dlp FIRST (more reliable, avoids 429 rate-limiting)
	GoLog("[YTSearch] Searching with yt-dlp for: %s - %s\n", artistName, trackName)
	url, err := searchWithYtDlp(trackName, artistName)
	if err == nil && url != "" {
		GoLog("[YTSearch] yt-dlp found stream: %s\n", url[:min(len(url), 80)])
		SetVideoURLCache(trackName, artistName, url)
		return url, nil
	}
	if err != nil {
		GoLog("[YTSearch] yt-dlp failed: %v, falling back to InnerTube\n", err)
	} else {
		GoLog("[YTSearch] yt-dlp returned empty, falling back to InnerTube\n")
	}

	// 4. Fallback to InnerTube API
	innerURL, innerErr := searchInnerTube(trackName, artistName)
	if innerErr == nil && innerURL != "" {
		SetVideoURLCache(trackName, artistName, innerURL)
	}
	return innerURL, innerErr
}

// searchWithYtDlp tries to find a YouTube video stream URL using yt-dlp.
// A context timeout prevents hanging if yt-dlp stalls.
func searchWithYtDlp(trackName, artistName string) (string, error) {
	query := artistName + " " + trackName
	ytPath := GetYtDlpPath()
	GoLog("[YTSearch] yt-dlp path: %s\n", ytPath)
	if fi, err := os.Stat(ytPath); err == nil {
		GoLog("[YTSearch] yt-dlp exists: size=%d mode=%s\n", fi.Size(), fi.Mode().String())
	} else {
		GoLog("[YTSearch] yt-dlp stat error: %v\n", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), ytDlpSearchTimeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, ytPath,
		"--default-search", "ytsearch",
		"-f", "best[height<=720]",
		"-g",
		"--no-playlist",
		"--no-warnings",
		"--ignore-errors",
		query,
	)
	out, err := cmd.CombinedOutput()
	if err != nil {
		// Distinguish timeout from other errors for logging clarity
		if ctx.Err() != nil {
			GoLog("[YTSearch] yt-dlp search timed out after %v\n", ytDlpSearchTimeout)
			return "", fmt.Errorf("yt-dlp search timed out after %v", ytDlpSearchTimeout)
		}
		outStr := strings.TrimSpace(string(out))
		if outStr != "" {
			parts := strings.Split(outStr, "\n")
			for _, p := range parts {
				p = strings.TrimSpace(p)
				if strings.HasPrefix(p, "http://") || strings.HasPrefix(p, "https://") {
					return p, nil
				}
			}
		}
		return "", err
	}

	url := strings.TrimSpace(string(out))
	if url == "" {
		return "", nil
	}
	return strings.Split(url, "\n")[0], nil
}

// searchInnerTube performs YouTube search using InnerTube API.
func searchInnerTube(trackName, artistName string) (string, error) {
	searchQuery := artistName + " " + trackName
	GoLog("[YTSearch] Searching for: %s\n", searchQuery)

	// Check failure cache
	if cached, ok := searchFailureCache.Load(searchQuery); ok {
		if entry, ok := cached.(searchFailureEntry); ok && time.Now().Before(entry.expiresAt) {
			GoLog("[YTSearch] Skipping cached failed search for: %s\n", searchQuery)
			return "", fmt.Errorf("cached failure for %q", searchQuery)
		}
		searchFailureCache.Delete(searchQuery)
	}

	type result struct {
		url         string
		err         error
		rateLimited bool
	}

	done := make(chan result, 1)
	go func() {
		for _, sc := range searchClients {
			if isDownloadCancelled("") {
				done <- result{err: fmt.Errorf("search cancelled")}
				return
			}
			GoLog("[YTSearch] Trying client: %s v%s\n", sc.Name, sc.Version)
			streamURL, err := searchInnerTubeClient(sc, searchQuery)
			if err == nil && streamURL != "" {
				GoLog("[YTSearch] Found stream via %s\n", sc.Name)
				done <- result{url: streamURL}
				return
			}
			GoLog("[YTSearch] %s failed: %v\n", sc.Name, err)

			if err != nil && isRateLimitError(err) {
				GoLog("[YTSearch] Rate-limited on %s, stopping search\n", sc.Name)
				done <- result{err: fmt.Errorf("rate-limited: %w", err), rateLimited: true}
				return
			}
		}
		done <- result{err: fmt.Errorf("no video found for %q", searchQuery)}
	}()

	select {
	case r := <-done:
		if r.err != nil && (r.rateLimited || strings.Contains(r.err.Error(), "429")) {
			searchFailureCache.Store(searchQuery, searchFailureEntry{expiresAt: time.Now().Add(searchFailureCacheTTL)})
			GoLog("[YTSearch] Cached failure for %s (5 min TTL)\n", searchQuery)
		}
		return r.url, r.err
	case <-time.After(globalSearchTimeout):
		GoLog("[YTSearch] Global timeout (%v) reached\n", globalSearchTimeout)
		searchFailureCache.Store(searchQuery, searchFailureEntry{expiresAt: time.Now().Add(searchFailureCacheTTL)})
		return "", fmt.Errorf("search timed out after %v", globalSearchTimeout)
	}
}

func isRateLimitError(err error) bool {
	if err == nil {
		return false
	}
	errStr := err.Error()
	return strings.Contains(errStr, "429") || strings.Contains(errStr, "HTTP 429") || strings.Contains(errStr, "Too Many Requests")
}

func searchInnerTubeClient(sc searchClient, query string) (string, error) {
	payload := searchPayload{
		Context: innertubeContext{
			Client: innertubeClient{
				Name:    sc.Name,
				Version: sc.Version,
			},
		},
		Query: query,
	}

	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("marshal: %w", err)
	}

	apiURL := fmt.Sprintf("https://www.youtube.com/youtubei/v1/search?key=%s", sc.Key)
	req, err := http.NewRequest("POST", apiURL, bytes.NewReader(bodyBytes))
	if err != nil {
		return "", fmt.Errorf("create req: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

	resp, err := httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("http: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("read: %w", err)
	}

	if resp.StatusCode != 200 {
		return "", fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(respBody[:min(len(respBody), 200)]))
	}

	var result map[string]interface{}
	if err := json.Unmarshal(respBody, &result); err != nil {
		return "", fmt.Errorf("json: %w", err)
	}

	if errObj, ok := result["error"].(map[string]interface{}); ok {
		errMsg, _ := errObj["message"].(string)
		return "", fmt.Errorf("InnerTube error: %s", errMsg)
	}

	videoIDs := extractInnerTubeVideoIDs(result)
	GoLog("[YTSearch] %s returned %d video IDs\n", sc.Name, len(videoIDs))

	maxVids := 1
	if len(videoIDs) < maxVids {
		maxVids = len(videoIDs)
	}
	for _, vid := range videoIDs[:maxVids] {
		streamURL, err := getYouTubeStreamURL(vid)
		if err == nil {
			return streamURL, nil
		}
		GoLog("[YTSearch] vid %s failed: %v\n", vid, err)
		if isRateLimitError(err) {
			return "", fmt.Errorf("HTTP 429: %w", err)
		}
	}

	return "", fmt.Errorf("no usable videos")
}

func extractInnerTubeVideoIDs(data map[string]interface{}) []string {
	seen := map[string]bool{}
	var ids []string
	extractVideoIDsRecursive(data, &ids, &seen)
	return ids
}

func extractVideoIDsRecursive(v interface{}, ids *[]string, seen *map[string]bool) {
	switch val := v.(type) {
	case map[string]interface{}:
		if vid, ok := val["videoId"].(string); ok && vid != "" && len(vid) == 11 && !(*seen)[vid] {
			(*seen)[vid] = true
			*ids = append(*ids, vid)
		}
		for _, child := range val {
			extractVideoIDsRecursive(child, ids, seen)
		}
	case []interface{}:
		for _, child := range val {
			extractVideoIDsRecursive(child, ids, seen)
		}
	}
}

func getYouTubeStreamURL(videoID string) (string, error) {
	client := kkdai.Client{
		HTTPClient: &http.Client{
			Timeout:   15 * time.Second,
			Transport: &http.Transport{
				DisableKeepAlives: true,
			},
		},
	}

	GoLog("[YTSearch] Getting video info for %s\n", videoID)
	video, err := client.GetVideo(videoID)
	if err != nil {
		return "", fmt.Errorf("get video info failed: %w", err)
	}

	var bestFormat *kkdai.Format
	for i, f := range video.Formats {
		if f.AudioChannels > 0 && f.Width > 0 {
			if bestFormat == nil || (f.Width >= 360 && f.Width < 720) {
				bestFormat = &video.Formats[i]
			}
		}
	}
	if bestFormat == nil {
		return "", fmt.Errorf("no video+audio format available")
	}

	GoLog("[YTSearch] Selected format: itag=%d, width=%d, height=%d, mime=%s\n",
		bestFormat.ItagNo, bestFormat.Width, bestFormat.Height, bestFormat.MimeType)
	streamURL, err := client.GetStreamURL(video, bestFormat)
	if err != nil {
		return "", fmt.Errorf("get stream URL failed: %w", err)
	}

	return streamURL, nil
}

// DownloadYouTubeVideo downloads a YouTube video.
// First tries yt-dlp (more reliable), then falls back to InnerTube stream download.
func DownloadYouTubeVideo(trackName, artistName, outputPath string) (string, error) {
	GoLog("[YTDL] Downloading video: %s - %s\n", artistName, trackName)

	// Ensure yt-dlp binary is available before trying to use it.
	ytDlpErr := EnsureYtDlp()
	if ytDlpErr == nil {
		// Try yt-dlp FIRST
		url, err := downloadWithYtDlp(trackName, artistName, outputPath)
		if err == nil && url != "" {
			return url, nil
		}
		if err != nil {
			GoLog("[YTDL] yt-dlp download failed: %v, falling back to InnerTube stream\n", err)
		} else {
			GoLog("[YTDL] yt-dlp returned empty, falling back to InnerTube stream\n")
		}
	} else {
		GoLog("[YTDL] yt-dlp not available (%v), using InnerTube directly\n", ytDlpErr)
	}

	// Fallback: search via InnerTube directly (avoid redundant EnsureYtDlp call)
	streamURL, err := searchInnerTube(trackName, artistName)
	if err != nil {
		GoLog("[YTDL] Search failed: %v\n", err)
		return "", err
	}
	GoLog("[YTDL] Got stream URL, downloading to %s\n", outputPath)
	result, err := downloadFromStreamURL(streamURL, outputPath)
	if err != nil {
		GoLog("[YTDL] Download failed: %v\n", err)
		return "", err
	}
	GoLog("[YTDL] Download complete: %s\n", result)
	return result, nil
}

// downloadWithYtDlp downloads a YouTube video using yt-dlp.
// A context timeout prevents hanging if yt-dlp stalls.
func downloadWithYtDlp(trackName, artistName, outputPath string) (string, error) {
	query := artistName + " " + trackName

	os.Remove(outputPath)

	ctx, cancel := context.WithTimeout(context.Background(), ytDlpDownloadTimeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, GetYtDlpPath(),
		"--default-search", "ytsearch",
		"-f", "best[height<=720]",
		"-o", outputPath,
		"--no-playlist",
		"--no-warnings",
		"--ignore-errors",
		"--merge-output-format", "mp4",
		query,
	)
	out, err := cmd.CombinedOutput()
	if err != nil {
		if ctx.Err() != nil {
			GoLog("[YTDL] yt-dlp download timed out after %v\n", ytDlpDownloadTimeout)
			return "", fmt.Errorf("yt-dlp download timed out after %v", ytDlpDownloadTimeout)
		}
		outStr := strings.TrimSpace(string(out))
		if outStr != "" {
			return "", fmt.Errorf("yt-dlp failed: %s", outStr)
		}
		return "", err
	}

	if _, statErr := os.Stat(outputPath); statErr == nil {
		return outputPath, nil
	}

	for _, ext := range []string{".mp4", ".webm", ".mkv"} {
		candidate := outputPath + ext
		if _, statErr := os.Stat(candidate); statErr == nil {
			return candidate, nil
		}
	}

	return outputPath, nil
}

func downloadFromStreamURL(streamURL, outputPath string) (string, error) {
	dlClient := &http.Client{
		Timeout:   5 * time.Minute,
		Transport: &http.Transport{
			DisableKeepAlives: true,
		},
	}
	defer dlClient.CloseIdleConnections()

	resp, err := dlClient.Get(streamURL)
	if err != nil {
		return "", fmt.Errorf("download request failed: %w", err)
	}
	defer resp.Body.Close()

	os.Remove(outputPath)
	out, err := os.Create(outputPath)
	if err != nil {
		return "", fmt.Errorf("failed to create output file: %w", err)
	}
	defer out.Close()

	_, err = io.Copy(out, resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to download: %w", err)
	}

	return outputPath, nil
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
