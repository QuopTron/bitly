package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/availability"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/providers/deezer"
)

// RegisterAvailabilityDeezerExtra registers legacy-compatible Deezer/Provider RPC methods.
func RegisterAvailabilityDeezerExtra(reg *rpc.Registry) {
	reg.Register("convertSpotifyToDeezer", func(params map[string]interface{}) (interface{}, error) {
		resourceType := rpc.Sp(params, "resource_type")
		spotifyID := rpc.Sp(params, "spotify_id")
		if spotifyID == "" {
			return nil, fmt.Errorf("spotify_id is required")
		}

		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		availClient := availability.NewClient()
		deezerClient := deezer.GetClient()

		if resourceType == "track" {
			deezerID, err := availClient.GetDeezerIDFromSpotify(spotifyID)
			if err != nil {
				return nil, fmt.Errorf("could not find Deezer equivalent: %w", err)
			}

			trackResp, err := deezerClient.GetTrack(ctx, deezerID)
			if err != nil {
				return nil, fmt.Errorf("failed to fetch Deezer metadata: %w", err)
			}
			if trackResp == nil {
				return nil, fmt.Errorf("no track data returned from Deezer")
			}

			jsonBytes, err := json.Marshal(trackResp)
			if err != nil {
				return nil, err
			}
			return string(jsonBytes), nil
		}

		if resourceType == "album" {
			deezerAlbumID, err := availClient.GetDeezerAlbumIDFromSpotify(spotifyID)
			if err != nil {
				return nil, fmt.Errorf("could not find Deezer album: %w", err)
			}

			albumResp, err := deezerClient.GetAlbum(ctx, deezerAlbumID)
			if err != nil {
				return nil, fmt.Errorf("failed to fetch Deezer album metadata: %w", err)
			}
			if albumResp == nil {
				return nil, fmt.Errorf("no album data returned from Deezer")
			}

			jsonBytes, err := json.Marshal(albumResp)
			if err != nil {
				return nil, err
			}
			return string(jsonBytes), nil
		}

		return nil, fmt.Errorf("spotify to Deezer conversion only supported for tracks and albums")
	})

	reg.Register("getDeezerExtendedMetadata", func(params map[string]interface{}) (interface{}, error) {
		trackID := rpc.Sp(params, "track_id")
		if trackID == "" {
			return nil, fmt.Errorf("track_id is required")
		}

		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()

		deezerClient := deezer.GetClient()
		metadata, err := deezerClient.GetExtendedMetadataByTrackID(ctx, trackID)
		if err != nil {
			return nil, err
		}

		result := map[string]string{
			"genre":     metadata.Genre,
			"label":     metadata.Label,
			"copyright": metadata.Copyright,
		}

		jsonBytes, err := json.Marshal(result)
		if err != nil {
			return nil, err
		}
		return string(jsonBytes), nil
	})

	reg.Register("getDeezerRelatedArtists", func(params map[string]interface{}) (interface{}, error) {
		artistID := rpc.Sp(params, "artist_id")
		limit := rpc.Sn(params, "limit")
		if artistID == "" {
			return nil, fmt.Errorf("artist_id is required")
		}
		if limit <= 0 {
			limit = 12
		}

		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()

		deezerClient := deezer.GetClient()
		artists, err := deezerClient.GetRelatedArtists(ctx, artistID, limit)
		if err != nil {
			return nil, err
		}

		result := map[string]interface{}{
			"artists": artists,
		}

		jsonBytes, err := json.Marshal(result)
		if err != nil {
			return nil, err
		}
		return string(jsonBytes), nil
	})

	reg.Register("getProviderMetadata", func(params map[string]interface{}) (interface{}, error) {
		providerID := rpc.Sp(params, "provider_id")
		resourceType := rpc.Sp(params, "resource_type")
		resourceID := rpc.Sp(params, "resource_id")

		if providerID == "" || resourceID == "" {
			return nil, fmt.Errorf("provider_id and resource_id are required")
		}

		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		switch strings.ToLower(strings.TrimSpace(providerID)) {
		case "deezer":
			deezerClient := deezer.GetClient()
			var data interface{}
			var err error

			switch resourceType {
			case "track":
				resp, trackErr := deezerClient.GetTrack(ctx, resourceID)
				data, err = resp, trackErr
			case "album":
				resp, albumErr := deezerClient.GetAlbum(ctx, resourceID)
				data, err = resp, albumErr
			default:
				return nil, fmt.Errorf("unsupported Deezer resource type: %s", resourceType)
			}

			if err != nil {
				return nil, err
			}

			jsonBytes, marshalErr := json.Marshal(data)
			if marshalErr != nil {
				return nil, marshalErr
			}
			return string(jsonBytes), nil

		case "qobuz_kennyy":
			// Delegate to search service — in the new backend, Qobuz metadata is
			// accessed through the search provider interface, not via direct RPC.
			// Return a meaningful error for direct RPC usage.
			return nil, fmt.Errorf("qobuz metadata via RPC is not available; use searchTracks instead")

		case "tidal_monochrome":
			return nil, fmt.Errorf("tidal metadata via RPC is not available; use searchTracks instead")

		default:
			return nil, fmt.Errorf("unknown provider: %s", providerID)
		}
	})

	reg.Register("searchDeezerByISRC", func(params map[string]interface{}) (interface{}, error) {
		isrc := rpc.Sp(params, "isrc")
		if isrc == "" {
			return nil, fmt.Errorf("isrc is required")
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		deezerClient := deezer.GetClient()
		track, err := deezerClient.SearchByISRC(ctx, isrc)
		if err != nil {
			return nil, err
		}

		result := map[string]interface{}{
			"id":            strings.TrimPrefix(track.SpotifyID, "deezer:"),
			"track_id":      strings.TrimPrefix(track.SpotifyID, "deezer:"),
			"spotify_id":    track.SpotifyID,
			"artists":       track.Artists,
			"name":          track.Name,
			"album_name":    track.AlbumName,
			"album_artist":  track.AlbumArtist,
			"duration_ms":   track.DurationMS,
			"images":        track.Images,
			"release_date":  track.ReleaseDate,
			"track_number":  track.TrackNumber,
			"disc_number":   track.DiscNumber,
			"external_urls": track.ExternalURL,
			"isrc":          track.ISRC,
			"album_id":      track.AlbumID,
			"artist_id":     track.ArtistID,
			"success":       strings.TrimPrefix(track.SpotifyID, "deezer:") != "",
		}

		jsonBytes, err := json.Marshal(result)
		if err != nil {
			return nil, err
		}
		return string(jsonBytes), nil
	})
}
