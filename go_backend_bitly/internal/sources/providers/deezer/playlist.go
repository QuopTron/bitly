package deezer

import (
	"context"
	"fmt"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

func (c *Client) GetPlaylist(ctx context.Context, playlistID string) (*core.PlaylistResponsePayload, error) {
	u := fmt.Sprintf(playlistURL, playlistID)
	var playlist deezerPlaylistFull
	if err := c.getJSON(ctx, u, &playlist); err != nil {
		return nil, err
	}

	playlistImage := playlist.PictureXL
	if playlistImage == "" {
		playlistImage = playlist.PictureBig
	}
	if playlistImage == "" {
		playlistImage = playlist.PictureMedium
	}

	var info core.PlaylistInfoMetadata
	info.Tracks.Total = playlist.NbTracks
	info.Owner.DisplayName = playlist.Creator.Name
	info.Owner.Name = playlist.Title
	info.Owner.Images = playlistImage

	allTracks := playlist.Tracks.Data
	if playlist.NbTracks > len(allTracks) {
		tracksURL := fmt.Sprintf("%s/tracks?limit=100&index=%d", fmt.Sprintf(playlistURL, playlistID), len(allTracks))
		for len(allTracks) < playlist.NbTracks {
			var tracksResp struct {
				Data []deezerTrack `json:"data"`
				Next string        `json:"next"`
			}
			if err := c.getJSON(ctx, tracksURL, &tracksResp); err != nil {
				fmt.Printf("[Deezer] Warning: failed to fetch playlist tracks page: %v\n", err)
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
	}

	isrcMap := c.fetchISRCsParallel(ctx, allTracks)
	tracks := make([]core.AlbumTrackMetadata, 0, len(allTracks))
	for _, track := range allTracks {
		albumImage := track.Album.CoverXL
		if albumImage == "" {
			albumImage = track.Album.CoverBig
		}
		if albumImage == "" {
			albumImage = track.Album.CoverMedium
		}
		trackIDStr := fmt.Sprintf("%d", track.ID)
		isrc := isrcMap[trackIDStr]

		tracks = append(tracks, core.AlbumTrackMetadata{
			SpotifyID:   fmt.Sprintf("deezer:%d", track.ID),
			Artists:     deezerTrackArtistDisplay(track),
			Name:        track.Title,
			AlbumName:   track.Album.Title,
			AlbumArtist: track.Artist.Name,
			DurationMS:  track.Duration * 1000,
			Images:      albumImage,
			TrackNumber: track.TrackPosition,
			DiscNumber:  track.DiskNumber,
			ExternalURL: track.Link,
			ISRC:        isrc,
			AlbumID:     fmt.Sprintf("deezer:%d", track.Album.ID),
		})
	}

	return &core.PlaylistResponsePayload{PlaylistInfo: info, TrackList: tracks}, nil
}
