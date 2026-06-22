package deezer

import (
	"context"
	"fmt"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

func (c *Client) SearchAll(ctx context.Context, query string, trackLimit, artistLimit int, filter string) (*core.SearchAllResult, error) {
	fmt.Printf("[Deezer] SearchAll: query=%q, trackLimit=%d, artistLimit=%d, filter=%q\n", query, trackLimit, artistLimit, filter)

	albumLimit := 5
	playlistLimit := 5

	if filter != "" {
		switch filter {
		case "track":
			trackLimit = 50
			artistLimit, albumLimit, playlistLimit = 0, 0, 0
		case "artist":
			trackLimit = 0
			artistLimit = 20
			albumLimit, playlistLimit = 0, 0
		case "album":
			trackLimit = 0
			artistLimit = 0
			albumLimit = 20
			playlistLimit = 0
		case "playlist":
			trackLimit = 0
			artistLimit = 0
			albumLimit = 0
			playlistLimit = 20
		}
	}

	cacheKey := fmt.Sprintf("deezer:all:%s:%d:%d:%d:%d:%s", query, trackLimit, artistLimit, albumLimit, playlistLimit, filter)

	c.cacheMu.RLock()
	if entry, ok := c.searchCache[cacheKey]; ok && !entry.isExpired() {
		c.cacheMu.RUnlock()
		fmt.Printf("[Deezer] SearchAll: returning cached result\n")
		return entry.data.(*core.SearchAllResult), nil
	}
	c.cacheMu.RUnlock()

	result := &core.SearchAllResult{
		Tracks:    make([]core.TrackMetadata, 0, trackLimit),
		Artists:   make([]core.SearchArtistResult, 0, artistLimit),
		Albums:    make([]core.SearchAlbumResult, 0, albumLimit),
		Playlists: make([]core.SearchPlaylistResult, 0, playlistLimit),
	}

	if trackLimit > 0 {
		trackResp, err := c.searchTracks(ctx, query, trackLimit)
		if err != nil {
			fmt.Printf("[Deezer] Track search failed: %v\n", err)
		} else {
			for _, t := range trackResp {
				result.Tracks = append(result.Tracks, c.convertTrack(t))
			}
		}
	}

	if artistLimit > 0 {
		artists, err := c.searchArtists(ctx, query, artistLimit)
		if err != nil {
			fmt.Printf("[Deezer] Artist search failed: %v\n", err)
		} else {
			result.Artists = append(result.Artists, artists...)
		}
	}

	if albumLimit > 0 {
		albums, err := c.searchAlbums(ctx, query, albumLimit)
		if err != nil {
			fmt.Printf("[Deezer] Album search failed: %v\n", err)
		} else {
			result.Albums = append(result.Albums, albums...)
		}
	}

	if playlistLimit > 0 {
		playlists, err := c.searchPlaylists(ctx, query, playlistLimit)
		if err != nil {
			fmt.Printf("[Deezer] Playlist search failed: %v\n", err)
		} else {
			result.Playlists = append(result.Playlists, playlists...)
		}
	}

	fmt.Printf("[Deezer] SearchAll complete: %d tracks, %d artists, %d albums, %d playlists\n",
		len(result.Tracks), len(result.Artists), len(result.Albums), len(result.Playlists))

	c.cacheMu.Lock()
	now := time.Now()
	c.searchCache[cacheKey] = &cacheEntry{
		data:      result,
		expiresAt: now.Add(cacheTTL),
	}
	c.maybeCleanupCachesLocked(now)
	c.cacheMu.Unlock()

	return result, nil
}
