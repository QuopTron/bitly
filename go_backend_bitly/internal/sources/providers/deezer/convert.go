package deezer

import (
	"fmt"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

func deezerTrackArtistDisplay(track deezerTrack) string {
	if len(track.Contributors) > 0 {
		names := make([]string, len(track.Contributors))
		for i, a := range track.Contributors {
			names[i] = a.Name
		}
		return strings.Join(names, ", ")
	}
	return track.Artist.Name
}

func (c *Client) convertTrack(track deezerTrack) core.TrackMetadata {
	artistName := deezerTrackArtistDisplay(track)
	albumImage := track.Album.CoverXL
	if albumImage == "" {
		albumImage = track.Album.CoverBig
	}
	if albumImage == "" {
		albumImage = track.Album.CoverMedium
	}
	if albumImage == "" {
		albumImage = track.Album.Cover
	}
	releaseDate := track.ReleaseDate
	if releaseDate == "" {
		releaseDate = track.Album.ReleaseDate
	}
	return core.TrackMetadata{
		SpotifyID:   fmt.Sprintf("deezer:%d", track.ID),
		Artists:     artistName,
		Name:        track.Title,
		AlbumName:   track.Album.Title,
		AlbumArtist: track.Artist.Name,
		DurationMS:  track.Duration * 1000,
		Images:      albumImage,
		ReleaseDate: releaseDate,
		TrackNumber: track.TrackPosition,
		DiscNumber:  track.DiskNumber,
		ExternalURL: track.Link,
		ISRC:        track.ISRC,
		AlbumID:     fmt.Sprintf("deezer:%d", track.Album.ID),
		ArtistID:    fmt.Sprintf("deezer:%d", track.Artist.ID),
	}
}

func (c *Client) bestArtistImage(artist deezerArtist) string {
	if artist.PictureXL != "" {
		return artist.PictureXL
	}
	if artist.PictureBig != "" {
		return artist.PictureBig
	}
	if artist.PictureMedium != "" {
		return artist.PictureMedium
	}
	return artist.Picture
}

func (c *Client) bestArtistImageFull(artist deezerArtistFull) string {
	if artist.PictureXL != "" {
		return artist.PictureXL
	}
	if artist.PictureBig != "" {
		return artist.PictureBig
	}
	if artist.PictureMedium != "" {
		return artist.PictureMedium
	}
	return artist.Picture
}

func (c *Client) bestAlbumImage(album deezerAlbumFull) string {
	if album.CoverXL != "" {
		return album.CoverXL
	}
	if album.CoverBig != "" {
		return album.CoverBig
	}
	if album.CoverMedium != "" {
		return album.CoverMedium
	}
	return album.Cover
}
