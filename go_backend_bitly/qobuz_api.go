package gobackend

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"
)

const (
	qobuzKennyyBase = "https://qobuz.kennyy.com.br/api"
	qobuzKennyyName = "qobuz_kennyy"

	qobuzSearchCacheTTL   = 5 * time.Minute
	qobuzAlbumCacheTTL    = 30 * time.Minute
	qobuzArtistCacheTTL   = 30 * time.Minute
	qobuzDownloadCacheTTL = 2 * time.Minute

	qobuzMaxCacheEntries = 500
)

type qobuzKennyyCacheEntry struct {
	data      interface{}
	expiresAt time.Time
}

type QobuzKennyyClient struct {
	httpClient    *http.Client
	cache         map[string]*qobuzKennyyCacheEntry
	mu            sync.RWMutex
	cleanupTicker *time.Ticker
	stopCleanup   chan struct{}
}

var (
	qobuzKennyyClient     *QobuzKennyyClient
	qobuzKennyyClientOnce sync.Once
)

func GetQobuzKennyyClient() *QobuzKennyyClient {
	qobuzKennyyClientOnce.Do(func() {
		qobuzKennyyClient = &QobuzKennyyClient{
			httpClient: &http.Client{
				Timeout: 15 * time.Second,
			},
			cache:       make(map[string]*qobuzKennyyCacheEntry),
			stopCleanup: make(chan struct{}),
		}
		qobuzKennyyClient.cleanupTicker = time.NewTicker(5 * time.Minute)
		go qobuzKennyyClient.cleanupLoop()
	})
	return qobuzKennyyClient
}

func (c *QobuzKennyyClient) cleanupLoop() {
	for {
		select {
		case <-c.cleanupTicker.C:
			c.mu.Lock()
			now := time.Now()
			for k, v := range c.cache {
				if now.After(v.expiresAt) {
					delete(c.cache, k)
				}
			}
			// Trim oldest entries if over max
			for len(c.cache) > qobuzMaxCacheEntries {
				var oldestKey string
				var oldestTime time.Time
				first := true
				for k, v := range c.cache {
					if first || v.expiresAt.Before(oldestTime) {
						oldestKey = k
						oldestTime = v.expiresAt
						first = false
					}
				}
				delete(c.cache, oldestKey)
			}
			c.mu.Unlock()
		case <-c.stopCleanup:
			return
		}
	}
}

func (c *QobuzKennyyClient) getFromCache(key string) interface{} {
	c.mu.RLock()
	defer c.mu.RUnlock()
	entry, ok := c.cache[key]
	if !ok || time.Now().After(entry.expiresAt) {
		return nil
	}
	return entry.data
}

func (c *QobuzKennyyClient) setCache(key string, data interface{}, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.cache[key] = &qobuzKennyyCacheEntry{
		data:      data,
		expiresAt: time.Now().Add(ttl),
	}
	for len(c.cache) > qobuzMaxCacheEntries {
		var oldestKey string
		var oldestTime time.Time
		first := true
		for k, v := range c.cache {
			if first || v.expiresAt.Before(oldestTime) {
				oldestKey = k
				oldestTime = v.expiresAt
				first = false
			}
		}
		delete(c.cache, oldestKey)
	}
}

func (c *QobuzKennyyClient) getJSON(endpoint string, params map[string]string) ([]byte, error) {
	u, err := url.Parse(qobuzKennyyBase + endpoint)
	if err != nil {
		return nil, fmt.Errorf("invalid URL: %w", err)
	}
	q := u.Query()
	for k, v := range params {
		q.Set(k, v)
	}
	u.RawQuery = q.Encode()

	req, err := http.NewRequest("GET", u.String(), nil)
	if err != nil {
		return nil, fmt.Errorf("request creation failed: %w", err)
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(body))
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read body failed: %w", err)
	}

	var apiResp struct {
		Success bool            `json:"success"`
		Data    json.RawMessage `json:"data"`
	}
	if err := json.Unmarshal(body, &apiResp); err != nil {
		return nil, fmt.Errorf("parse response failed: %w", err)
	}
	if !apiResp.Success {
		return nil, fmt.Errorf("API returned success=false")
	}
	return apiResp.Data, nil
}

type qobuzKennyyPerformer struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

type qobuzKennyyAlbumRef struct {
	ID      string `json:"id"`
	Title   string `json:"title"`
	QobuzID int    `json:"qobuz_id,omitempty"`
}

type qobuzKennyyTrackItem struct {
	ID              int                  `json:"id"`
	Title           string               `json:"title"`
	Duration        int                  `json:"duration"`
	TrackNumber     int                  `json:"track_number"`
	ISRC            string               `json:"isrc"`
	Performer       qobuzKennyyPerformer `json:"performer"`
	Album           qobuzKennyyAlbumRef  `json:"album"`
	MaximumBitDepth int                  `json:"maximum_bit_depth"`
	MaximumSampling float64              `json:"maximum_sampling_rate"`
}

