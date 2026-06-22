package audio

import (
	"net/http"
	"time"
)

const DefaultUserAgent = "Bitly/1.0"

type Strategy struct {
	client    *http.Client
	retries   int
	userAgent string
}

type AudioRequest struct {
	URL          string `json:"url"`
	TrackID      string `json:"track_id"`
	FilePath     string `json:"file_path"`
	Format       string `json:"format"`
	ExpectedSize int64  `json:"expected_size,omitempty"`
}

type AudioResult struct {
	FilePath     string `json:"file_path"`
	Size         int64  `json:"size"`
	Format       string `json:"format"`
	BytesWritten int64  `json:"bytes_written"`
}

func NewStrategy(client *http.Client, retries int) *Strategy {
	ua := DefaultUserAgent
	if client == nil {
		client = &http.Client{Timeout: 5 * time.Minute}
	}
	return &Strategy{client: client, retries: retries, userAgent: ua}
}
