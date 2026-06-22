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

type GeniusLyricsClient struct {
	httpClient *http.Client
}

type geniusSearchResponse struct {
	Response struct {
		Sections []struct {
			Hits []struct {
				Type   string `json:"type"`
				Result struct {
					Title              string `json:"title"`
					ArtistNames        string `json:"artist_names"`
					PrimaryArtistNames string `json:"primary_artist_names"`
					URL                string `json:"url"`
				} `json:"result"`
			} `json:"hits"`
		} `json:"sections"`
	} `json:"response"`
}

func NewGeniusLyricsClient() *GeniusLyricsClient {
	return &GeniusLyricsClient{httpClient: httpclient.NewMetadataClient(15 * time.Second)}
}

func (c *GeniusLyricsClient) searchSong(trackName, artistName string, durationSec float64) (string, error) {
	query := strings.TrimSpace(trackName + " " + artistName)
	if query == "" {
		return "", fmt.Errorf("empty search query")
	}
	params := url.Values{}
	params.Set("q", query)
	params.Set("per_page", "10")
	raw, err := fetchPaxsenixBody(c.httpClient, "https://genius.com/api/search/multi", params)
	if err != nil {
		return "", fmt.Errorf("genius search failed: %w", err)
	}

	var results geniusSearchResponse
	if err := json.Unmarshal([]byte(raw), &results); err != nil {
		return "", fmt.Errorf("failed to decode genius search: %w", err)
	}

	bestURL, bestScore := "", -1
	for _, section := range results.Response.Sections {
		for _, hit := range section.Hits {
			if hit.Type != "song" || strings.TrimSpace(hit.Result.URL) == "" {
				continue
			}
			artist := hit.Result.PrimaryArtistNames
			if strings.TrimSpace(artist) == "" {
				artist = hit.Result.ArtistNames
			}
			score := scoreLyricsSearchCandidate(hit.Result.Title, artist, 0, trackName, artistName, durationSec)
			if score > bestScore {
				bestScore = score
				bestURL = strings.TrimSpace(hit.Result.URL)
			}
		}
	}
	if bestURL == "" {
		return "", fmt.Errorf("no songs found on genius")
	}
	return bestURL, nil
}

func (c *GeniusLyricsClient) FetchLyrics(trackName, artistName string, durationSec float64) (*LyricsResponse, error) {
	geniusURL, err := c.searchSong(trackName, artistName, durationSec)
	if err != nil {
		return nil, err
	}
	params := url.Values{}
	params.Set("url", geniusURL)
	raw, err := fetchPaxsenixBody(c.httpClient, "https://lyrics.paxsenix.org/genius/lyrics", params)
	if err != nil {
		return nil, fmt.Errorf("genius lyrics fetch failed: %w", err)
	}
	return parsePaxsenixLyricsPayload(raw, "Genius", false)
}
