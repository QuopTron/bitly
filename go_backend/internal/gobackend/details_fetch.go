package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

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
	p := providerPorNombre(params.Source)
	if p == nil {
		return `{}`
	}

	// Prefer the extension raw detail (includes tracks).
	if ep, ok := p.(*provider.ExtensionProvider); ok {
		raw, err := ep.GetAlbumRaw(params.AlbumID)
		if err == nil && raw != "" && raw != "null" {
			if out := mapearAlbumDetalle(raw, params.Source); out != "" {
				return out
			}
		}
		// The raw detail call es scoped a el "detail" cooldown bucket; si se
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
	p := providerPorNombre(params.Source)
	if p == nil {
		return `{}`
	}

	if ep, ok := p.(*provider.ExtensionProvider); ok {
		raw, err := ep.GetPlaylistRaw(params.CollectionID)
		if err == nil && raw != "" && raw != "null" {
			if out := mapearPlaylistDetalle(raw, params.Source); out != "" {
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
	p := providerPorNombre(params.Source)
	if p == nil {
		return `{}`
	}

	if ep, ok := p.(*provider.ExtensionProvider); ok {
		raw, err := ep.GetArtistRaw(params.ArtistID)
		if err == nil && raw != "" && raw != "null" {
			if out := mapearArtistDetalle(raw, params.Source); out != "" {
				return out
			}
		}
		// Same isolation como FetchAlbumDetail: un tasa-limited raw detail call
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

// =========================================================================
// RAW → Flutter schema mappers (handles the various extension shapes)
// =========================================================================
