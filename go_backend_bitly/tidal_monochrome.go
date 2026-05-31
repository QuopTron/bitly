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
	tidalMonochromeName = "tidal_monochrome"
	tidalMetadataTTL    = 10 * time.Minute
)

type tidalMonochromeServer struct {
	URL     string `json:"url"`
	Version string `json:"version"`
}

type tidalUptimeResponse struct {
	LastUpdated string                  `json:"lastUpdated"`
	API         []tidalMonochromeServer `json:"api"`
	Down        []struct {
		URL   string `json:"url"`
		Error string `json:"error"`
	} `json:"down"`
}

type TidalMonochromeClient struct {
	httpClient *http.Client
	cache      map[string]*tidalCacheEntry
	mu         sync.RWMutex
	baseURLs   []string
}

type tidalCacheEntry struct {
	data      interface{}
	expiresAt time.Time
}

var (
	tidalMonochromeClient     *TidalMonochromeClient
	tidalMonochromeClientOnce sync.Once
)

func GetTidalMonochromeClient() *TidalMonochromeClient {
	tidalMonochromeClientOnce.Do(func() {
		client := &TidalMonochromeClient{
			httpClient: &http.Client{
				Timeout: 15 * time.Second,
			},
			cache: make(map[string]*tidalCacheEntry),
		}
		client.refreshServers()
		go client.periodicRefresh()
		tidalMonochromeClient = client
	})
	return tidalMonochromeClient
}

func (c *TidalMonochromeClient) periodicRefresh() {
	ticker := time.NewTicker(10 * time.Minute)
	for range ticker.C {
		c.refreshServers()
	}
}

func (c *TidalMonochromeClient) refreshServers() {
	uptimeURLs := []string{
		"https://tidal-uptime.jiffy-puffs-1j.workers.dev",
		"https://tidal-uptime.props-76styles.workers.dev",
	}

	seen := map[string]struct{}{}
	var servers []tidalMonochromeServer

	for _, uptimeURL := range uptimeURLs {
		resp, err := c.httpClient.Get(uptimeURL)
		if err != nil {
			continue
		}
		body, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			continue
		}

		var uptime tidalUptimeResponse
		if err := json.Unmarshal(body, &uptime); err != nil {
			continue
		}
		for _, api := range uptime.API {
			normalized := strings.TrimRight(api.URL, "/")
			if _, exists := seen[normalized]; !exists {
				seen[normalized] = struct{}{}
				servers = append(servers, api)
			}
		}
	}

	if len(servers) == 0 {
		servers = []tidalMonochromeServer{
			{URL: "https://eu-central.monochrome.tf", Version: "2.10"},
			{URL: "https://us-west.monochrome.tf", Version: "2.10"},
			{URL: "https://api.monochrome.tf", Version: "2.5"},
		}
	}

	c.mu.Lock()
	c.baseURLs = make([]string, len(servers))
	for i, s := range servers {
		c.baseURLs[i] = strings.TrimRight(s.URL, "/")
	}
	c.mu.Unlock()
}

func (c *TidalMonochromeClient) getBaseURLs() []string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	result := make([]string, len(c.baseURLs))
	copy(result, c.baseURLs)
	return result
}

func (c *TidalMonochromeClient) getFromCache(key string) interface{} {
	c.mu.RLock()
	defer c.mu.RUnlock()
	entry, ok := c.cache[key]
	if !ok || time.Now().After(entry.expiresAt) {
		return nil
	}
	return entry.data
}

func (c *TidalMonochromeClient) setCache(key string, data interface{}, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.cache[key] = &tidalCacheEntry{
		data:      data,
		expiresAt: time.Now().Add(ttl),
	}
}

type tidalMonochromeTrackItem struct {
	ID           int    `json:"id"`
	Title        string `json:"title"`
	Duration     int    `json:"duration"`
	ISRC         string `json:"isrc"`
	AudioQuality string `json:"audioQuality"`
	URL          string `json:"url"`
	Artist       struct {
		ID   int    `json:"id"`
		Name string `json:"name"`
	} `json:"artist"`
	Album struct {
		ID    int    `json:"id"`
		Title string `json:"title"`
		Cover string `json:"cover"`
	} `json:"album"`
	TrackNumber int `json:"trackNumber"`
}

