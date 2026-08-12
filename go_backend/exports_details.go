package gobackend

import (
	"encoding/json"
	"strconv"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// =========================================================================
// DETAIL VIEWS — Flutter DetailMixin contract:
//   fetchAlbumDetail   {album_id, source}      → AlbumDetail JSON
//   fetchPlaylistDetail {collection_id, source} → PlaylistDetail JSON
//   fetchArtistDetail  {artist_id, source}     → ArtistDetail JSON
// =========================================================================

// detailTrack is Flutter's DetailTrack schema.
type detailTrack struct {
	TrackID      string `json:"trackId"`
	Name         string `json:"name"`
	DurationMs   int    `json:"durationMs"`
	TrackNumber  int    `json:"trackNumber"`
	ISRC         string `json:"isrc"`
	CoverURL     string `json:"coverUrl,omitempty"`
	CoverPath    string `json:"coverPath,omitempty"`
	FilePath     string `json:"filePath,omitempty"`
	ArtistName   string `json:"artistName,omitempty"`
	AlbumName    string `json:"albumName,omitempty"`
	IsLiked      bool   `json:"isLiked"`
	IsDownloaded bool   `json:"isDownloaded"`
	Provider     string `json:"provider,omitempty"`
	// Cross-provider ids, mirroring the reference CheckAvailabilityForItemID
	// inputs so a detail track from ANY extension (spotify, tidal, qobuz,
	// deezer) can resolve immediately on other providers instead of falling
	// back to a slow name search.
	SpotifyID string `json:"spotifyId,omitempty"`
	DeezerID  string `json:"deezerId,omitempty"`
	TidalID   string `json:"tidalId,omitempty"`
	QobuzID   string `json:"qobuzId,omitempty"`
}

// detailAlbum is Flutter's DetailAlbum schema (artist page albums).
type detailAlbum struct {
	AlbumID     string `json:"albumId"`
	Name        string `json:"name"`
	CoverURL    string `json:"coverUrl,omitempty"`
	CoverPath   string `json:"coverPath,omitempty"`
	ReleaseDate string `json:"releaseDate,omitempty"`
	TotalTracks int    `json:"totalTracks"`
	PlayCount   int    `json:"playCount"`
}

// FetchAlbumDetail returns the album detail with its full track list.
func FetchAlbumDetail(payload string) string {
	var params struct {
		AlbumID string `json:"album_id"`
		Source  string `json:"source"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{}`
	}
	if params.AlbumID == "" {
		return `{}`
	}
	p := providerByName(params.Source)
	if p == nil {
		return `{}`
	}

	// Prefer the extension raw detail (includes tracks).
	if ep, ok := p.(*provider.ExtensionProvider); ok {
		raw, err := ep.GetAlbumRaw(params.AlbumID)
		if err == nil && raw != "" && raw != "null" {
			if out := mapAlbumDetail(raw, params.Source); out != "" {
				return out
			}
		}
		// The raw detail call is scoped to the "detail" cooldown bucket; if it
		// just 429'd (bucket now cooled), DON'T fall through to GetAlbum — that
		// re-hits the same provider through the provider-wide bucket and would
		// leak a detail-page rate-limit into playback/search. Genuine
		// non-rate-limit failures still fall back as before.
		if cooldown.IsCooledOp(p.Name(), "detail") {
			return `{}`
		}
	}

	// Fallback: basic GetAlbum.
	album, err := p.GetAlbum(params.AlbumID)
	if err != nil || album == nil {
		return `{}`
	}
	out := map[string]interface{}{
		"id":          album.ID,
		"name":        album.Title,
		"coverUrl":    album.CoverURL,
		"artistName":  album.Artist,
		"releaseDate": album.ReleaseDate,
		"totalTracks": album.TrackCount,
		"tracks":      []detailTrack{},
	}
	data, _ := json.Marshal(out)
	return string(data)
}

// FetchPlaylistDetail returns the playlist detail with its track list.
func FetchPlaylistDetail(payload string) string {
	var params struct {
		CollectionID string `json:"collection_id"`
		Source       string `json:"source"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{}`
	}
	if params.CollectionID == "" {
		return `{}`
	}
	p := providerByName(params.Source)
	if p == nil {
		return `{}`
	}

	if ep, ok := p.(*provider.ExtensionProvider); ok {
		raw, err := ep.GetPlaylistRaw(params.CollectionID)
		if err == nil && raw != "" && raw != "null" {
			if out := mapPlaylistDetail(raw, params.Source); out != "" {
				return out
			}
		}
	}
	return `{}`
}

// FetchArtistDetail returns the artist detail with top tracks + top albums.
func FetchArtistDetail(payload string) string {
	var params struct {
		ArtistID string `json:"artist_id"`
		Source   string `json:"source"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{}`
	}
	if params.ArtistID == "" {
		return `{}`
	}
	p := providerByName(params.Source)
	if p == nil {
		return `{}`
	}

	if ep, ok := p.(*provider.ExtensionProvider); ok {
		raw, err := ep.GetArtistRaw(params.ArtistID)
		if err == nil && raw != "" && raw != "null" {
			if out := mapArtistDetail(raw, params.Source); out != "" {
				return out
			}
		}
		// Same isolation as FetchAlbumDetail: a rate-limited raw detail call
		// must not fall through to GetArtist and cool the provider-wide bucket.
		if cooldown.IsCooledOp(p.Name(), "detail") {
			return `{}`
		}
	}

	// Fallback: basic GetArtist.
	artist, err := p.GetArtist(params.ArtistID)
	if err != nil || artist == nil {
		return `{}`
	}
	out := map[string]interface{}{
		"id":        artist.ID,
		"name":      artist.Name,
		"imageUrl":  artist.PictureURL,
		"topTracks": []detailTrack{},
		"topAlbums": []detailAlbum{},
	}
	data, _ := json.Marshal(out)
	return string(data)
}

// providerByName finds a provider by name (case-insensitive).
func providerByName(name string) provider.Provider {
	if reg == nil {
		return nil
	}
	if p := reg.Get(name); p != nil {
		return p
	}
	for _, n := range reg.Names() {
		if strings.EqualFold(n, name) {
			return reg.Get(n)
		}
	}
	return nil
}

// =========================================================================
// RAW → Flutter schema mappers (handles the various extension shapes)
// =========================================================================

func mapAlbumDetail(raw, source string) string {
	var m map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &m); err != nil {
		return ""
	}
	name := detailString(m, "name", "title")
	if name == "" {
		return ""
	}
	tracks := extractDetailTracks(m, source)
	out := map[string]interface{}{
		"id":          detailString(m, "id"),
		"name":        name,
		"coverUrl":    detailCover(m),
		"artistName":  detailString(m, "artists", "artist", "artist_name"),
		"releaseDate": detailString(m, "release_date", "releaseDate"),
		"albumType":   detailString(m, "album_type", "albumType"),
		"totalTracks": detailInt(m, "total_tracks", "totalTracks"),
		"tracks":      tracks,
	}
	data, _ := json.Marshal(out)
	return string(data)
}

