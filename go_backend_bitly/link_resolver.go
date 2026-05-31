package gobackend

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"sync"
	"time"
)

type ISRCResolutionResult struct {
	ISRC       string `json:"isrc"`
	TidalURL   string `json:"tidal_url,omitempty"`
	QobuzURL   string `json:"qobuz_url,omitempty"`
	DeezerURL  string `json:"deezer_url,omitempty"`
	SpotifyURL string `json:"spotify_url,omitempty"`
	Provider   string `json:"provider"`
}

type LinkResolver struct {
	httpClient *http.Client
	mu         sync.RWMutex
	resolverPriority []string
}

var (
	linkResolver     *LinkResolver
	linkResolverOnce sync.Once
)

func GetLinkResolver() *LinkResolver {
	linkResolverOnce.Do(func() {
		linkResolver = &LinkResolver{
			httpClient: &http.Client{
				Timeout: 30 * time.Second,
			},
			resolverPriority: []string{"songstats", "deezer_songlink"},
		}
	})
	return linkResolver
}

func (lr *LinkResolver) ResolveByISRC(isrc string) (*ISRCResolutionResult, error) {
	for _, provider := range lr.resolverPriority {
		switch provider {
		case "deezer_songlink":
			result, err := lr.resolveViaDeezerSonglink(isrc)
			if err == nil && result != nil {
				result.Provider = "deezer_songlink"
				return result, nil
			}
		case "songstats":
			result, err := lr.resolveViaSongstats(isrc)
			if err == nil && result != nil {
				result.Provider = "songstats"
				return result, nil
			}
		}
	}
	return nil, fmt.Errorf("all link resolvers failed for ISRC: %s", isrc)
}

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
		return nil, fmt.Errorf("ISRC not found on Deezer: %s", isrc)
	}

	songlinkURL := fmt.Sprintf("https://api.song.link/v1-beta.1/links?url=%s&userCountry=US",
		urlQueryEscape(deezerResp.Link))
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

func (lr *LinkResolver) resolveViaSongstats(isrc string) (*ISRCResolutionResult, error) {
	songstatsURL := fmt.Sprintf("https://api.songstats.com/v1/tracks?isrc=%s&platforms=tidal,qobuz,deezer,spotify", isrc)
	req, err := http.NewRequest("GET", songstatsURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
	req.Header.Set("Accept", "application/json")

	resp, err := lr.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var songstatsResp struct {
		Data []struct {
			ISRC    string `json:"isrc"`
			Streams []struct {
				Platform string `json:"platform"`
				URL      string `json:"url"`
			} `json:"streams"`
		} `json:"data"`
	}
	if err := json.Unmarshal(body, &songstatsResp); err != nil {
		return nil, err
	}
	if len(songstatsResp.Data) == 0 {
		return nil, fmt.Errorf("ISRC not found on Songstats: %s", isrc)
	}

	result := &ISRCResolutionResult{ISRC: isrc}
	for _, stream := range songstatsResp.Data[0].Streams {
		switch strings.ToLower(stream.Platform) {
		case "tidal":
			result.TidalURL = stream.URL
		case "qobuz":
			result.QobuzURL = stream.URL
		case "deezer":
			result.DeezerURL = stream.URL
		case "spotify":
			result.SpotifyURL = stream.URL
		}
	}
	return result, nil
}

var spotifyTrackRe = regexp.MustCompile(`spotify:track:([a-zA-Z0-9]+)|open\.spotify\.com/track/([a-zA-Z0-9]+)`)

func (lr *LinkResolver) ISRCFromSpotify(spotifyID string) (string, error) {
	url := fmt.Sprintf("https://api.spotify.com/v1/tracks/%s", spotifyID)
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0")

	resp, err := lr.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	var track struct {
		ExternalIDs struct {
			ISRC string `json:"isrc"`
		} `json:"external_ids"`
		Name   string `json:"name"`
		Artists []struct {
			Name string `json:"name"`
		} `json:"artists"`
		Album struct {
			Name string `json:"name"`
		} `json:"album"`
	}
	if err := json.Unmarshal(body, &track); err != nil {
		return "", err
	}
	if track.ExternalIDs.ISRC == "" {
		return "", fmt.Errorf("no ISRC found for Spotify track: %s", spotifyID)
	}
	return track.ExternalIDs.ISRC, nil
}

func urlQueryEscape(s string) string {
	return url.PathEscape(s)
}