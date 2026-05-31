package gobackend

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

const (
	mbRequestWindow = 1100 * time.Millisecond
	mbCooldownDur   = 5 * time.Second
	mbMaxRetries    = 3
	mbUserAgent     = "Bitly/4.5.1 ( https://github.com/zarz/Bitly_android )"
)

type mbInflightKey struct {
	isrc      string
	queryType string
}

type mbInflightResult struct {
	result string
	err    error
}

type MusicBrainzClient struct {
	rl       *RateLimiter
	mu       sync.Mutex
	cooldown time.Time
	inflight map[mbInflightKey]chan mbInflightResult
}

var (
	globalMBClient *MusicBrainzClient
	initMBOnce     sync.Once
)

func GetMusicBrainzClient() *MusicBrainzClient {
	initMBOnce.Do(func() {
		globalMBClient = &MusicBrainzClient{
			rl:       NewRateLimiter(1, mbRequestWindow),
			inflight: make(map[mbInflightKey]chan mbInflightResult),
		}
	})
	return globalMBClient
}

func (c *MusicBrainzClient) waitForCooldown() {
	c.mu.Lock()
	now := time.Now()
	if now.Before(c.cooldown) {
		waitDur := c.cooldown.Sub(now)
		c.mu.Unlock()
		time.Sleep(waitDur)
		return
	}
	c.mu.Unlock()
}

func (c *MusicBrainzClient) enterCooldown() {
	c.mu.Lock()
	c.cooldown = time.Now().Add(mbCooldownDur)
	c.mu.Unlock()
}

func (c *MusicBrainzClient) doRequest(url string) (*http.Response, error) {
	c.waitForCooldown()
	c.rl.WaitForSlot()

	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", mbUserAgent)
	return NewMetadataHTTPClient(10 * time.Second).Do(req)
}

func (c *MusicBrainzClient) doRequestWithRetry(url string) (*http.Response, error) {
	var resp *http.Response
	var lastErr error

	for attempt := range mbMaxRetries {
		resp, lastErr = c.doRequest(url)
		if lastErr != nil {
			if attempt < mbMaxRetries-1 {
				time.Sleep(2 * time.Second)
			}
			continue
		}

		switch resp.StatusCode {
		case http.StatusOK:
			return resp, nil
		case http.StatusTooManyRequests, http.StatusServiceUnavailable:
			resp.Body.Close()
			c.enterCooldown()
			if attempt < mbMaxRetries-1 {
				time.Sleep(mbCooldownDur)
			}
			continue
		default:
			resp.Body.Close()
			return nil, fmt.Errorf("MusicBrainz API returned status: %d", resp.StatusCode)
		}
	}

	if resp != nil {
		resp.Body.Close()
	}
	if lastErr != nil {
		return nil, fmt.Errorf("MusicBrainz request failed after %d attempts: %w", mbMaxRetries, lastErr)
	}
	return nil, fmt.Errorf("MusicBrainz request failed after %d attempts", mbMaxRetries)
}

func (c *MusicBrainzClient) dedup(key mbInflightKey, fn func() (string, error)) (string, error) {
	c.mu.Lock()
	if ch, exists := c.inflight[key]; exists {
		c.mu.Unlock()
		result := <-ch
		return result.result, result.err
	}

	ch := make(chan mbInflightResult, 1)
	c.inflight[key] = ch
	c.mu.Unlock()

	var result mbInflightResult
	result.result, result.err = fn()

	c.mu.Lock()
	delete(c.inflight, key)
	c.mu.Unlock()

	ch <- result
	return result.result, result.err
}

func (c *MusicBrainzClient) FetchGenreByISRC(isrc string) (string, error) {
	normalizedISRC := strings.ToUpper(strings.TrimSpace(isrc))
	if normalizedISRC == "" {
		return "", fmt.Errorf("no ISRC provided")
	}

	key := mbInflightKey{isrc: normalizedISRC, queryType: "genre"}
	return c.dedup(key, func() (string, error) {
		reqURL := fmt.Sprintf(
			"%s/recording?query=%s&fmt=json&inc=tags",
			musicBrainzAPIBase,
			url.QueryEscape("isrc:"+normalizedISRC),
		)

		resp, err := c.doRequestWithRetry(reqURL)
		if err != nil {
			return "", err
		}
		defer resp.Body.Close()

		var payload musicBrainzRecordingResponse
		if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
			return "", err
		}
		if len(payload.Recordings) == 0 {
			return "", fmt.Errorf("no recordings found for ISRC: %s", normalizedISRC)
		}

		genre := formatMusicBrainzGenre(payload.Recordings[0].Tags)
		if genre == "" {
			return "", fmt.Errorf("no MusicBrainz genre tags found for ISRC: %s", normalizedISRC)
		}
		return genre, nil
	})
}

func (c *MusicBrainzClient) FetchAlbumArtistByISRC(isrc string, albumName string) (string, error) {
	normalizedISRC := strings.ToUpper(strings.TrimSpace(isrc))
	if normalizedISRC == "" {
		return "", fmt.Errorf("no ISRC provided")
	}

	key := mbInflightKey{isrc: normalizedISRC, queryType: "album_artist"}
	return c.dedup(key, func() (string, error) {
		reqURL := fmt.Sprintf(
			"%s/recording?query=%s&fmt=json&inc=releases+artist-credits",
			musicBrainzAPIBase,
			url.QueryEscape("isrc:"+normalizedISRC),
		)

		resp, err := c.doRequestWithRetry(reqURL)
		if err != nil {
			return "", err
		}
		defer resp.Body.Close()

		var payload musicBrainzAlbumArtistResponse
		if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
			return "", err
		}
		for _, recording := range payload.Recordings {
			if albumArtist := selectMusicBrainzAlbumArtist(recording.Releases, albumName); albumArtist != "" {
				return albumArtist, nil
			}
		}

		return "", fmt.Errorf("no MusicBrainz album artist found for ISRC: %s", normalizedISRC)
	})
}
