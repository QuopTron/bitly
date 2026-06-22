package availability

import (
	"encoding/json"
	"fmt"
	"io"
	"net/url"
	"strings"
)

func (lr *LinkResolver) resolveViaDeezerSonglink(isrc string) (*ISRCResolutionResult, error) {
	deezerURL := fmt.Sprintf("https://api.deezer.com/2.0/track/isrc:%s", isrc)
	resp, err := lr.httpClient.Get(deezerURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var deezerResp struct {
		ID     int    `json:"id"`
		Title  string `json:"title"`
		Link   string `json:"link"`
		Artist struct {
			Name string `json:"name"`
		} `json:"artist"`
		Album struct {
			Title string `json:"title"`
		} `json:"album"`
	}
	if err := json.Unmarshal(body, &deezerResp); err != nil {
		return nil, err
	}
	if deezerResp.ID == 0 {
		return nil, fmt.Errorf("linkresolver: ISRC not found on Deezer: %s", isrc)
	}

	songlinkURL := fmt.Sprintf("https://api.song.link/v1-beta.1/links?url=%s&userCountry=US",
		url.PathEscape(deezerResp.Link))
	resp2, err := lr.httpClient.Get(songlinkURL)
	if err != nil {
		return &ISRCResolutionResult{
			ISRC:      isrc,
			DeezerURL: deezerResp.Link,
		}, nil
	}
	defer resp2.Body.Close()

	body2, err := io.ReadAll(resp2.Body)
	if err != nil {
		return &ISRCResolutionResult{ISRC: isrc, DeezerURL: deezerResp.Link}, nil
	}

	var songlinkResp struct {
		LinksByPlatform map[string]struct {
			URL string `json:"url"`
		} `json:"linksByPlatform"`
	}
	if err := json.Unmarshal(body2, &songlinkResp); err != nil {
		return &ISRCResolutionResult{ISRC: isrc, DeezerURL: deezerResp.Link}, nil
	}

	result := &ISRCResolutionResult{ISRC: isrc}
	for platform, link := range songlinkResp.LinksByPlatform {
		switch {
		case strings.Contains(platform, "tidal"):
			result.TidalURL = link.URL
		case strings.Contains(platform, "qobuz"):
			result.QobuzURL = link.URL
		case strings.Contains(platform, "deezer"):
			result.DeezerURL = link.URL
		case strings.Contains(platform, "spotify"):
			result.SpotifyURL = link.URL
		}
	}
	return result, nil
}
