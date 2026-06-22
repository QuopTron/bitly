package cover

import "net/http"

type Strategy struct {
	client *http.Client
}

type CoverRequest struct {
	URL        string `json:"url"`
	TrackID    string `json:"track_id"`
	CacheDir   string `json:"cache_dir"`
	TrackName  string `json:"track_name,omitempty"`
	ArtistName string `json:"artist_name,omitempty"`
}

type CoverResult struct {
	FilePath string `json:"file_path"`
	Size     int64  `json:"size"`
	MimeType string `json:"mime_type"`
}

func NewStrategy(client *http.Client) *Strategy {
	if client == nil {
		client = &http.Client{}
	}
	return &Strategy{client: client}
}
