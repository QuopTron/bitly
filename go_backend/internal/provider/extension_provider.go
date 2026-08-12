package provider

import (
	"encoding/json"
	"fmt"

	"github.com/zarz/bitly/go_backend/internal/extensions"
)

// ExtensionProvider wraps a JS extension as a Provider.
type ExtensionProvider struct {
	extID           string
	name            string
	runtime         *extensions.Runtime
	hasHomeFeed     bool
	// qualityOptions mirrors the manifest's qualityOptions list, so the
	// download/stream fallback can pass a quality token the extension actually
	// recognizes instead of a source-provider token that doesn't map.
	qualityOptions  []string
	// downloadCapable is false for metadata-only extensions (e.g. spotify-web)
	// that expose no download()/getDownloadUrl(), so the fallback can skip them
	// quickly instead of attempting a doomed download for every track.
	downloadCapable bool
}

// NewExtensionProvider creates a new provider backed by a JS extension.
func NewExtensionProvider(extID, name string, rt *extensions.Runtime) *ExtensionProvider {
	return &ExtensionProvider{
		extID:           extID,
		name:            name,
		runtime:         rt,
		downloadCapable: true, // optimistic; SetDownloadCapable(false) on metadata-only
	}
}

// SetHomeFeedEnabled marks whether the extension declares the homeFeed
// capability in its manifest (equivalent to SpotiFLAC's `hasHomeFeed`).
func (p *ExtensionProvider) SetHomeFeedEnabled(v bool) { p.hasHomeFeed = v }

// SetQualityOptions stores the extension's declared quality option IDs.
func (p *ExtensionProvider) SetQualityOptions(qs []string) { p.qualityOptions = qs }

// QualityOptions returns the extension's declared quality option IDs, or nil.
func (p *ExtensionProvider) QualityOptions() []string { return p.qualityOptions }

// SetDownloadCapable marks whether the extension can produce audio files.
func (p *ExtensionProvider) SetDownloadCapable(v bool) { p.downloadCapable = v }

// DownloadCapable reports whether the extension can produce audio files.
func (p *ExtensionProvider) DownloadCapable() bool { return p.downloadCapable }

// HomeFeedEnabled reports whether the extension supports a home feed.
func (p *ExtensionProvider) HomeFeedEnabled() bool { return p.hasHomeFeed }

func (p *ExtensionProvider) Name() string { return p.name }

