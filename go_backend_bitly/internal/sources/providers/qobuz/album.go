package qobuz

import (
	"encoding/json"
	"fmt"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

func (c *Client) GetAlbum(albumID string) (*core.ExtAlbumMetadata, error) {
	cacheKey := "album:" + albumID
	if cached := c.getFromCache(cacheKey); cached != nil {
		return cached.(*core.ExtAlbumMetadata), nil
	}

	data, err := c.getJSON("/get-album", map[string]string{"album_id": albumID})
	if err != nil {
		return nil, fmt.Errorf("qobuz_kennyy get album: %w", err)
	}

	var album albumData
	if err := json.Unmarshal(data, &album); err != nil {
		return nil, fmt.Errorf("qobuz_kennyy parse album: %w", err)
	}

	tracks := make([]core.ExtTrackMetadata, 0, len(album.Tracks.Items))
	for _, t := range album.Tracks.Items {
		artistName := t.Performer.Name
		if artistName == "" {
			artistName = album.Artist.Name
		}
		tracks = append(tracks, core.ExtTrackMetadata{
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

	metadata := &core.ExtAlbumMetadata{
		ID:          album.ID,
		Name:        album.Title,
		Artists:     album.Artist.Name,
		ArtistID:    fmt.Sprintf("%d", album.Artist.ID),
		Tracks:      tracks,
		CoverURL:    coverURL,
		ReleaseDate: album.ReleaseDateOriginal,
		TotalTracks: album.TracksCount,
	}

	c.setCache(cacheKey, metadata, albumCacheTTL)
	return metadata, nil
}
