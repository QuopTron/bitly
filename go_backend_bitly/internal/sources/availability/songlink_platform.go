package availability

import "fmt"

func (s *Client) CheckAvailabilityFromDeezer(deezerTrackID string) (*TrackAvailability, error) {
	if deezerTrackID == "" {
		return nil, fmt.Errorf("deezer track ID is empty")
	}
	deezerURL := fmt.Sprintf("https://www.deezer.com/track/%s", deezerTrackID)
	links, err := s.resolve(deezerURL)
	if err != nil {
		return nil, fmt.Errorf("resolve failed for Deezer %s: %w", deezerTrackID, err)
	}

	availability := buildAvailability("", links)
	availability.Deezer = true
	availability.DeezerID = deezerTrackID
	if availability.DeezerURL == "" {
		availability.DeezerURL = deezerURL
	}
	return availability, nil
}

func (s *Client) CheckAvailabilityByPlatform(platform, entityType, entityID string) (*TrackAvailability, error) {
	if entityID == "" {
		return nil, fmt.Errorf("%s ID is empty", platform)
	}
	links, err := s.resolveByPlatform(platform, entityType, entityID)
	if err != nil {
		return nil, fmt.Errorf("resolve failed for %s %s: %w", platform, entityID, err)
	}
	return buildAvailability("", links), nil
}

func (s *Client) CheckAvailabilityFromURL(inputURL string) (*TrackAvailability, error) {
	links, err := s.resolve(inputURL)
	if err != nil {
		return nil, fmt.Errorf("resolve failed for URL %s: %w", inputURL, err)
	}
	return buildAvailability("", links), nil
}

func (s *Client) CheckAlbumAvailability(spotifyAlbumID string) (*AlbumAvailability, error) {
	spotifyURL := fmt.Sprintf("https://open.spotify.com/album/%s", spotifyAlbumID)
	links, err := s.resolve(spotifyURL)
	if err != nil {
		return nil, fmt.Errorf("resolve failed for album %s: %w", spotifyAlbumID, err)
	}

	a := &AlbumAvailability{SpotifyID: spotifyAlbumID}
	if deezerLink, ok := links["deezer"]; ok && deezerLink.URL != "" {
		a.Deezer = true
		a.DeezerURL = deezerLink.URL
		a.DeezerID = extractDeezerIDFromURL(deezerLink.URL)
	}
	return a, nil
}