func mapPlaylistDetail(raw, source string) string {
	var m map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &m); err != nil {
		return ""
	}
	name := detailString(m, "name", "title")
	if name == "" {
		return ""
	}
	tracks := extractDetailTracks(m, source)
	out := map[string]interface{}{
		"id":        detailString(m, "id"),
		"name":      name,
		"coverUrl":  detailCover(m),
		"itemCount": detailInt(m, "total_tracks", "totalTracks", "track_count", "itemCount"),
		"tracks":    tracks,
	}
	data, _ := json.Marshal(out)
	return string(data)
}

func mapArtistDetail(raw, source string) string {
	var m map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &m); err != nil {
		return ""
	}
	name := detailString(m, "name", "title")
	if name == "" {
		return ""
	}
	topTracks := extractDetailTracks(m, source)
	albums := extractDetailAlbums(m)
	out := map[string]interface{}{
		"id":        detailString(m, "id"),
		"name":      name,
		"imageUrl":  detailCover(m),
		"topTracks": topTracks,
		"topAlbums": albums,
	}
	data, _ := json.Marshal(out)
	return string(data)
}

// extractDetailTracks pulls a track list from any common key name. Artist
// responses commonly put top songs under top_tracks/topTracks (amazon,
// ytmusic-spotiflac), matching the reference's parseExtensionArtistValue.
func extractDetailTracks(m map[string]interface{}, source string) []detailTrack {
	lists := []string{"tracks", "track_list", "songs", "items", "data", "top_tracks", "topTracks", "top-songs"}
	for _, key := range lists {
		raw, ok := m[key]
		if !ok {
			continue
		}
		items, ok := raw.([]interface{})
		if !ok || len(items) == 0 {
			continue
		}
		result := make([]detailTrack, 0, len(items))
		for _, it := range items {
			tm, ok := it.(map[string]interface{})
			if !ok {
				continue
			}
			tid := detailString(tm, "id", "track_id", "trackId")
			tname := detailString(tm, "name", "title")
			if tid == "" && tname == "" {
				continue
			}
			// Prefer the track's own provider_id when present (extensions tag
			// every track with it) — a playlist can mix tracks from different
			// providers, and forcing the collection source misroutes playback.
			provider := detailString(tm, "provider_id", "providerId")
			if provider == "" {
				provider = source
			}
			result = append(result, detailTrack{
				TrackID:     tid,
				Name:        tname,
				DurationMs:  detailInt(tm, "duration_ms", "durationMs"),
				TrackNumber: detailInt(tm, "track_number", "trackNumber"),
				ISRC:        detailString(tm, "isrc"),
				CoverURL:    detailCover(tm),
				ArtistName:  detailString(tm, "artists", "artist", "artist_name"),
				AlbumName:   detailString(tm, "album_name", "album", "albumName"),
				Provider:    provider,
				SpotifyID:   detailString(tm, "spotify_id", "spotifyId"),
				DeezerID:    detailString(tm, "deezer_id", "deezerId"),
				TidalID:     detailString(tm, "tidal_id", "tidalId"),
				QobuzID:     detailString(tm, "qobuz_id", "qobuzId"),
			})
		}
		return result
	}
	return []detailTrack{}
}