type tidalMonochromeSearchData struct {
	Limit              int                        `json:"limit"`
	Offset             int                        `json:"offset"`
	TotalNumberOfItems int                        `json:"totalNumberOfItems"`
	Items              []tidalMonochromeTrackItem `json:"items"`
}

type tidalMonochromeSearchResponse struct {
	Version string                    `json:"version"`
	Data    tidalMonochromeSearchData `json:"data"`
}

func (c *TidalMonochromeClient) SearchByISRC(isrc string) (*ExtTrackMetadata, error) {
	cacheKey := "isrc:" + isrc
	if cached := c.getFromCache(cacheKey); cached != nil {
		return cached.(*ExtTrackMetadata), nil
	}

	baseURLs := c.getBaseURLs()
	for _, baseURL := range baseURLs {
		u := fmt.Sprintf("%s/search/?i=%s", baseURL, url.QueryEscape(isrc))
		resp, err := c.httpClient.Get(u)
		if err != nil {
			continue
		}
		body, readErr := io.ReadAll(resp.Body)
		resp.Body.Close()
		if readErr != nil || resp.StatusCode != http.StatusOK {
			continue
		}

		var searchResp tidalMonochromeSearchResponse
		if err := json.Unmarshal(body, &searchResp); err != nil {
			continue
		}
		if searchResp.Data.TotalNumberOfItems == 0 || len(searchResp.Data.Items) == 0 {
			continue
		}

		item := searchResp.Data.Items[0]
		metadata := &ExtTrackMetadata{
			ID:         fmt.Sprintf("%d", item.ID),
			Name:       item.Title,
			Artists:    item.Artist.Name,
			AlbumName:  item.Album.Title,
			DurationMS: item.Duration * 1000,
			ISRC:       item.ISRC,
			TidalID:    fmt.Sprintf("%d", item.ID),
		}

		c.setCache(cacheKey, metadata, tidalMetadataTTL)
		return metadata, nil
	}

	return nil, fmt.Errorf("tidal_monochrome: ISRC %s not found on any server", isrc)
}

type tidalMonochromeTrackInfoData struct {
	ID           int    `json:"id"`
	Title        string `json:"title"`
	Duration     int    `json:"duration"`
	ISRC         string `json:"isrc"`
	TrackNumber  int    `json:"trackNumber"`
	Copyright    string `json:"copyright"`
	URL          string `json:"url"`
	AudioQuality string `json:"audioQuality"`
	Artist       struct {
		ID   int    `json:"id"`
		Name string `json:"name"`
	} `json:"artist"`
	Album struct {
		ID    int    `json:"id"`
		Title string `json:"title"`
		Cover string `json:"cover"`
	} `json:"album"`
}

type tidalMonochromeInfoResponse struct {
	Version string                       `json:"version"`
	Data    tidalMonochromeTrackInfoData `json:"data"`
}

func (c *TidalMonochromeClient) GetTrackInfo(trackID string) (*ExtTrackMetadata, error) {
	cacheKey := "track:" + trackID
	if cached := c.getFromCache(cacheKey); cached != nil {
		return cached.(*ExtTrackMetadata), nil
	}

	baseURLs := c.getBaseURLs()
	for _, baseURL := range baseURLs {
		u := fmt.Sprintf("%s/info/?id=%s", baseURL, url.QueryEscape(trackID))
		resp, err := c.httpClient.Get(u)
		if err != nil {
			continue
		}
		body, readErr := io.ReadAll(resp.Body)
		resp.Body.Close()
		if readErr != nil || resp.StatusCode != http.StatusOK {
			continue
		}

		var infoResp tidalMonochromeInfoResponse
		if err := json.Unmarshal(body, &infoResp); err != nil {
			continue
		}

		data := infoResp.Data
		metadata := &ExtTrackMetadata{
			ID:         fmt.Sprintf("%d", data.ID),
			Name:       data.Title,
			Artists:    data.Artist.Name,
			AlbumName:  data.Album.Title,
			DurationMS: data.Duration * 1000,
			ISRC:       data.ISRC,
			TidalID:    fmt.Sprintf("%d", data.ID),
		}

		c.setCache(cacheKey, metadata, tidalMetadataTTL)
		return metadata, nil
	}

	return nil, fmt.Errorf("tidal_monochrome: track %s not found", trackID)
}