type qobuzKennyyTrackList struct {
	Items []qobuzKennyyTrackItem `json:"items"`
	Total int                    `json:"total"`
}

type qobuzKennyySearchResult struct {
	Tracks qobuzKennyyTrackList `json:"tracks"`
}

func (c *QobuzKennyyClient) SearchTracks(query string, limit int) ([]ExtTrackMetadata, error) {
	cacheKey := "search:" + strings.ToLower(query) + fmt.Sprintf(":%d", limit)
	if cached := c.getFromCache(cacheKey); cached != nil {
		return cached.([]ExtTrackMetadata), nil
	}

	params := map[string]string{"q": query, "offset": "0"}
	if limit > 0 {
		params["limit"] = fmt.Sprintf("%d", limit)
	}

	data, err := c.getJSON("/get-music", params)
	if err != nil {
		return nil, fmt.Errorf("qobuz_kennyy search: %w", err)
	}

	var searchResult struct {
		Query  string               `json:"query"`
		Tracks qobuzKennyyTrackList `json:"tracks"`
	}
	if err := json.Unmarshal(data, &searchResult); err != nil {
		return nil, fmt.Errorf("qobuz_kennyy parse search: %w", err)
	}

	tracks := make([]ExtTrackMetadata, 0, len(searchResult.Tracks.Items))
	for _, item := range searchResult.Tracks.Items {
		tracks = append(tracks, ExtTrackMetadata{
			ID:          fmt.Sprintf("%d", item.ID),
			Name:        item.Title,
			Artists:     item.Performer.Name,
			AlbumName:   item.Album.Title,
			DurationMS:  item.Duration * 1000,
			TrackNumber: item.TrackNumber,
			ISRC:        item.ISRC,
			QobuzID:     fmt.Sprintf("%d", item.ID),
		})
	}

	c.setCache(cacheKey, tracks, qobuzSearchCacheTTL)
	return tracks, nil
}

type qobuzKennyyAlbumTrack struct {
	ID              int                  `json:"id"`
	Title           string               `json:"title"`
	TrackNumber     int                  `json:"track_number"`
	Duration        int                  `json:"duration"`
	ISRC            string               `json:"isrc"`
	Performer       qobuzKennyyPerformer `json:"performer"`
	MaximumBitDepth int                  `json:"maximum_bit_depth"`
	MaximumSampling float64              `json:"maximum_sampling_rate"`
}

type qobuzKennyyAlbumData struct {
	ID                  string                    `json:"id"`
	Title               string                    `json:"title"`
	Artist              qobuzKennyyArtistRef      `json:"artist"`
	Image               qobuzKennyyImages         `json:"image"`
	Tracks              qobuzKennyyAlbumTrackList `json:"tracks"`
	TracksCount         int                       `json:"tracks_count"`
	Duration            int                       `json:"duration"`
	ReleaseDateOriginal string                    `json:"release_date_original"`
	Label               qobuzKennyyLabelRef       `json:"label"`
	Copyright           string                    `json:"copyright"`
	Genre               qobuzKennyyGenreRef       `json:"genre"`
	Popularity          int                       `json:"popularity"`
	URL                 string                    `json:"url"`
	QobuzID             int                       `json:"qobuz_id"`
}

type qobuzKennyyArtistRef struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

type qobuzKennyyImages struct {
	Small     string `json:"small"`
	Large     string `json:"large"`
	Thumbnail string `json:"thumbnail"`
}

type qobuzKennyyAlbumTrackList struct {
	Items []qobuzKennyyAlbumTrack `json:"items"`
	Total int                     `json:"total"`
}

type qobuzKennyyLabelRef struct {
	Name string `json:"name"`
}

type qobuzKennyyGenreRef struct {
	Name string `json:"name"`
}

