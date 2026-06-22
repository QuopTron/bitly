package deezer

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

func (c *Client) GetAlbum(ctx context.Context, albumID string) (*core.AlbumResponsePayload, error) {
	c.cacheMu.RLock()
	if entry, ok := c.albumCache[albumID]; ok && !entry.isExpired() {
		c.cacheMu.RUnlock()
		return entry.data.(*core.AlbumResponsePayload), nil
	}
	c.cacheMu.RUnlock()

	u := fmt.Sprintf(albumURL, albumID)
	var album deezerAlbumFull
	if err := c.getJSON(ctx, u, &album); err != nil {
		return nil, err
	}

	albumImage := c.bestAlbumImage(album)
	artistName := album.Artist.Name
	if len(album.Contributors) > 0 {
		names := make([]string, len(album.Contributors))
		for i, a := range album.Contributors {
			names[i] = a.Name
		}
		artistName = strings.Join(names, ", ")
	}

	var genres []string
	for _, g := range album.Genres.Data {
		if g.Name != "" {
			genres = append(genres, g.Name)
		}
	}

	info := core.AlbumInfoMetadata{
		TotalTracks: album.NbTracks,
		Name:        album.Title,
		ReleaseDate: album.ReleaseDate,
		Artists:     artistName,
		ArtistId:    fmt.Sprintf("deezer:%d", album.Artist.ID),
		Images:      albumImage,
		Genre:       strings.Join(genres, ", "),
		Label:       album.Label,
	}

	allTracks := album.Tracks.Data
	if album.NbTracks > len(allTracks) {
		allTracks = c.fetchAlbumTracksPaginated(ctx, albumID, album.NbTracks, allTracks)
	}

	isrcMap := c.fetchISRCsParallel(ctx, allTracks)
	totalDiscs := 0
	for _, track := range allTracks {
		if track.DiskNumber > totalDiscs {
			totalDiscs = track.DiskNumber
		}
	}

	albumType := album.RecordType
	if albumType == "compile" {
		albumType = "compilation"
	}

	tracks := make([]core.AlbumTrackMetadata, 0, len(allTracks))
	for i, track := range allTracks {
		trackIDStr := fmt.Sprintf("%d", track.ID)
		isrc := isrcMap[trackIDStr]
		trackNum := track.TrackPosition
		if trackNum == 0 {
			trackNum = i + 1
		}
		tracks = append(tracks, core.AlbumTrackMetadata{
			SpotifyID:   fmt.Sprintf("deezer:%d", track.ID),
			Artists:     deezerTrackArtistDisplay(track),
			Name:        track.Title,
			AlbumName:   album.Title,
			AlbumArtist: artistName,
			DurationMS:  track.Duration * 1000,
			Images:      albumImage,
			ReleaseDate: album.ReleaseDate,
			TrackNumber: trackNum,
			TotalTracks: album.NbTracks,
			DiscNumber:  track.DiskNumber,
			TotalDiscs:  totalDiscs,
			ExternalURL: track.Link,
			ISRC:        isrc,
			AlbumID:     fmt.Sprintf("deezer:%d", album.ID),
			AlbumType:   albumType,
		})
	}

	result := &core.AlbumResponsePayload{AlbumInfo: info, TrackList: tracks}

	c.cacheMu.Lock()
	now := time.Now()
	c.albumCache[albumID] = &cacheEntry{data: result, expiresAt: now.Add(cacheTTL)}
	c.maybeCleanupCachesLocked(now)
	c.cacheMu.Unlock()

	return result, nil
}

func (c *Client) fetchAlbumTracksPaginated(ctx context.Context, albumID string, expected int, initial []deezerTrack) []deezerTrack {
	allTracks := initial
	tracksURL := fmt.Sprintf("%s/tracks?limit=100&index=%d", fmt.Sprintf(albumURL, albumID), len(allTracks))
	for len(allTracks) < expected {
		var tracksResp struct {
			Data []deezerTrack `json:"data"`
			Next string        `json:"next"`
		}
		if err := c.getJSON(ctx, tracksURL, &tracksResp); err != nil {
			fmt.Printf("[Deezer] Warning: failed to fetch album tracks page: %v\n", err)
			break
		}
		if len(tracksResp.Data) == 0 {
			break
		}
		allTracks = append(allTracks, tracksResp.Data...)
		if tracksResp.Next == "" {
			break
		}
		tracksURL = tracksResp.Next
	}
	fmt.Printf("[Deezer] Fetched total %d tracks for album\n", len(allTracks))
	return allTracks
}
