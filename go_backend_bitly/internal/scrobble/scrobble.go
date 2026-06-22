// Package scrobble implements audio scrobbling for Last.fm and ListenBrainz.
//
// The package stores configuration in the application_state table via the
// database package and sends HTTP requests to the respective scrobbling APIs.
package scrobble

import (
	"bytes"
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

// Config holds the scrobbling configuration.
type Config struct {
	LastFM      *LastFMConfig       `json:"lastfm,omitempty"`
	ListenBrainz *ListenBrainzConfig `json:"listenbrainz,omitempty"`
}

// LastFMConfig holds Last.fm credentials and preferences.
type LastFMConfig struct {
	Enabled    bool   `json:"enabled"`
	APIKey     string `json:"api_key,omitempty"`
	APISecret  string `json:"api_secret,omitempty"`
	SessionKey string `json:"session_key,omitempty"`
	Username   string `json:"username,omitempty"`
}

// ListenBrainzConfig holds ListenBrainz credentials and preferences.
type ListenBrainzConfig struct {
	Enabled   bool   `json:"enabled"`
	UserToken string `json:"user_token,omitempty"`
}

// TrackInfo is the track information sent in scrobbling requests.
type TrackInfo struct {
	Artist      string `json:"artist,omitempty"`
	Track       string `json:"track,omitempty"`
	Album       string `json:"album,omitempty"`
	AlbumArtist string `json:"albumArtist,omitempty"`
	Duration    int    `json:"duration,omitempty"` // seconds
	TrackNumber int    `json:"trackNumber,omitempty"`
	MBID        string `json:"mbid,omitempty"`
}

// trackMetadata is the track metadata map used for ListenBrainz API calls.
type trackMetadata struct {
	ArtistName     string `json:"artist_name"`
	TrackName      string `json:"track_name"`
	ReleaseName    string `json:"release_name,omitempty"`
	AdditionalInfo struct {
		DurationMs    int    `json:"duration_ms,omitempty"`
		TrackNumber   int    `json:"tracknumber,omitempty"`
		MusicBrainzID string `json:"musicbrainz_id,omitempty"`
	} `json:"additional_info,omitempty"`
}

// listenBrainzListen is a single listen in the ListenBrainz submit-listens payload.
type listenBrainzListen struct {
	ListenedAt    *int64        `json:"listened_at,omitempty"`
	TrackMetadata trackMetadata `json:"track_metadata"`
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const (
	lastfmAPIBase       = "https://ws.audioscrobbler.com/2.0"
	listenBrainzAPIBase = "https://api.listenbrainz.org/1"

	configDBKey = "scrobbling_config"

	httpTimeout = 10 * time.Second
)

// ---------------------------------------------------------------------------
// Global state
// ---------------------------------------------------------------------------

var (
	configCache     *Config
	configCacheMu   sync.RWMutex
	configCacheTime time.Time
	configCacheTTL  = 30 * time.Second

	httpClient = &http.Client{Timeout: httpTimeout}
)

// ---------------------------------------------------------------------------
// Config persistence
// ---------------------------------------------------------------------------

// saveConfig persists the scrobbling config to the database and updates the
// in-memory cache.
func saveConfig(cfg *Config) error {
	b, err := json.Marshal(cfg)
	if err != nil {
		return fmt.Errorf("scrobble: marshal config: %w", err)
	}

	db, err := database.Get()
	if err != nil {
		return fmt.Errorf("scrobble: get database: %w", err)
	}

	_, err = db.Exec(
		`INSERT INTO application_state (key, value, updated_at)
		 VALUES (?, ?, datetime('now'))
		 ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at`,
		configDBKey, string(b),
	)
	if err != nil {
		return fmt.Errorf("scrobble: persist config: %w", err)
	}

	configCacheMu.Lock()
	configCache = cfg
	configCacheTime = time.Now()
	configCacheMu.Unlock()
	return nil
}

// loadConfig loads the scrobbling config from the database.  Returns a default
// (empty) config if nothing is stored.
func loadConfig() (*Config, error) {
	configCacheMu.RLock()
	if configCache != nil && time.Since(configCacheTime) < configCacheTTL {
		defer configCacheMu.RUnlock()
		return configCache, nil
	}
	configCacheMu.RUnlock()

	db, err := database.Get()
	if err != nil {
		return &Config{}, nil // return empty config on DB error
	}

	var raw string
	err = db.QueryRow("SELECT value FROM application_state WHERE key = ?", configDBKey).Scan(&raw)
	if err != nil {
		return &Config{}, nil // not stored yet → empty config
	}

	var cfg Config
	if err := json.Unmarshal([]byte(raw), &cfg); err != nil {
		return &Config{}, nil // corrupt entry → reset to empty
	}

	configCacheMu.Lock()
	configCache = &cfg
	configCacheTime = time.Now()
	configCacheMu.Unlock()
	return &cfg, nil
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

// SetupConfig saves a new scrobbling configuration.
func SetupConfig(cfgJSON string) error {
	var cfg Config
	if err := json.Unmarshal([]byte(cfgJSON), &cfg); err != nil {
		return fmt.Errorf("scrobble: invalid config JSON: %w", err)
	}
	return saveConfig(&cfg)
}

// GetConfig returns the current scrobbling configuration as a JSON string.
func GetConfig() (string, error) {
	cfg, err := loadConfig()
	if err != nil {
		return "{}", nil
	}
	b, err := json.Marshal(cfg)
	if err != nil {
		return "{}", nil
	}
	return string(b), nil
}

// NowPlaying sends a "now playing" notification to all enabled services.
func NowPlaying(trackJSON string) error {
	var track TrackInfo
	if err := json.Unmarshal([]byte(trackJSON), &track); err != nil {
		return fmt.Errorf("scrobble: invalid track JSON: %w", err)
	}

	cfg, err := loadConfig()
	if err != nil {
		return err
	}

	var errs []string

	if cfg.LastFM != nil && cfg.LastFM.Enabled {
		if err := lastfmNowPlaying(cfg.LastFM, &track); err != nil {
			errs = append(errs, fmt.Sprintf("last.fm: %v", err))
		}
	}

	if cfg.ListenBrainz != nil && cfg.ListenBrainz.Enabled {
		if err := listenBrainzNowPlaying(cfg.ListenBrainz, &track); err != nil {
			errs = append(errs, fmt.Sprintf("listenbrainz: %v", err))
		}
	}

	if len(errs) > 0 {
		return fmt.Errorf("scrobble nowplaying: %s", strings.Join(errs, "; "))
	}
	return nil
}

// Scrobble sends a final scrobble (track completed) to all enabled services.
func Scrobble(trackJSON string) error {
	var track TrackInfo
	if err := json.Unmarshal([]byte(trackJSON), &track); err != nil {
		return fmt.Errorf("scrobble: invalid track JSON: %w", err)
	}

	cfg, err := loadConfig()
	if err != nil {
		return err
	}

	var errs []string

	if cfg.LastFM != nil && cfg.LastFM.Enabled {
		if err := lastfmScrobble(cfg.LastFM, &track); err != nil {
			errs = append(errs, fmt.Sprintf("last.fm: %v", err))
		}
	}

	if cfg.ListenBrainz != nil && cfg.ListenBrainz.Enabled {
		if err := listenBrainzScrobble(cfg.ListenBrainz, &track); err != nil {
			errs = append(errs, fmt.Sprintf("listenbrainz: %v", err))
		}
	}

	if len(errs) > 0 {
		return fmt.Errorf("scrobble: %s", strings.Join(errs, "; "))
	}
	return nil
}

// ---------------------------------------------------------------------------
// Last.fm API
// ---------------------------------------------------------------------------

func lastfmNowPlaying(cfg *LastFMConfig, track *TrackInfo) error {
	params := url.Values{}
	params.Set("method", "track.updateNowPlaying")
	params.Set("artist", track.Artist)
	params.Set("track", track.Track)
	params.Set("api_key", cfg.APIKey)
	params.Set("sk", cfg.SessionKey)
	if track.Album != "" {
		params.Set("album", track.Album)
	}
	if track.Duration > 0 {
		params.Set("duration", fmt.Sprintf("%d", track.Duration))
	}
	if track.TrackNumber > 0 {
		params.Set("trackNumber", fmt.Sprintf("%d", track.TrackNumber))
	}
	if track.MBID != "" {
		params.Set("mbid", track.MBID)
	}

	return lastfmPost(cfg, params)
}

func lastfmScrobble(cfg *LastFMConfig, track *TrackInfo) error {
	params := url.Values{}
	params.Set("method", "track.scrobble")
	params.Set("artist", track.Artist)
	params.Set("track", track.Track)
	params.Set("api_key", cfg.APIKey)
	params.Set("sk", cfg.SessionKey)
	params.Set("timestamp", fmt.Sprintf("%d", time.Now().Unix()))
	if track.Album != "" {
		params.Set("album", track.Album)
	}
	if track.Duration > 0 {
		params.Set("duration", fmt.Sprintf("%d", track.Duration))
	}
	if track.TrackNumber > 0 {
		params.Set("trackNumber", fmt.Sprintf("%d", track.TrackNumber))
	}
	if track.MBID != "" {
		params.Set("mbid", track.MBID)
	}

	return lastfmPost(cfg, params)
}

func lastfmPost(cfg *LastFMConfig, params url.Values) error {
	// Add api_sig — required by Last.fm for authenticated write operations.
	// The signature is an MD5 of sorted param key-value pairs + api_secret.
	params.Set("format", "json")

	sig := lastfmSignature(params, cfg.APISecret)
	params.Set("api_sig", sig)

	req, err := http.NewRequest("POST", lastfmAPIBase, bytes.NewBufferString(params.Encode()))
	if err != nil {
		return fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("http post: %w", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("last.fm API returned status %d: %s", resp.StatusCode, string(body))
	}

	// Check for API error response
	var apiErr struct {
		Error   int    `json:"error"`
		Message string `json:"message"`
	}
	if err := json.Unmarshal(body, &apiErr); err == nil && apiErr.Error != 0 {
		return fmt.Errorf("last.fm API error %d: %s", apiErr.Error, apiErr.Message)
	}

	return nil
}

// lastfmSignature computes the api_sig for a Last.fm API request.
//
// The signature is an MD5 hex digest of the concatenation:
//
//	key1value1key2value2...secret
//
// where keys are sorted alphabetically and the "format" and "api_sig"
// parameters are excluded.
func lastfmSignature(params url.Values, secret string) string {
	keys := make([]string, 0, len(params))
	for k := range params {
		if k == "format" || k == "api_sig" {
			continue
		}
		keys = append(keys, k)
	}
	sort.Strings(keys)

	var b strings.Builder
	for _, k := range keys {
		b.WriteString(k)
		b.WriteString(params.Get(k))
	}
	b.WriteString(secret)

	hash := md5.Sum([]byte(b.String()))
	return hex.EncodeToString(hash[:])
}

// ---------------------------------------------------------------------------
// ListenBrainz API
// ---------------------------------------------------------------------------

func buildTrackMeta(track *TrackInfo) trackMetadata {
	meta := trackMetadata{
		ArtistName: track.Artist,
		TrackName:  track.Track,
	}
	if track.Album != "" {
		meta.ReleaseName = track.Album
	}
	if track.Duration > 0 {
		meta.AdditionalInfo.DurationMs = track.Duration * 1000
	}
	if track.TrackNumber > 0 {
		meta.AdditionalInfo.TrackNumber = track.TrackNumber
	}
	if track.MBID != "" {
		meta.AdditionalInfo.MusicBrainzID = track.MBID
	}
	return meta
}

func listenBrainzNowPlaying(cfg *ListenBrainzConfig, track *TrackInfo) error {
	listen := listenBrainzListen{
		TrackMetadata: buildTrackMeta(track),
	}
	// "playing-now" type omits listened_at entirely.

	return listenBrainzPost(cfg, "playing-now", listen)
}

func listenBrainzScrobble(cfg *ListenBrainzConfig, track *TrackInfo) error {
	now := time.Now().Unix()
	listen := listenBrainzListen{
		ListenedAt:    &now,
		TrackMetadata: buildTrackMeta(track),
	}

	return listenBrainzPost(cfg, "single", listen)
}

func listenBrainzPost(cfg *ListenBrainzConfig, listenType string, listen listenBrainzListen) error {
	payload := map[string]interface{}{
		"listen_type": listenType,
		"payload":     []listenBrainzListen{listen},
	}

	b, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal payload: %w", err)
	}

	u := fmt.Sprintf("%s/submit-listens", listenBrainzAPIBase)
	req, err := http.NewRequest("POST", u, bytes.NewReader(b))
	if err != nil {
		return fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Token "+cfg.UserToken)

	resp, err := httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("http post: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("listenbrainz API returned status %d: %s", resp.StatusCode, string(respBody))
	}

	return nil
}