func (c *QobuzKennyyClient) GetAlbum(albumID string) (*ExtAlbumMetadata, error) {
	cacheKey := "album:" + albumID
	if cached := c.getFromCache(cacheKey); cached != nil {
		return cached.(*ExtAlbumMetadata), nil
	}

	data, err := c.getJSON("/get-album", map[string]string{"album_id": albumID})
	if err != nil {
		return nil, fmt.Errorf("qobuz_kennyy get album: %w", err)
	}

	var album qobuzKennyyAlbumData
	if err := json.Unmarshal(data, &album); err != nil {
		return nil, fmt.Errorf("qobuz_kennyy parse album: %w", err)
	}

	tracks := make([]ExtTrackMetadata, 0, len(album.Tracks.Items))
	for _, t := range album.Tracks.Items {
		artistName := t.Performer.Name
		if artistName == "" {
			artistName = album.Artist.Name
		}
		tracks = append(tracks, ExtTrackMetadata{
			ID:          fmt.Sprintf("%d", t.ID),
			Name:        t.Title,
			Artists:     artistName,
			AlbumName:   album.Title,
			TrackNumber: t.TrackNumber,
			DurationMS:  t.Duration * 1000,
			ISRC:        t.ISRC,
			QobuzID:     fmt.Sprintf("%d", t.ID),
		})
	}

	coverURL := album.Image.Large
	if coverURL == "" {
		coverURL = album.Image.Small
	}

	metadata := &ExtAlbumMetadata{
		ID:          album.ID,
		Name:        album.Title,
		Artists:     album.Artist.Name,
		ArtistID:    fmt.Sprintf("%d", album.Artist.ID),
		Tracks:      tracks,
		CoverURL:    coverURL,
		ReleaseDate: album.ReleaseDateOriginal,
		TotalTracks: album.TracksCount,
	}

	c.setCache(cacheKey, metadata, qobuzAlbumCacheTTL)
	return metadata, nil
}

type qobuzKennyyArtistData struct {
	ID          int    `json:"id"`
	Name        string `json:"name"`
	AlbumsCount int    `json:"albums_count"`
	Image       string `json:"image"`
	Picture     string `json:"picture"`
}

type qobuzKennyyArtistResponse struct {
	Artist qobuzKennyyArtistData `json:"artist"`
}

func (c *QobuzKennyyClient) GetArtist(artistID string) (*ExtArtistMetadata, error) {
	cacheKey := "artist:" + artistID
	if cached := c.getFromCache(cacheKey); cached != nil {
		return cached.(*ExtArtistMetadata), nil
	}

	data, err := c.getJSON("/get-artist", map[string]string{"artist_id": artistID})
	if err != nil {
		return nil, fmt.Errorf("qobuz_kennyy get artist: %w", err)
	}

	var resp qobuzKennyyArtistResponse
	if err := json.Unmarshal(data, &resp); err != nil {
		return nil, fmt.Errorf("qobuz_kennyy parse artist: %w", err)
	}

	imageURL := resp.Artist.Image
	if imageURL == "" {
		imageURL = resp.Artist.Picture
	}

	metadata := &ExtArtistMetadata{
		ID:       fmt.Sprintf("%d", resp.Artist.ID),
		Name:     resp.Artist.Name,
		ImageURL: imageURL,
	}

	c.setCache(cacheKey, metadata, qobuzArtistCacheTTL)
	return metadata, nil
}

type qobuzKennyyDownloadData struct {
	URL string `json:"url"`
}

type qobuzKennyyDownloadResponse struct {
	Success bool                    `json:"success"`
	Data    qobuzKennyyDownloadData `json:"data"`
}

// Quality mapping: 5=MP3_320, 6=FLAC_LOSSLESS(16/44.1), 7=HI_RES(24/96), 27=HI_RES_MAX(24/192)
func qobuzKennyyQualityToParam(quality string) string {
	switch strings.ToUpper(quality) {
	case "MP3_320", "320":
		return "5"
	case "LOSSLESS", "CD", "16":
		return "6"
	case "HI_RES", "24":
		return "7"
	default:
		return "27"
	}
}

func GetQobuzKennyyMetadata(resourceType, resourceID string) (string, error) {
	client := GetQobuzKennyyClient()

	switch resourceType {
	case "album":
		album, err := client.GetAlbum(resourceID)
		if err != nil {
			return "", err
		}
		jsonBytes, err := json.Marshal(album)
		if err != nil {
			return "", err
		}
		return string(jsonBytes), nil

	case "artist":
		artist, err := client.GetArtist(resourceID)
		if err != nil {
			return "", err
		}
		jsonBytes, err := json.Marshal(artist)
		if err != nil {
			return "", err
		}
		return string(jsonBytes), nil

	default:
		return "", fmt.Errorf("qobuz_kennyy: unsupported resource type: %s", resourceType)
	}
}

func (c *QobuzKennyyClient) SearchByISRC(isrc string) (string, error) {
	if isrc == "" {
		return "", fmt.Errorf("empty ISRC")
	}

	cacheKey := "isrc:" + isrc
	if cached := c.getFromCache(cacheKey); cached != nil {
		return cached.(string), nil
	}

	tracks, err := c.SearchTracks(isrc, 5)
	if err != nil {
		return "", fmt.Errorf("qobuz_kennyy search ISRC: %w", err)
	}

	for _, track := range tracks {
		if strings.EqualFold(track.ISRC, isrc) && track.QobuzID != "" {
			c.setCache(cacheKey, track.QobuzID, qobuzSearchCacheTTL)
			return track.QobuzID, nil
		}
	}
	for _, track := range tracks {
		if track.QobuzID != "" {
			c.setCache(cacheKey, track.QobuzID, qobuzSearchCacheTTL)
			return track.QobuzID, nil
		}
	}

	return "", fmt.Errorf("qobuz_kennyy: no Qobuz track found for ISRC %s", isrc)
}

