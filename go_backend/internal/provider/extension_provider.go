package provider

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/extensions"
)

// ExtensionProvider wraps a JS extension as a Provider.
type ExtensionProvider struct {
	extID   string
	name    string
	runtime *extensions.Runtime
}

// NewExtensionProvider creates a new provider backed by a JS extension.
func NewExtensionProvider(extID, name string, rt *extensions.Runtime) *ExtensionProvider {
	return &ExtensionProvider{
		extID:   extID,
		name:    name,
		runtime: rt,
	}
}

func (p *ExtensionProvider) Name() string { return p.name }

// SearchTracks calls the extension's searchTracks(query, limit) JS function.
func (p *ExtensionProvider) SearchTracks(query string, limit int) ([]TrackResult, error) {
	result, err := p.runtime.CallMethod(p.extID, "searchTracks", query, limit)
	if err != nil {
		return nil, fmt.Errorf("ext %s searchTracks: %w", p.extID, err)
	}
	if result == nil {
		return nil, nil
	}
	return convertToTrackResults(result, p.name)
}

// SearchAlbums calls the extension's customSearch with filter "album".
func (p *ExtensionProvider) SearchAlbums(query string, limit int) ([]AlbumResult, error) {
	opts := map[string]interface{}{"limit": limit, "filter": "album"}
	result, err := p.runtime.CallMethod(p.extID, "customSearch", query, opts)
	if err != nil || result == nil {
		return p.searchTracksAsAlbums(query, limit)
	}
	return convertToAlbumResults(result, p.name)
}

// SearchPlaylists calls the extension's customSearch with filter "playlist".
func (p *ExtensionProvider) SearchPlaylists(query string, limit int) ([]PlaylistResult, error) {
	opts := map[string]interface{}{"limit": limit, "filter": "playlist"}
	result, err := p.runtime.CallMethod(p.extID, "customSearch", query, opts)
	if err != nil || result == nil {
		return nil, nil
	}
	return convertToPlaylistResults(result, p.name)
}

// SearchArtists calls the extension's customSearch with filter "artist".
func (p *ExtensionProvider) SearchArtists(query string, limit int) ([]ArtistResult, error) {
	opts := map[string]interface{}{"limit": limit, "filter": "artist"}
	result, err := p.runtime.CallMethod(p.extID, "customSearch", query, opts)
	if err != nil || result == nil {
		return nil, nil
	}
	return convertToArtistResults(result, p.name)
}

// GetTrack calls the extension's getTrack(id) JS function.
func (p *ExtensionProvider) GetTrack(id string) (*TrackResult, error) {
	result, err := p.runtime.CallMethod(p.extID, "getTrack", id)
	if err != nil {
		return nil, fmt.Errorf("ext %s getTrack: %w", p.extID, err)
	}
	if result == nil {
		return nil, nil
	}
	return convertToTrackResult(result, p.name)
}

// GetTrackByISRC resolves an ISRC via the extension.
func (p *ExtensionProvider) GetTrackByISRC(isrc string) (*TrackResult, error) {
	trackID, _ := p.callStringMethod("resolveTrackIDFromISRC", isrc)
	if trackID != "" {
		return p.GetTrack(trackID)
	}
	avail, err := p.runtime.CallMethod(p.extID, "checkAvailability", isrc, "", "", map[string]interface{}{})
	if err == nil && avail != nil {
		if m, ok := avail.(map[string]interface{}); ok {
			if tid, ok := m["track_id"].(string); ok && tid != "" {
				return p.GetTrack(tid)
			}
		}
	}
	return p.searchByISRC(isrc)
}

// GetAlbum calls the extension's getAlbum(id).
func (p *ExtensionProvider) GetAlbum(id string) (*AlbumResult, error) {
	result, err := p.runtime.CallMethod(p.extID, "getAlbum", id)
	if err != nil {
		return nil, fmt.Errorf("ext %s getAlbum: %w", p.extID, err)
	}
	if result == nil {
		return nil, nil
	}
	return convertToAlbumResult(result, p.name)
}

// GetArtist calls the extension's getArtist(id).
func (p *ExtensionProvider) GetArtist(id string) (*ArtistResult, error) {
	result, err := p.runtime.CallMethod(p.extID, "getArtist", id)
	if err != nil {
		return nil, fmt.Errorf("ext %s getArtist: %w", p.extID, err)
	}
	if result == nil {
		return nil, nil
	}
	return convertToArtistResult(result, p.name)
}

// GetStreamURL calls the extension's getDownloadUrl(id, quality) for stream URL.
func (p *ExtensionProvider) GetStreamURL(id, quality string) (string, error) {
	result, err := p.runtime.CallMethod(p.extID, "getDownloadUrl", id, quality)
	if err != nil {
		return "", fmt.Errorf("ext %s getDownloadUrl: %w", p.extID, err)
	}
	if result == nil {
		return "", fmt.Errorf("ext %s: stream not available", p.extID)
	}
	if s, ok := result.(string); ok && s != "" {
		return s, nil
	}
	return "", fmt.Errorf("ext %s: getDownloadUrl returned no URL", p.extID)
}