type tidalMonochromeAlbumData struct {
	ID             int    `json:"id"`
	Title          string `json:"title"`
	Cover          string `json:"cover"`
	ReleaseDate    string `json:"releaseDate"`
	NumberOfTracks int    `json:"numberOfTracks"`
	Duration       int    `json:"duration"`
	Artist         struct {
		ID   int    `json:"id"`
		Name string `json:"name"`
	} `json:"artist"`
	Items []struct {
		Item struct {
			ID          int    `json:"id"`
			Title       string `json:"title"`
			Duration    int    `json:"duration"`
			ISRC        string `json:"isrc"`
			TrackNumber int    `json:"trackNumber"`
		} `json:"item"`
	} `json:"items"`
}

type tidalMonochromeAlbumResponse struct {
	Version string                   `json:"version"`
	Data    tidalMonochromeAlbumData `json:"data"`
}

func (c *TidalMonochromeClient) GetAlbum(albumID string) (*ExtAlbumMetadata, error) {
	cacheKey := "album:" + albumID
	if cached := c.getFromCache(cacheKey); cached != nil {
		return cached.(*ExtAlbumMetadata), nil
	}

	baseURLs := c.getBaseURLs()
	for _, baseURL := range baseURLs {
		u := fmt.Sprintf("%s/album/?id=%s", baseURL, url.QueryEscape(albumID))
		resp, err := c.httpClient.Get(u)
		if err != nil {
			continue
		}
		body, readErr := io.ReadAll(resp.Body)
		resp.Body.Close()
		if readErr != nil || resp.StatusCode != http.StatusOK {
			continue
		}

		var albumResp tidalMonochromeAlbumResponse
		if err := json.Unmarshal(body, &albumResp); err != nil {
			continue
		}

		data := albumResp.Data
		tracks := make([]ExtTrackMetadata, 0, len(data.Items))
		for _, item := range data.Items {
			tracks = append(tracks, ExtTrackMetadata{
				ID:          fmt.Sprintf("%d", item.Item.ID),
				Name:        item.Item.Title,
				Artists:     data.Artist.Name,
				AlbumName:   data.Title,
				DurationMS:  item.Item.Duration * 1000,
				ISRC:        item.Item.ISRC,
				TrackNumber: item.Item.TrackNumber,
				TidalID:     fmt.Sprintf("%d", item.Item.ID),
			})
		}

		coverURL := ""
		if data.Cover != "" {
			coverURL = fmt.Sprintf("https://resources.tidal.com/images/%s/640x640.jpg", data.Cover)
		}

		metadata := &ExtAlbumMetadata{
			ID:          fmt.Sprintf("%d", data.ID),
			Name:        data.Title,
			Artists:     data.Artist.Name,
			Tracks:      tracks,
			CoverURL:    coverURL,
			ReleaseDate: data.ReleaseDate,
			TotalTracks: data.NumberOfTracks,
		}

		c.setCache(cacheKey, metadata, tidalMetadataTTL)
		return metadata, nil
	}

	return nil, fmt.Errorf("tidal_monochrome: album %s not found", albumID)
}

func GetTidalMonochromeMetadata(resourceType, resourceID string) (string, error) {
	client := GetTidalMonochromeClient()

	switch resourceType {
	case "track":
		track, err := client.GetTrackInfo(resourceID)
		if err != nil {
			return "", err
		}
		jsonBytes, err := json.Marshal(track)
		if err != nil {
			return "", err
		}
		return string(jsonBytes), nil

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

	case "isrc":
		track, err := client.SearchByISRC(resourceID)
		if err != nil {
			return "", err
		}
		jsonBytes, err := json.Marshal(track)
		if err != nil {
			return "", err
		}
		return string(jsonBytes), nil

	default:
		return "", fmt.Errorf("tidal_monochrome: unsupported resource type: %s", resourceType)
	}
}

