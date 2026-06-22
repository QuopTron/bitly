package lyrics

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/http"
)

type NeteaseClient struct {
	httpClient *http.Client
}

type neteaseSearchResponse struct {
	Result struct {
		Songs []struct {
			Name    string `json:"name"`
			ID      int64  `json:"id"`
			Artists []struct {
				Name string `json:"name"`
			} `json:"artists"`
		} `json:"songs"`
		SongCount int `json:"songCount"`
	} `json:"result"`
	Code int `json:"code"`
}

type neteaseLyricsResponse struct {
	LRC     *neteaseLyricField `json:"lrc"`
	TLyric  *neteaseLyricField `json:"tlyric"`
	RomaLRC *neteaseLyricField `json:"romalrc"`
	Code    int                `json:"code"`
}

type neteaseLyricField struct {
	Lyric string `json:"lyric"`
}

func NewNeteaseClient() *NeteaseClient {
	return &NeteaseClient{
		httpClient: httpclient.NewMetadataClient(15 * time.Second),
	}
}

func (c *NeteaseClient) SearchSong(trackName, artistName string) (int64, error) {
	query := strings.TrimSpace(trackName + " " + artistName)
	if query == "" {
		return 0, fmt.Errorf("empty search query")
	}

	searchURL := "https://lyrics.paxsenix.org/netease/search?q=" + url.QueryEscape(query)
	req, err := http.NewRequest("GET", searchURL, nil)
	if err != nil {
		return 0, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Accept-Language", "en-US,en;q=0.9")
	req.Header.Set("User-Agent", httpclient.UserAgentForURL(nil))

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return 0, fmt.Errorf("netease search failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return 0, fmt.Errorf("netease search returned HTTP %d", resp.StatusCode)
	}

	var searchResp neteaseSearchResponse
	if err := json.NewDecoder(resp.Body).Decode(&searchResp); err != nil {
		return 0, fmt.Errorf("failed to decode netease search: %w", err)
	}
	if searchResp.Result.SongCount == 0 || len(searchResp.Result.Songs) == 0 {
		return 0, fmt.Errorf("no songs found on netease")
	}
	return searchResp.Result.Songs[0].ID, nil
}
