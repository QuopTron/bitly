//go:build android

package gobackend

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"

	kkdai "github.com/kkdai/youtube/v2"
)

var globalSearchTimeout = 30 * time.Second

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

func SearchYouTubeVideo(trackName, artistName string) (string, error) {
	searchQuery := artistName + " " + trackName
	GoLog("[YTSearch] Searching for: %s\n", searchQuery)

	type result struct {
		url string
		err error
	}

	done := make(chan result, 1)
	go func() {
		for _, sc := range searchClients {
			GoLog("[YTSearch] Trying client: %s v%s\n", sc.Name, sc.Version)
			streamURL, err := searchInnerTube(sc, searchQuery)
			if err == nil && streamURL != "" {
				GoLog("[YTSearch] Found stream via %s\n", sc.Name)
				done <- result{url: streamURL}
				return
			}
			GoLog("[YTSearch] %s failed: %v\n", sc.Name, err)
		}
		done <- result{err: fmt.Errorf("no video found for %q", searchQuery)}
	}()

	select {
	case r := <-done:
		return r.url, r.err
	case <-time.After(globalSearchTimeout):
		GoLog("[YTSearch] Global timeout (%v) reached\n", globalSearchTimeout)
		return "", fmt.Errorf("search timed out after %v", globalSearchTimeout)
	}
}

func searchInnerTube(sc searchClient, query string) (string, error) {
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
	req.Header.Set("User-Agent", "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36")

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

	maxVids := 3
	if len(videoIDs) < maxVids {
		maxVids = len(videoIDs)
	}
	for _, vid := range videoIDs[:maxVids] {
		streamURL, err := getYouTubeStreamURL(vid)
		if err == nil {
			return streamURL, nil
		}
		GoLog("[YTSearch] vid %s failed: %v\n", vid, err)
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

func DownloadYouTubeVideo(trackName, artistName, outputPath string) (string, error) {
	GoLog("[YTDl] Downloading video: %s - %s\n", artistName, trackName)
	streamURL, err := SearchYouTubeVideo(trackName, artistName)
	if err != nil {
		GoLog("[YTDl] Search failed: %v\n", err)
		return "", err
	}
	GoLog("[YTDl] Got stream URL, downloading to %s\n", outputPath)
	result, err := downloadFromStreamURL(streamURL, outputPath)
	if err != nil {
		GoLog("[YTDl] Download failed: %v\n", err)
		return "", err
	}
	GoLog("[YTDl] Download complete: %s\n", result)
	return result, nil
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
