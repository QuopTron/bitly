package metadata

import (
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"
)

// Cover URL size constants.
const (
	spotifySize300 = "ab67616d00001e02"
	spotifySize640 = "ab67616d0000b273"
	spotifySizeMax = "ab67616d000082c1"
)

// Deezer CDN supports these sizes: 56, 250, 500, 1000, 1400, 1800
var deezerSizeRegex = regexp.MustCompile(`/(\d+)x(\d+)-(\d+)-(\d+)-(\d+)-(\d+)\.jpg$`)

var tidalSizeRegex = regexp.MustCompile(`/\d+x\d+\.jpg$`)

var qobuzSizeRegex = regexp.MustCompile(`_\d+\.jpg$`)

// DefaultCoverTimeout is the HTTP timeout for cover downloads.
const DefaultCoverTimeout = 15

// convertSmallToMedium converts a Spotify 300x300 URL to 640x640.
func convertSmallToMedium(imageURL string) string {
	if strings.Contains(imageURL, spotifySize300) {
		return strings.Replace(imageURL, spotifySize300, spotifySize640, 1)
	}
	return imageURL
}

// DownloadCoverToMemory downloads cover art to memory, optionally at max quality.
func DownloadCoverToMemory(coverURL string, maxQuality bool) ([]byte, error) {
	if coverURL == "" {
		return nil, fmt.Errorf("no cover URL provided")
	}

	// LogDebug("Cover", "Original URL: %s", coverURL)

	downloadURL := convertSmallToMedium(coverURL)
	// if downloadURL != coverURL {
	// 	LogDebug("Cover", "Upgraded 300x300 to 640x640")
	// }

	if maxQuality {
		maxURL := upgradeToMaxQuality(downloadURL)
		if maxURL != downloadURL {
			downloadURL = maxURL
			// if strings.Contains(coverURL, "scdn.co") || strings.Contains(coverURL, "spotifycdn") {
			// 	LogInfo("Cover", "Spotify: upgraded to max resolution (~2000x2000)")
			// }
		}
	}

	// LogDebug("Cover", "Final URL: %s", downloadURL)

	client := &http.Client{}
	req, err := http.NewRequest("GET", downloadURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36")

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to download cover: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("cover download failed: HTTP %d", resp.StatusCode)
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read cover data: %w", err)
	}

	// sizeKB := len(data) / 1024
	// LogInfo("Cover", "Downloaded %d KB", sizeKB)

	return data, nil
}

// upgradeToMaxQuality attempts to upscale a cover URL to the maximum available resolution.
func upgradeToMaxQuality(coverURL string) string {
	if strings.Contains(coverURL, spotifySize640) {
		return strings.Replace(coverURL, spotifySize640, spotifySizeMax, 1)
	}
	if strings.Contains(coverURL, "cdn-images.dzcdn.net") {
		return upgradeDeezerCover(coverURL)
	}
	if strings.Contains(coverURL, "resources.tidal.com") {
		return upgradeTidalCover(coverURL)
	}
	if strings.Contains(coverURL, "static.qobuz.com") {
		return upgradeQobuzCover(coverURL)
	}
	return coverURL
}

func upgradeDeezerCover(coverURL string) string {
	if !strings.Contains(coverURL, "cdn-images.dzcdn.net") {
		return coverURL
	}
	upgraded := deezerSizeRegex.ReplaceAllString(coverURL, "/1800x1800-000000-80-0-0.jpg")
	return upgraded
}

func upgradeTidalCover(coverURL string) string {
	if !strings.Contains(coverURL, "resources.tidal.com") {
		return coverURL
	}
	upgraded := tidalSizeRegex.ReplaceAllString(coverURL, "/origin.jpg")
	return upgraded
}

func upgradeQobuzCover(coverURL string) string {
	if !strings.Contains(coverURL, "static.qobuz.com") {
		return coverURL
	}
	upgraded := qobuzSizeRegex.ReplaceAllString(coverURL, "_max.jpg")
	return upgraded
}

// GetCoverFromSpotify normalizes and optionally upscales a Spotify image URL.
func GetCoverFromSpotify(imageURL string, maxQuality bool) string {
	if imageURL == "" {
		return ""
	}
	result := convertSmallToMedium(imageURL)
	if maxQuality {
		result = upgradeToMaxQuality(result)
	}
	return result
}