// DownloadResult holds the result of a JS extension download.
type DownloadResult struct {
	Success   bool   `json:"success"`
	FilePath  string `json:"filePath"`
	Title     string `json:"title"`
	Artist    string `json:"artist"`
	Album     string `json:"album"`
	Error     string `json:"error,omitempty"`
}

// Download invokes the extension's full download pipeline (JS download() function).
// The JS function handles streaming, decryption, and file writing internally.
// onProgress is called from JS with percentage (0-100).
func (p *ExtensionProvider) Download(trackID, quality, outputPath string, onProgress func(int)) *DownloadResult {
	// Wrap the Go callback as a JS-compatible function
	progressFn := func(percent float64) {
		if onProgress != nil {
			onProgress(int(percent))
		}
	}

	result, err := p.runtime.CallMethod(p.extID, "download", trackID, quality, outputPath, progressFn)
	if err != nil {
		return &DownloadResult{Success: false, Error: fmt.Sprintf("ext %s download call failed: %v", p.extID, err)}
	}
	if result == nil {
		return &DownloadResult{Success: false, Error: "ext returned nil"}
	}

	m, ok := result.(map[string]interface{})
	if !ok {
		return &DownloadResult{Success: false, Error: fmt.Sprintf("ext returned unexpected type: %T", result)}
	}

	dr := &DownloadResult{}
	if s, ok := m["success"].(bool); ok {
		dr.Success = s
	}
	dr.FilePath = getString(m, "file_path", "filePath")
	dr.Title = getString(m, "title")
	dr.Artist = getString(m, "artist")
	dr.Album = getString(m, "album")
	if e, ok := m["error_message"].(string); ok && e != "" {
		dr.Error = e
	} else if e, ok := m["error"].(string); ok && e != "" {
		dr.Error = e
	}

	return dr
}

// --- Internal helpers ---

func (p *ExtensionProvider) searchTracksAsAlbums(query string, limit int) ([]AlbumResult, error) {
	result, err := p.runtime.CallMethod(p.extID, "searchTracks", query, limit)
	if err != nil || result == nil {
		return nil, nil
	}
	return convertToAlbumResults(result, p.name)
}

func (p *ExtensionProvider) searchByISRC(isrc string) (*TrackResult, error) {
	result, err := p.runtime.CallMethod(p.extID, "searchTracks", "isrc:\""+isrc+"\"", 5)
	if err != nil || result == nil {
		return nil, nil
	}
	tracks, err := convertToTrackResults(result, p.name)
	if err != nil || len(tracks) == 0 {
		return nil, nil
	}
	return &tracks[0], nil
}

// callStringMethod calls a JS method that returns a single string.
func (p *ExtensionProvider) callStringMethod(method string, args ...interface{}) (string, error) {
	result, err := p.runtime.CallMethod(p.extID, method, args...)
	if err != nil {
		return "", err
	}
	if result == nil {
		return "", nil
	}
	if s, ok := result.(string); ok {
		return s, nil
	}
	return fmt.Sprint(result), nil
}

// --- Conversion helpers ---

func toInt(v interface{}) int {
	if v == nil {
		return 0
	}
	switch n := v.(type) {
	case float64:
		return int(n)
	case int64:
		return int(n)
	case int:
		return n
	case string:
		i, _ := strconv.Atoi(n)
		return i
	default:
		return 0
	}
}

func getString(m map[string]interface{}, keys ...string) string {
	for _, k := range keys {
		if v, ok := m[k]; ok && v != nil {
			if s, ok := v.(string); ok && s != "" {
				return s
			}
		}
	}
	return ""
}

func getCoverURL(m map[string]interface{}) string {
	return getString(m, "cover_url", "coverUrl", "cover", "images", "image_url", "picture_xl", "picture_big", "picture_medium", "picture")
}

func convertToTrackResults(result interface{}, providerName string) ([]TrackResult, error) {
	list, ok := result.([]interface{})
	if !ok {
		return nil, fmt.Errorf("expected array, got %T", result)
	}
	tracks := make([]TrackResult, 0, len(list))
	for _, item := range list {
		m, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		t := TrackResult{
			ID:       getString(m, "id"),
			Title:    getString(m, "name", "title"),
			Artist:   getString(m, "artists", "artist"),
			ArtistID: getString(m, "artist_id", "artistId", "artistID"),
			Album:    getString(m, "album_name", "album"),
			AlbumID:  getString(m, "album_id", "albumId", "albumID"),
			Duration: toInt(m["duration_ms"]),
			ISRC:     getString(m, "isrc"),
			CoverURL: getCoverURL(m),
			Provider: providerName,
		}
		if t.ID == "" {
			continue
		}
		t.ID = stripPrefix(t.ID)
		tracks = append(tracks, t)
	}
	return tracks, nil
}