// searchTidalMonochromeID resolves a Tidal track ID from ISRC or track name+artist.
func searchTidalMonochromeID(req *DownloadRequest) (string, error) {
	if req.TidalID != "" {
		return req.TidalID, nil
	}

	client := GetTidalMonochromeClient()

	if req.ISRC != "" {
		track, err := client.SearchByISRC(req.ISRC)
		if err == nil && track != nil && track.TidalID != "" {
			GoLog("[TidalMonochrome] Resolved ISRC %s to TidalID %s\n", req.ISRC, track.TidalID)
			return track.TidalID, nil
		}
	}

	if req.TrackName != "" && req.ArtistName != "" {
		query := req.TrackName + " " + req.ArtistName
		GoLog("[TidalMonochrome] No TidalID, searching by query: %q\n", query)

		track, err := client.SearchText(query)
		if err == nil && track != nil && track.TidalID != "" {
			GoLog("[TidalMonochrome] Found track by name+artist: %s - %s (TidalID=%s, ISRC=%s)\n",
				track.Name, track.Artists, track.TidalID, track.ISRC)
			return track.TidalID, nil
		}
		if err != nil {
			GoLog("[TidalMonochrome] Name+artist search failed: %v\n", err)
		}
	}

	return "", fmt.Errorf("tidal_monochrome: no Tidal ID available (ISRC=%q, TidalID=%q, track=%q, artist=%q)", req.ISRC, req.TidalID, req.TrackName, req.ArtistName)
}

type tidalMonochromeStreamData struct {
	URL          string `json:"url"`
	Codec        string `json:"codec"`
	AudioQuality string `json:"audioQuality"`
}

type tidalMonochromeStreamResponse struct {
	Version string                    `json:"version"`
	Data    tidalMonochromeStreamData `json:"data"`
}

func (c *TidalMonochromeClient) GetTrackStreamURL(trackID string) (string, error) {
	baseURLs := c.getBaseURLs()
	for _, baseURL := range baseURLs {
		u := fmt.Sprintf("%s/track/%s", baseURL, url.PathEscape(trackID))
		resp, err := c.httpClient.Get(u)
		if err != nil {
			continue
		}
		body, readErr := io.ReadAll(resp.Body)
		resp.Body.Close()
		if readErr != nil || resp.StatusCode != http.StatusOK {
			continue
		}

		var streamResp tidalMonochromeStreamResponse
		if err := json.Unmarshal(body, &streamResp); err != nil {
			continue
		}
		if streamResp.Data.URL != "" {
			GoLog("[TidalMonochrome] Got stream URL for track %s (codec=%s, quality=%s)\n",
				trackID, streamResp.Data.Codec, streamResp.Data.AudioQuality)
			return streamResp.Data.URL, nil
		}
	}
	return "", fmt.Errorf("tidal_monochrome: no stream URL for track %s", trackID)
}

func (c *TidalMonochromeClient) SearchText(query string) (*ExtTrackMetadata, error) {
	cacheKey := "search:" + query
	if cached := c.getFromCache(cacheKey); cached != nil {
		return cached.(*ExtTrackMetadata), nil
	}

	baseURLs := c.getBaseURLs()
	for _, baseURL := range baseURLs {
		u := fmt.Sprintf("%s/search/?q=%s", baseURL, url.QueryEscape(query))
		resp, err := c.httpClient.Get(u)
		if err != nil {
			continue
		}
		body, readErr := io.ReadAll(resp.Body)
		resp.Body.Close()
		if readErr != nil || resp.StatusCode != http.StatusOK {
			continue
		}

		var searchResp tidalMonochromeSearchResponse
		if err := json.Unmarshal(body, &searchResp); err != nil {
			continue
		}
		if searchResp.Data.TotalNumberOfItems == 0 || len(searchResp.Data.Items) == 0 {
			continue
		}

		item := searchResp.Data.Items[0]
		metadata := &ExtTrackMetadata{
			ID:         fmt.Sprintf("%d", item.ID),
			Name:       item.Title,
			Artists:    item.Artist.Name,
			AlbumName:  item.Album.Title,
			DurationMS: item.Duration * 1000,
			ISRC:       item.ISRC,
			TidalID:    fmt.Sprintf("%d", item.ID),
		}

		c.setCache(cacheKey, metadata, tidalMetadataTTL)
		return metadata, nil
	}

	return nil, fmt.Errorf("tidal_monochrome: no results for query %q", query)
}

