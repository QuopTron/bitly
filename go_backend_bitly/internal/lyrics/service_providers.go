package lyrics

import (
	"net/http"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/http"
)

type LyricsLine struct {
	StartTimeMs int64  `json:"startTimeMs"`
	Words       string `json:"words"`
	EndTimeMs   int64  `json:"endTimeMs"`
}

type LyricsResponse struct {
	Lines        []LyricsLine `json:"lines"`
	SyncType     string       `json:"syncType"`
	Instrumental bool         `json:"instrumental"`
	PlainLyrics  string       `json:"plainLyrics"`
	Provider     string       `json:"provider"`
	Source       string       `json:"source"`
}

type LRCLibResponse struct {
	ID           int     `json:"id"`
	Name         string  `json:"name"`
	TrackName    string  `json:"trackName"`
	ArtistName   string  `json:"artistName"`
	AlbumName    string  `json:"albumName"`
	Duration     float64 `json:"duration"`
	Instrumental bool    `json:"instrumental"`
	PlainLyrics  string  `json:"plainLyrics"`
	SyncedLyrics string  `json:"syncedLyrics"`
}

type LyricsFetchOptions struct {
	IncludeTranslationNetease  bool   `json:"include_translation_netease"`
	IncludeRomanizationNetease bool   `json:"include_romanization_netease"`
	MultiPersonWordByWord      bool   `json:"multi_person_word_by_word"`
	AppleElrcWordSync          bool   `json:"apple_elrc_word_sync"`
	MusixmatchLanguage         string `json:"musixmatch_language,omitempty"`
}

type LyricsClient struct {
	httpClient *http.Client
}

func NewLyricsClient() *LyricsClient {
	return &LyricsClient{
		httpClient: httpclient.NewMetadataClient(15 * time.Second),
	}
}
