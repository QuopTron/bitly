package availability

import (
	"context"
	"fmt"
	"strings"
)

func (s *Client) CheckTrackAvailability(spotifyTrackID string, isrc string) (*TrackAvailability, error) {
	spotifyTrackID = strings.TrimSpace(spotifyTrackID)
	isrc = strings.ToUpper(strings.TrimSpace(isrc))

	switch {
	case spotifyTrackID != "":
		return s.checkFromSpotify(spotifyTrackID)
	case isrc != "":
		return s.checkFromISRC(isrc)
	default:
		return nil, fmt.Errorf("spotify track ID and ISRC are empty")
	}
}

func (s *Client) checkFromSpotify(spotifyTrackID string) (*TrackAvailability, error) {
	spotifyURL := fmt.Sprintf("https://open.spotify.com/track/%s", spotifyTrackID)
	links, err := s.resolve(spotifyURL)
	if err != nil {
		return nil, fmt.Errorf("resolve failed for Spotify %s: %w", spotifyTrackID, err)
	}
	return buildAvailability(spotifyTrackID, links), nil
}

func (s *Client) checkFromISRC(isrc string) (*TrackAvailability, error) {
	if s.isrcSearcher == nil {
		return nil, fmt.Errorf("ISRC searcher not configured — call SetISRCSearcher first")
	}

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	track, err := s.isrcSearcher.SearchByISRC(ctx, isrc)
	if err != nil {
		return nil, fmt.Errorf("failed to resolve track from ISRC %s: %w", isrc, err)
	}

	deezerTrackID := extractDeezerID(track)
	if deezerTrackID == "" {
		return nil, fmt.Errorf("failed to resolve Deezer track ID from ISRC %s", isrc)
	}

	return s.CheckAvailabilityFromDeezer(deezerTrackID)
}