// SearchTracks calls the extension's searchTracks(query, limit) JS function.
// Falls back to customSearch with filter "song" if searchTracks is not available.
func (p *ExtensionProvider) SearchTracks(query string, limit int) ([]TrackResult, error) {
	result, err := p.runtime.CallMethod(p.extID, "searchTracks", query, limit)
	if err == nil {
		if result != nil {
			return convertToTrackResults(result, p.name)
		}
		return nil, nil
	}

	// Fallback: try customSearch with filter "song"
	opts := map[string]interface{}{"limit": limit, "filter": "song"}
	result, err = p.runtime.CallMethod(p.extID, "customSearch", query, opts)
	if err != nil || result == nil {
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

// CombinedResult is a single typed search hit from an unfiltered combined
// search. Type mirrors the extension's item_type (track/album/artist/playlist).
type CombinedResult struct {
	ID          string
	Type        string
	Name        string
	Artists     string
	CoverURL    string
	AlbumID     string
	AlbumName   string
	Duration    int
	ReleaseDate string
	TotalTracks int
	Owner       string
}

// CombinedSearch runs the extension's customSearch with no type filter, which
// returns every result kind (tracks, albums, artists, playlists) in a single
// call — the SpotiFLAC principle. Each item keeps its own item_type, so the UI
// can group them afterwards. Providers whose filtered per-type search returns
// empty (e.g. Spotify web search only populates the combined "all" view) rely
// on this to surface artists/albums/playlists at all.
func (p *ExtensionProvider) CombinedSearch(query string, limit int) ([]CombinedResult, error) {
	opts := map[string]interface{}{"limit": limit}
	result, err := p.runtime.CallMethod(p.extID, "customSearch", query, opts)
	if err != nil || result == nil {
		return nil, nil
	}
	return p.combinedFromResult(result)
}

// SearchFiltered runs customSearch restricted to a single category using the
// extension's own manifest filter id (e.g. "tracks", "songs", "albums"). This is
// how SpotiFLAC re-queries a category when the user taps its bubble, returning
// many more results than the capped "all" mix (50 tracks / 20 albums, etc.).
func (p *ExtensionProvider) SearchFiltered(filter string, query string, limit int) ([]CombinedResult, error) {
	opts := map[string]interface{}{"limit": limit, "filter": filter}
	result, err := p.runtime.CallMethod(p.extID, "customSearch", query, opts)
	if err != nil || result == nil {
		return nil, nil
	}
	return p.combinedFromResult(result)
}

func (p *ExtensionProvider) combinedFromResult(result interface{}) ([]CombinedResult, error) {
	list, ok := result.([]interface{})
	if !ok {
		return nil, nil
	}
	out := make([]CombinedResult, 0, len(list))
	for _, item := range list {
		m, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		typ := getString(m, "item_type", "type")
		id := stripPrefix(getString(m, "id"))
		if id == "" {
			continue
		}
		out = append(out, CombinedResult{
			ID:          id,
			Type:        typ,
			Name:        getString(m, "name", "title"),
			Artists:     getString(m, "artists", "artist"),
			CoverURL:    getCoverURL(m),
			AlbumID:     getString(m, "album_id", "albumId", "albumID"),
			AlbumName:   getString(m, "album_name", "album"),
			Duration:    toInt(m["duration_ms"]),
			ReleaseDate: getString(m, "release_date"),
			TotalTracks: toInt(m["track_count"]),
			Owner:       getString(m, "owner"),
		})
	}
	return out, nil
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

// HomeFeedSection represents a section from a JS extension's getHomeFeed().
type HomeFeedSection struct {
	URI   string         `json:"uri"`
	Title string         `json:"title"`
	Items []HomeFeedItem `json:"items"`
}

// HomeFeedItem represents a single item in a home feed section.
// Compatible with SpotiFLAC-Mobile extension format.
type HomeFeedItem struct {
	Name       string `json:"name"`
	Artists    string `json:"artists"`
	DurationMs int    `json:"duration_ms,omitempty"`
	ItemType   string `json:"type"`
	ItemID     string `json:"id"`
	AlbumID    string `json:"album_id,omitempty"`
	AlbumName  string `json:"album_name,omitempty"`
	ThumbURL   string `json:"cover_url,omitempty"`
}

// GetHomeFeed calls the extension's getHomeFeed() JS function.
func (p *ExtensionProvider) GetHomeFeed() ([]HomeFeedSection, error) {
	result, err := p.runtime.CallMethod(p.extID, "getHomeFeed")
	if err != nil {
		return nil, fmt.Errorf("ext %s getHomeFeed: %w", p.extID, err)
	}
	if result == nil {
		return nil, nil
	}

	// Convert the JS result to JSON bytes so we can unmarshal properly
	// (Goja returns int64/float64, not int; json.Unmarshal handles all types)
	raw, err := json.Marshal(result)
	if err != nil {
		return nil, fmt.Errorf("ext %s: marshal getHomeFeed result: %w", p.extID, err)
	}

	var feedResult struct {
		Success  bool               `json:"success"`
		Sections []HomeFeedSection  `json:"sections"`
	}
	if err := json.Unmarshal(raw, &feedResult); err != nil {
		return nil, fmt.Errorf("ext %s: unmarshal getHomeFeed: %w", p.extID, err)
	}

	if !feedResult.Success || len(feedResult.Sections) == 0 {
		return nil, nil
	}

	// For YouTube Music, fill in missing thumbnails using video ID pattern
	if p.extID == "ytmusic-spotiflac" {
		for si := range feedResult.Sections {
			for ii := range feedResult.Sections[si].Items {
				item := &feedResult.Sections[si].Items[ii]
				if item.ThumbURL == "" && item.ItemID != "" {
					item.ThumbURL = "https://img.youtube.com/vi/" + item.ItemID + "/mqdefault.jpg"
				}
			}
		}
	}

	return feedResult.Sections, nil
}