func searchQobuzKennyyID(req *DownloadRequest) (string, error) {
	if req.QobuzID != "" {
		return req.QobuzID, nil
	}

	client := GetQobuzKennyyClient()

	if req.ISRC != "" {
		qobuzID, err := client.SearchByISRC(req.ISRC)
		if err == nil && qobuzID != "" {
			GoLog("[QobuzKennyy] Resolved ISRC %s to QobuzID %s\n", req.ISRC, qobuzID)
			return qobuzID, nil
		}
	}

	// Fallback: search by track name + artist when no ISRC or QobuzID
	if req.TrackName != "" && req.ArtistName != "" {
		query := req.TrackName + " " + req.ArtistName
		GoLog("[QobuzKennyy] No ISRC, searching by query: %q\n", query)
		tracks, err := client.SearchTracks(query, 5)
		if err == nil && len(tracks) > 0 {
			best := tracks[0]
			GoLog("[QobuzKennyy] Found track by name+artist: %s - %s (QobuzID=%s, ISRC=%s)\n",
				best.Name, best.Artists, best.QobuzID, best.ISRC)
			return best.QobuzID, nil
		}
		if err != nil {
			GoLog("[QobuzKennyy] Name+artist search failed: %v\n", err)
		}
	}

	return "", fmt.Errorf("qobuz_kennyy: no Qobuz ID available (ISRC=%q, QobuzID=%q, track=%q, artist=%q)", req.ISRC, req.QobuzID, req.TrackName, req.ArtistName)
}

func downloadViaQobuzKennyy(req *DownloadRequest) (*DownloadResponse, error) {
	qobuzID, err := searchQobuzKennyyID(req)
	if err != nil {
		return nil, err
	}

	client := GetQobuzKennyyClient()
	q := qobuzKennyyQualityToParam(req.Quality)
	downloadURL, err := client.GetDownloadURL(qobuzID, q)
	if err != nil {
		return nil, fmt.Errorf("qobuz_kennyy: %w", err)
	}

	outputPath := buildOutputPath(*req)
	if req.ItemID != "" {
		StartItemProgress(req.ItemID)
	}

	dlResp, err := client.httpClient.Get(downloadURL)
	if err != nil {
		if req.ItemID != "" {
			RemoveItemProgress(req.ItemID)
		}
		return nil, fmt.Errorf("qobuz_kennyy download request: %w", err)
	}
	defer dlResp.Body.Close()

	if dlResp.StatusCode != http.StatusOK {
		if req.ItemID != "" {
			RemoveItemProgress(req.ItemID)
		}
		return nil, fmt.Errorf("qobuz_kennyy: HTTP %d", dlResp.StatusCode)
	}

	outFile, err := os.Create(outputPath)
	if err != nil {
		if req.ItemID != "" {
			RemoveItemProgress(req.ItemID)
		}
		return nil, fmt.Errorf("qobuz_kennyy create file: %w", err)
	}

	if _, copyErr := io.Copy(outFile, dlResp.Body); copyErr != nil {
		outFile.Close()
		os.Remove(outputPath)
		if req.ItemID != "" {
			RemoveItemProgress(req.ItemID)
		}
		return nil, fmt.Errorf("qobuz_kennyy save file: %w", copyErr)
	}
	outFile.Close()

	if req.ItemID != "" {
		CompleteItemProgress(req.ItemID)
	}

	downloadResult := DownloadResult{
		FilePath: outputPath,
	}

	resp := buildDownloadSuccessResponse(
		*req,
		downloadResult,
		qobuzKennyyName,
		"Downloaded from "+qobuzKennyyName,
		outputPath,
		false,
	)
	return &resp, nil
}

func (c *QobuzKennyyClient) GetDownloadURL(trackID string, quality string) (string, error) {
	cacheKey := "dl:" + trackID + ":" + quality
	if cached := c.getFromCache(cacheKey); cached != nil {
		return cached.(string), nil
	}

	q := quality
	if q == "" {
		q = "27"
	}

	data, err := c.getJSON("/download-music", map[string]string{
		"track_id": trackID,
		"quality":  q,
	})
	if err != nil {
		return "", fmt.Errorf("qobuz_kennyy download: %w", err)
	}

	var dlData qobuzKennyyDownloadData
	if err := json.Unmarshal(data, &dlData); err != nil {
		return "", fmt.Errorf("qobuz_kennyy parse download: %w", err)
	}
	if dlData.URL == "" {
		return "", fmt.Errorf("qobuz_kennyy: no download URL returned")
	}

	c.setCache(cacheKey, dlData.URL, qobuzDownloadCacheTTL)
	return dlData.URL, nil
}
