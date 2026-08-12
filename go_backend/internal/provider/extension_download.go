package provider

import (
	"fmt"
)

// DownloadResult holds the result of a JS extension download.
type DownloadResult struct {
	Success  bool   `json:"success"`
	FilePath string `json:"filePath"`
	Title    string `json:"title"`
	Artist   string `json:"artist"`
	Album    string `json:"album"`
	Encrypted bool  `json:"encrypted,omitempty"`
	// DecryptionKey is the optional key a provider supplies (e.g. amazon's
	// mov_key) to decrypt an encrypted stream into a playable file. Absent when
	// the download is already playable or the provider cannot decrypt.
	DecryptionKey  string `json:"decryption_key,omitempty"`
	OutputExtension string `json:"output_extension,omitempty"`
	Error    string `json:"error,omitempty"`
}

// Download invokes the extension's full download pipeline (JS download() function).
func (p *ExtensionProvider) Download(trackID, quality, outputPath string, onProgress func(int)) *DownloadResult {
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
	if e, ok := m["encrypted"].(bool); ok {
		dr.Encrypted = e
	}
	dr.DecryptionKey = getString(m, "decryption_key")
	dr.OutputExtension = getString(m, "output_extension")
	if e, ok := m["error_message"].(string); ok && e != "" {
		dr.Error = e
	} else if e, ok := m["error"].(string); ok && e != "" {
		dr.Error = e
	}
	return dr
}

func (p *ExtensionProvider) searchTracksAsAlbums(query string, limit int) ([]AlbumResult, error) {
	result, err := p.runtime.CallMethod(p.extID, "searchTracks", query, limit)
	if err != nil || result == nil {
		return nil, nil
	}
	return convertToAlbumResults(result, p.name)
}

func (p *ExtensionProvider) searchByISRC(isrc string) (*TrackResult, error) {
	result, err := p.runtime.CallMethod(p.extID, "searchTracks", `isrc:"`+isrc+`"`, 5)
	if err != nil || result == nil {
		return nil, nil
	}
	tracks, err := convertToTrackResults(result, p.name)
	if err != nil || len(tracks) == 0 {
		return nil, nil
	}
	return &tracks[0], nil
}

// IsNumericID reports whether [id] is a plain numeric id (deezer/tidal track
// ids). Used to feed a feed item's TrackID back as the cross-provider id for
// providers (e.g. amazon) that resolve via it.
func IsNumericID(id string) bool {
	if id == "" || len(id) > 20 {
		return false
	}
	for i := 0; i < len(id); i++ {
		if id[i] < '0' || id[i] > '9' {
			return false
		}
	}
	return true
}

// IsSpotifyID reports whether [id] looks like a Spotify track id (22 base-62
// alphanumeric characters). Used to feed a feed item's TrackID back as the
// cross-provider spotify id for providers (e.g. amazon) that resolve via it.
func IsSpotifyID(id string) bool {
	if len(id) != 22 {
		return false
	}
	for i := 0; i < len(id); i++ {
		c := id[i]
		if !(c >= 'A' && c <= 'Z') && !(c >= 'a' && c <= 'z') && !(c >= '0' && c <= '9') {
			return false
		}
	}
	return true
}

// CheckAvailability invokes the extension's checkAvailability(isrc, trackName,
// artistName, {spotify_id, deezer_id}) JS function, which returns
// {available, track_id} when the track can be resolved on the provider (e.g.
// amazon resolves the ASIN via its signed /resolve route instead of an
// anonymous web search). Returns the provider-specific track id and whether it
// was found.
func (p *ExtensionProvider) CheckAvailability(isrc, trackName, artistName string, spotifyID, deezerID string) (string, bool) {
	result, err := p.runtime.CallMethod(p.extID, "checkAvailability", isrc, trackName, artistName, map[string]interface{}{
		"spotify_id": spotifyID,
		"deezer_id":  deezerID,
	})
	if err != nil || result == nil {
		return "", false
	}
	m, ok := result.(map[string]interface{})
	if !ok {
		return "", false
	}
	if avail, ok := m["available"].(bool); ok && !avail {
		return "", false
	}
	if id, ok := m["track_id"].(string); ok && id != "" {
		return id, true
	}
	return "", false
}

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