// extractDetailAlbums pulls the album list from an artist detail object.
func extractDetailAlbums(m map[string]interface{}) []detailAlbum {
	lists := []string{"albums", "top_albums", "topAlbums", "releases"}
	for _, key := range lists {
		raw, ok := m[key]
		if !ok {
			continue
		}
		items, ok := raw.([]interface{})
		if !ok || len(items) == 0 {
			continue
		}
		result := make([]detailAlbum, 0, len(items))
		for _, it := range items {
			am, ok := it.(map[string]interface{})
			if !ok {
				continue
			}
			aid := detailString(am, "id", "album_id", "albumId")
			aname := detailString(am, "name", "title")
			if aid == "" && aname == "" {
				continue
			}
			result = append(result, detailAlbum{
				AlbumID:     aid,
				Name:        aname,
				CoverURL:    detailCover(am),
				ReleaseDate: detailString(am, "release_date", "releaseDate"),
				TotalTracks: detailInt(am, "total_tracks", "totalTracks", "track_count"),
			})
		}
		return result
	}
	return []detailAlbum{}
}

// detailString reads the first non-empty string from a list of keys.
func detailString(m map[string]interface{}, keys ...string) string {
	for _, k := range keys {
		if v, ok := m[k]; ok && v != nil {
			if s, ok := v.(string); ok && s != "" {
				return s
			}
		}
	}
	return ""
}

// detailInt reads the first non-zero int from a list of keys.
func detailInt(m map[string]interface{}, keys ...string) int {
	for _, k := range keys {
		if v, ok := m[k]; ok && v != nil {
			switch n := v.(type) {
			case float64:
				return int(n)
			case int64:
				return int(n)
			case int:
				return n
			case string:
				if out, err := strconv.Atoi(n); err == nil {
					return out
				}
			}
		}
	}
	return 0
}

// detailCover resolves a cover URL from the common key shapes.
func detailCover(m map[string]interface{}) string {
	for _, k := range []string{"cover_url", "coverUrl", "cover", "images", "image_url", "imageUrl", "picture", "picture_xl", "thumbnail"} {
		v, ok := m[k]
		if !ok || v == nil {
			continue
		}
		if s, ok := v.(string); ok && s != "" {
			return s
		}
		// images can be an array of {url} or a string
		if arr, ok := v.([]interface{}); ok && len(arr) > 0 {
			if first, ok := arr[0].(map[string]interface{}); ok {
				if s := detailString(first, "url", "href", "src"); s != "" {
					return s
				}
			}
			if s, ok := arr[0].(string); ok {
				return s
			}
		}
	}
	return ""
}
