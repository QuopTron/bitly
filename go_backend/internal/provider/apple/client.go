package apple

import (
	"net/http"
	"time"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

const baseURL = "https://api.music.apple.com/v1"

// Client for Apple Music API.
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
func (c *Client) Name() string          { return "apple" }

type appleSong struct {
	ID         string `json:"id"`
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
	ID         string `json:"id"`
	Attributes struct {
		Name       string `json:"name"`
		ArtistName string `json:"artistName"`
		Artwork    struct {
			URL string `json:"url"`
		} `json:"artwork"`
		ReleaseDate string `json:"releaseDate"`
		TrackCount  int    `json:"trackCount"`
	} `json:"attributes"`
}

type appleArtist struct {
	ID         string `json:"id"`
	Attributes struct {
		Name    string `json:"name"`
		Artwork struct {
			URL string `json:"url"`
		} `json:"artwork"`
		GenreNames []string `json:"genreNames"`
	} `json:"attributes"`
}

type applePlaylist struct {
	ID         string `json:"id"`
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
