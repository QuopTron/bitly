package apple

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

const baseURL = "https://api.music.apple.com/v1"

type Client struct {
	http       *http.Client
	token      string
	storefront string
}

func NewClient(httpClient *http.Client, token, storefront string) *Client {
	if httpClient == nil {
		cfg := httpclient.DefaultConfig()
		cfg.Timeout = 15 * time.Second
		httpClient = httpclient.NewClient(cfg)
	}
	if storefront == "" {
		storefront = "us"
	}
	return &Client{http: httpClient, token: token, storefront: storefront}
}

func (c *Client) SetToken(token string) { c.token = token }
func (c *Client) Name() string { return "apple" }

type appleSong struct {
	ID   string `json:"id"`
	Attributes struct {
		Name         string `json:"name"`
		ArtistName   string `json:"artistName"`
		AlbumName    string `json:"albumName"`
		DurationInMs int    `json:"durationInMillis"`
		ISRC         string `json:"isrc"`
		Artwork      struct {
			URL string `json:"url"`
		} `json:"artwork"`
	} `json:"attributes"`
}

type appleAlbum struct {
	ID   string `json:"id"`
	Attributes struct {
		Name         string `json:"name"`
		ArtistName   string `json:"artistName"`
		Artwork      struct {
			URL string `json:"url"`
		} `json:"artwork"`
		ReleaseDate string `json:"releaseDate"`
		TrackCount  int    `json:"trackCount"`
	} `json:"attributes"`
}

type appleArtist struct {
	ID   string `json:"id"`
	Attributes struct {
		Name    string `json:"name"`
		Artwork struct {
			URL string `json:"url"`
		} `json:"artwork"`
		GenreNames []string `json:"genreNames"`
	} `json:"attributes"`
}

type applePlaylist struct {
	ID   string `json:"id"`
	Attributes struct {
		Name        string `json:"name"`
		Description string `json:"description"`
		CuratorName string `json:"curatorName"`
		TrackCount  int    `json:"trackCount"`
		Artwork     struct {
			URL string `json:"url"`
		} `json:"artwork"`
	} `json:"attributes"`
}

func (c *Client) SearchTracks(query string, limit int) ([]provider.TrackResult, error) {
	if c.token == "" {
		return nil, fmt.Errorf("apple: no developer token set")
	}
	if limit < 1 || limit > 100 {
		limit = 25
	}
	type searchResp struct {
		Results struct {
			Songs struct {
				Data []appleSong `json:"data"`
			} `json:"songs"`
		} `json:"results"`
	}
	var resp searchResp
	if err := c.doGet("/catalog/"+c.storefront+"/search", map[string]string{
		"term": query, "types": "songs", "limit": fmt.Sprintf("%d", limit),
	}, &resp); err != nil {
		return nil, err
	}
	tracks := make([]provider.TrackResult, 0, len(resp.Results.Songs.Data))
	for _, s := range resp.Results.Songs.Data {
		artworkURL := s.Attributes.Artwork.URL
		if artworkURL != "" {
			artworkURL = strings.Replace(artworkURL, "{w}x{h}", "300x300", 1)
		}
		tracks = append(tracks, provider.TrackResult{
			ID:       "apple:" + s.ID,
			Title:    s.Attributes.Name,
			Artist:   s.Attributes.ArtistName,
			Album:    s.Attributes.AlbumName,
			Duration: s.Attributes.DurationInMs,
			ISRC:     s.Attributes.ISRC,
			CoverURL: artworkURL,
			Provider: "apple",
		})
	}
	return tracks, nil
}

func (c *Client) doGet(path string, params map[string]string, result interface{}) error {
	u, _ := url.Parse(baseURL + path)
	q := u.Query()
	for k, v := range params {
		q.Set(k, v)
	}
	u.RawQuery = q.Encode()
	req, _ := http.NewRequest("GET", u.String(), nil)
	req.Header.Set("Authorization", "Bearer "+c.token)
	req.Header.Set("User-Agent", httpclient.RandomUserAgent())
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("apple: HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}

	return json.NewDecoder(resp.Body).Decode(result)
}
