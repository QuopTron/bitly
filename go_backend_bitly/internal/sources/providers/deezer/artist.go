package deezer

import (
	"context"
	"fmt"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

func (c *Client) GetArtist(ctx context.Context, artistID string) (*core.ArtistResponsePayload, error) {
	c.cacheMu.RLock()
	if entry, ok := c.artistCache[artistID]; ok && !entry.isExpired() {
		c.cacheMu.RUnlock()
		return entry.data.(*core.ArtistResponsePayload), nil
	}
	c.cacheMu.RUnlock()

	u := fmt.Sprintf(artistURL, artistID)
	var artist deezerArtistFull
	if err := c.getJSON(ctx, u, &artist); err != nil {
		return nil, err
	}

	artistInfo := core.ArtistInfoMetadata{
		ID:     fmt.Sprintf("deezer:%d", artist.ID),
		Name:   artist.Name,
		Images: c.bestArtistImageFull(artist),
	}

	albums := c.fetchArtistAlbums(ctx, artistID, artist.Name)

	result := &core.ArtistResponsePayload{ArtistInfo: artistInfo, Albums: albums}

	c.cacheMu.Lock()
	now := time.Now()
	c.artistCache[artistID] = &cacheEntry{data: result, expiresAt: now.Add(cacheTTL)}
	c.maybeCleanupCachesLocked(now)
	c.cacheMu.Unlock()

	return result, nil
}

func (c *Client) fetchArtistAlbums(ctx context.Context, artistID, artistName string) []core.ArtistAlbumMetadata {
	albumsURL := fmt.Sprintf("%s/albums?limit=100", fmt.Sprintf(artistURL, artistID))
	var albumsResp struct {
		Data []struct {
			ID          int64  `json:"id"`
			Title       string `json:"title"`
			ReleaseDate string `json:"release_date"`
			NbTracks    int    `json:"nb_tracks"`
			Cover       string `json:"cover"`
			CoverMedium string `json:"cover_medium"`
			CoverBig    string `json:"cover_big"`
			CoverXL     string `json:"cover_xl"`
			RecordType  string `json:"record_type"`
		} `json:"data"`
	}
	if err := c.getJSON(ctx, albumsURL, &albumsResp); err != nil {
		return nil
	}

	albums := make([]core.ArtistAlbumMetadata, 0, len(albumsResp.Data))
	for _, a := range albumsResp.Data {
		albumType := a.RecordType
		if albumType == "compile" {
			albumType = "compilation"
		}
		coverURL := a.CoverXL
		if coverURL == "" {
			coverURL = a.CoverBig
		}
		if coverURL == "" {
			coverURL = a.CoverMedium
		}
		if coverURL == "" {
			coverURL = a.Cover
		}
		albums = append(albums, core.ArtistAlbumMetadata{
			ID:          fmt.Sprintf("deezer:%d", a.ID),
			Name:        a.Title,
			ReleaseDate: a.ReleaseDate,
			TotalTracks: a.NbTracks,
			Images:      coverURL,
			AlbumType:   albumType,
			Artists:     artistName,
		})
	}
	return albums
}
