package availability

import "fmt"

func (s *Client) GetDeezerIDFromSpotify(spotifyTrackID string) (string, error) {
	a, err := s.CheckTrackAvailability(spotifyTrackID, "")
	if err != nil {
		return "", err
	}
	if !a.Deezer || a.DeezerID == "" {
		return "", fmt.Errorf("track not found on Deezer")
	}
	return a.DeezerID, nil
}

func (s *Client) GetYouTubeURLFromSpotify(spotifyTrackID string) (string, error) {
	a, err := s.CheckTrackAvailability(spotifyTrackID, "")
	if err != nil {
		return "", err
	}
	if !a.YouTube || a.YouTubeURL == "" {
		return "", fmt.Errorf("track not found on YouTube")
	}
	return a.YouTubeURL, nil
}

func (s *Client) GetTidalURLFromDeezer(deezerTrackID string) (string, error) {
	a, err := s.CheckAvailabilityFromDeezer(deezerTrackID)
	if err != nil {
		return "", err
	}
	if !a.Tidal || a.TidalURL == "" {
		return "", fmt.Errorf("track not found on Tidal")
	}
	return a.TidalURL, nil
}

func (s *Client) GetStreamingURLs(spotifyTrackID string) (map[string]string, error) {
	availability, err := s.CheckTrackAvailability(spotifyTrackID, "")
	if err != nil {
		return nil, err
	}
	urls := make(map[string]string)
	if availability.TidalURL != "" {
		urls["tidal"] = availability.TidalURL
	}
	if availability.AmazonURL != "" {
		urls["amazon"] = availability.AmazonURL
	}
	return urls, nil
}

func (s *Client) GetSpotifyIDFromDeezer(deezerTrackID string) (string, error) {
	availability, err := s.CheckAvailabilityFromDeezer(deezerTrackID)
	if err != nil {
		return "", err
	}
	if availability.SpotifyID == "" {
		return "", fmt.Errorf("track not found on Spotify")
	}
	return availability.SpotifyID, nil
}

func (s *Client) GetAmazonURLFromDeezer(deezerTrackID string) (string, error) {
	availability, err := s.CheckAvailabilityFromDeezer(deezerTrackID)
	if err != nil {
		return "", err
	}
	if !availability.Amazon || availability.AmazonURL == "" {
		return "", fmt.Errorf("track not found on Amazon Music")
	}
	return availability.AmazonURL, nil
}

func (s *Client) GetYouTubeURLFromDeezer(deezerTrackID string) (string, error) {
	availability, err := s.CheckAvailabilityFromDeezer(deezerTrackID)
	if err != nil {
		return "", err
	}
	if !availability.YouTube || availability.YouTubeURL == "" {
		return "", fmt.Errorf("track not found on YouTube")
	}
	return availability.YouTubeURL, nil
}

func (s *Client) GetDeezerAlbumIDFromSpotify(spotifyAlbumID string) (string, error) {
	availability, err := s.CheckAlbumAvailability(spotifyAlbumID)
	if err != nil {
		return "", err
	}
	if !availability.Deezer || availability.DeezerID == "" {
		return "", fmt.Errorf("album not found on Deezer")
	}
	return availability.DeezerID, nil
}
