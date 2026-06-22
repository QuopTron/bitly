package deezer

import (
	"context"
	"fmt"
	"strings"
	"time"
)

type AlbumExtendedMetadata struct {
	Genre     string
	Label     string
	Copyright string
}

func (c *Client) GetAlbumExtendedMetadata(ctx context.Context, albumID string) (*AlbumExtendedMetadata, error) {
	if albumID == "" {
		return nil, fmt.Errorf("empty album ID")
	}
	cacheKey := "album_meta:" + albumID
	c.cacheMu.RLock()
	if entry, ok := c.searchCache[cacheKey]; ok && !entry.isExpired() {
		c.cacheMu.RUnlock()
		return entry.data.(*AlbumExtendedMetadata), nil
	}
	c.cacheMu.RUnlock()

	u := fmt.Sprintf(albumURL, albumID)
	var album deezerAlbumFull
	if err := c.getJSON(ctx, u, &album); err != nil {
		return nil, fmt.Errorf("failed to fetch album: %w", err)
	}

	var genres []string
	for _, g := range album.Genres.Data {
		if g.Name != "" {
			genres = append(genres, g.Name)
		}
	}
	result := &AlbumExtendedMetadata{
		Genre:     strings.Join(genres, ", "),
		Label:     album.Label,
		Copyright: album.Copyright,
	}

	c.cacheMu.Lock()
	now := time.Now()
	c.searchCache[cacheKey] = &cacheEntry{data: result, expiresAt: now.Add(cacheTTL)}
	c.maybeCleanupCachesLocked(now)
	c.cacheMu.Unlock()

	return result, nil
}

func (c *Client) GetExtendedMetadataByTrackID(ctx context.Context, trackID string) (*AlbumExtendedMetadata, error) {
	albumID, err := c.getTrackAlbumID(ctx, trackID)
	if err != nil {
		return nil, fmt.Errorf("failed to get album ID: %w", err)
	}
	return c.GetAlbumExtendedMetadata(ctx, albumID)
}

func (c *Client) GetExtendedMetadataByISRC(ctx context.Context, isrc string) (*AlbumExtendedMetadata, error) {
	if isrc == "" {
		return nil, fmt.Errorf("empty ISRC")
	}
	track, err := c.SearchByISRC(ctx, isrc)
	if err != nil {
		return nil, fmt.Errorf("failed to find track by ISRC: %w", err)
	}
	deezerID := strings.TrimPrefix(track.SpotifyID, "deezer:")
	if deezerID == "" {
		return nil, fmt.Errorf("track found but no Deezer ID")
	}
	return c.GetExtendedMetadataByTrackID(ctx, deezerID)
}

func (c *Client) getTrackAlbumID(ctx context.Context, trackID string) (string, error) {
	u := fmt.Sprintf(trackURL, trackID)
	var track deezerTrack
	if err := c.getJSON(ctx, u, &track); err != nil {
		return "", err
	}
	return fmt.Sprintf("%d", track.Album.ID), nil
}