// TidalMonochromeEnrichISRC tries to fill missing ISRC by searching Tidal.
func TidalMonochromeEnrichISRC(req *DownloadRequest) string {
	if req.ISRC != "" {
		return req.ISRC
	}
	if req.TrackName == "" || req.ArtistName == "" {
		return req.ISRC
	}

	client := GetTidalMonochromeClient()
	query := req.TrackName + " " + req.ArtistName
	track, err := client.SearchText(query)
	if err != nil || track == nil || track.ISRC == "" {
		query = req.ArtistName + " " + req.TrackName
		track, err = client.SearchText(query)
		if err != nil || track == nil || track.ISRC == "" {
			return req.ISRC
		}
	}

	GoLog("[TidalMonochrome] Enriched ISRC via Tidal: %q -> %q\n", req.ISRC, track.ISRC)
	if req.TidalID == "" && track.TidalID != "" {
		req.TidalID = track.TidalID
	}
	return track.ISRC
}

func downloadViaTidalMonochrome(req *DownloadRequest) (*DownloadResponse, error) {
	tidalID, err := searchTidalMonochromeID(req)
	if err != nil {
		return nil, err
	}

	client := GetTidalMonochromeClient()
	streamURL, err := client.GetTrackStreamURL(tidalID)
	if err != nil {
		return nil, fmt.Errorf("tidal_monochrome: %w", err)
	}

	outputPath := buildOutputPath(*req)
	if req.ItemID != "" {
		StartItemProgress(req.ItemID)
	}

	dlResp, err := client.httpClient.Get(streamURL)
	if err != nil {
		if req.ItemID != "" {
			RemoveItemProgress(req.ItemID)
		}
		return nil, fmt.Errorf("tidal_monochrome download request: %w", err)
	}
	defer dlResp.Body.Close()

	if dlResp.StatusCode != http.StatusOK {
		if req.ItemID != "" {
			RemoveItemProgress(req.ItemID)
		}
		return nil, fmt.Errorf("tidal_monochrome: HTTP %d", dlResp.StatusCode)
	}

	outFile, err := os.Create(outputPath)
	if err != nil {
		if req.ItemID != "" {
			RemoveItemProgress(req.ItemID)
		}
		return nil, fmt.Errorf("tidal_monochrome create file: %w", err)
	}

	if _, copyErr := io.Copy(outFile, dlResp.Body); copyErr != nil {
		outFile.Close()
		os.Remove(outputPath)
		if req.ItemID != "" {
			RemoveItemProgress(req.ItemID)
		}
		return nil, fmt.Errorf("tidal_monochrome save file: %w", copyErr)
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
		tidalMonochromeName,
		"Downloaded from "+tidalMonochromeName,
		outputPath,
		false,
	)
	return &resp, nil
}

var tidalQualityPriority = []string{"HI_RES_LOSSLESS", "HI_RES", "LOSSLESS", "HIGH", "LOW"}

func getTidalQuality(quality string) string {
	q := strings.ToUpper(quality)
	for _, qp := range tidalQualityPriority {
		if q == "LOSSLESS" && (qp == "LOSSLESS" || qp == "HI_RES" || qp == "HI_RES_LOSSLESS") {
			continue
		}
		if q == qp {
			return qp
		}
	}
	if quality == "24" || quality == "24/192" || quality == "24/96" || quality == "24/48" {
		return "HI_RES_LOSSLESS"
	}
	if quality == "16" || quality == "16/44" || quality == "16/44.1" {
		return "LOSSLESS"
	}
	return "LOSSLESS"
}

func tidalQualityFallback(quality string) []string {
	seen := map[string]bool{}
	var chain []string
	normalized := getTidalQuality(quality)
	chain = append(chain, normalized)
	seen[normalized] = true

	for _, q := range tidalQualityPriority {
		if !seen[q] {
			chain = append(chain, q)
			seen[q] = true
		}
	}
	return chain
}

func downloadViaTidalMonochromeWithFallback(req *DownloadRequest) (*DownloadResponse, error) {
	qualities := tidalQualityFallback(req.Quality)
	var lastErr error

	for _, quality := range qualities {
		qualityReq := *req
		qualityReq.Quality = quality
		resp, err := downloadViaTidalMonochrome(&qualityReq)
		if err == nil {
			if quality != req.Quality {
				GoLog("[TidalMonochrome] Quality fallback: %s -> %s\n", req.Quality, quality)
			}
			return resp, nil
		}
		lastErr = err
	}
	return nil, fmt.Errorf("tidal_monochrome: all qualities failed, last: %w", lastErr)
}