func convertToTrackResult(result interface{}, providerName string) (*TrackResult, error) {
	m, ok := result.(map[string]interface{})
	if !ok {
		if wrapper, ok := result.(map[string]interface{}); ok {
			if t, ok := wrapper["track"]; ok {
				if m2, ok := t.(map[string]interface{}); ok {
					m = m2
				}
			}
		}
		if m == nil {
			return nil, fmt.Errorf("expected object, got %T", result)
		}
	}
	t := TrackResult{
		ID:       getString(m, "id"),
		Title:    getString(m, "name", "title"),
		Artist:   getString(m, "artists", "artist"),
		ArtistID: getString(m, "artist_id", "artistId", "artistID"),
		Album:    getString(m, "album_name", "album"),
		AlbumID:  getString(m, "album_id", "albumId", "albumID"),
		Duration: toInt(m["duration_ms"]),
		ISRC:     getString(m, "isrc"),
		CoverURL: getCoverURL(m),
		Provider: providerName,
	}
	if t.ID != "" {
		t.ID = stripPrefix(t.ID)
	}
	return &t, nil
}

func convertToAlbumResults(result interface{}, providerName string) ([]AlbumResult, error) {
	list, ok := result.([]interface{})
	if !ok {
		return nil, fmt.Errorf("expected array, got %T", result)
	}
	albums := make([]AlbumResult, 0, len(list))
	for _, item := range list {
		m, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		a := AlbumResult{
			ID:          getString(m, "id"),
			Title:       getString(m, "name", "title"),
			Artist:      getString(m, "artists", "artist"),
			ArtistID:    getString(m, "artist_id", "artistId", "artistID"),
			CoverURL:    getCoverURL(m),
			ReleaseDate: getString(m, "release_date", "releaseDate"),
			TrackCount:  toInt(m["total_tracks"]),
			Provider:    providerName,
		}
		if a.ID != "" {
			a.ID = stripPrefix(a.ID)
		}
		if a.ID != "" {
			albums = append(albums, a)
		}
	}
	return albums, nil
}

func convertToAlbumResult(result interface{}, providerName string) (*AlbumResult, error) {
	m, ok := result.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("expected object, got %T", result)
	}
	a := AlbumResult{
		ID:          getString(m, "id"),
		Title:       getString(m, "name", "title"),
		Artist:      getString(m, "artists", "artist"),
		ArtistID:    getString(m, "artist_id", "artistId", "artistID"),
		CoverURL:    getCoverURL(m),
		ReleaseDate: getString(m, "release_date", "releaseDate"),
		TrackCount:  toInt(m["total_tracks"]),
		Provider:    providerName,
	}
	if a.ID != "" {
		a.ID = stripPrefix(a.ID)
	}
	return &a, nil
}

func convertToArtistResults(result interface{}, providerName string) ([]ArtistResult, error) {
	list, ok := result.([]interface{})
	if !ok {
		return nil, fmt.Errorf("expected array, got %T", result)
	}
	artists := make([]ArtistResult, 0, len(list))
	for _, item := range list {
		m, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		a := ArtistResult{
			ID:        getString(m, "id"),
			Name:      getString(m, "name"),
			PictureURL: getCoverURL(m),
			Fans:      toInt(m["listeners"]),
			Provider:  providerName,
		}
		if a.ID != "" {
			a.ID = stripPrefix(a.ID)
		}
		if a.ID != "" {
			artists = append(artists, a)
		}
	}
	return artists, nil
}

func convertToPlaylistResults(result interface{}, providerName string) ([]PlaylistResult, error) {
	list, ok := result.([]interface{})
	if !ok {
		return nil, fmt.Errorf("expected array, got %T", result)
	}
	playlists := make([]PlaylistResult, 0, len(list))
	for _, item := range list {
		m, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		p := PlaylistResult{
			ID:          getString(m, "id"),
			Title:       getString(m, "name", "title"),
			Description: getString(m, "description"),
			Creator:     getString(m, "owner", "creator", "artist", "artists"),
			TrackCount:  toInt(m["track_count"]),
			CoverURL:    getCoverURL(m),
			Provider:    providerName,
		}
		if p.ID != "" {
			p.ID = stripPrefix(p.ID)
		}
		if p.ID != "" {
			playlists = append(playlists, p)
		}
	}
	return playlists, nil
}

func convertToArtistResult(result interface{}, providerName string) (*ArtistResult, error) {
	m, ok := result.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("expected object, got %T", result)
	}
	a := ArtistResult{
		ID:        getString(m, "id"),
		Name:      getString(m, "name"),
		PictureURL: getCoverURL(m),
		Fans:      toInt(m["listeners"]),
		Provider:  providerName,
	}
	if a.ID != "" {
		a.ID = stripPrefix(a.ID)
	}
	return &a, nil
}

// stripPrefix removes provider: prefix from IDs (e.g., "deezer:123" -> "123").
func stripPrefix(id string) string {
	if idx := strings.IndexByte(id, ':'); idx >= 0 {
		return id[idx+1:]
	}
	return id
}
