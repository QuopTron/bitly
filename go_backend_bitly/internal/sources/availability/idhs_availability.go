package availability

import (
	"fmt"
	"log"
	"strings"
)

func (c *IDHSClient) GetAvailabilityFromSpotify(spotifyTrackID string) (*TrackAvailability, error) {
	spotifyURL := fmt.Sprintf("https://open.spotify.com/track/%s", spotifyTrackID)
	adapters := []string{"tidal", "deezer"}

	result, err := c.Search(spotifyURL, adapters)
	if err != nil {
		return nil, err
	}

	availability := &TrackAvailability{
		SpotifyID: spotifyTrackID,
	}

	for _, link := range result.Links {
		if link.NotAvailable {
			continue
		}
		switch strings.ToLower(link.Type) {
		case "tidal":
			availability.Tidal = true
			availability.TidalURL = link.URL
			availability.TidalID = extractTidalID(link.URL)
		case "deezer":
			availability.Deezer = true
			availability.DeezerURL = link.URL
			availability.DeezerID = extractDeezerIDFromURL(link.URL)
		}
	}

	log.Printf("[IDHS] Availability from Spotify %s: Tidal=%v, Deezer=%v",
		spotifyTrackID, availability.Tidal, availability.Deezer)

	return availability, nil
}

func (c *IDHSClient) GetAvailabilityFromDeezer(deezerTrackID string) (*TrackAvailability, error) {
	deezerURL := fmt.Sprintf("https://www.deezer.com/track/%s", deezerTrackID)
	adapters := []string{"spotify", "tidal"}

	result, err := c.Search(deezerURL, adapters)
	if err != nil {
		return nil, err
	}

	availability := &TrackAvailability{
		Deezer:   true,
		DeezerID: deezerTrackID,
	}

	for _, link := range result.Links {
		if link.NotAvailable {
			continue
		}
		switch strings.ToLower(link.Type) {
		case "spotify":
			availability.SpotifyID = extractSpotifyID(link.URL)
		case "tidal":
			availability.Tidal = true
			availability.TidalURL = link.URL
			availability.TidalID = extractTidalID(link.URL)
		}
	}

	log.Printf("[IDHS] Availability from Deezer %s: Spotify=%s, Tidal=%v",
		deezerTrackID, availability.SpotifyID, availability.Tidal)

	return availability, nil
}
