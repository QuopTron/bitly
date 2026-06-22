package youtube

import (
	"fmt"
	"net/http"
	"time"

	kkdai "github.com/kkdai/youtube/v2"
)

func getYouTubeStreamURL(videoID string) (string, error) {
	client := kkdai.Client{
		HTTPClient: &http.Client{
			Timeout: 15 * time.Second,
			Transport: &http.Transport{
				DisableKeepAlives: true,
			},
		},
	}

	fmt.Printf("[YTSearch] Getting video info for %s\n", videoID)
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

	fmt.Printf("[YTSearch] Selected format: itag=%d, width=%d, height=%d, mime=%s\n",
		bestFormat.ItagNo, bestFormat.Width, bestFormat.Height, bestFormat.MimeType)
	streamURL, err := client.GetStreamURL(video, bestFormat)
	if err != nil {
		return "", fmt.Errorf("get stream URL failed: %w", err)
	}

	return streamURL, nil
}
