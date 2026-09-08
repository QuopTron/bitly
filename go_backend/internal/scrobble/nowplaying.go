package scrobble

import (
	"encoding/json"
	"fmt"
	"net/url"
)

// Now-playing (lo que suena ahora) para Last.fm y ListenBrainz.
//
// Port del ScrobbleService Dart (lib/backend/services/scrobble_service.dart):
// updateNowPlaying enviaba track.updateNowPlaying a Last.fm y listen_type
// "playing_now" a ListenBrainz, sin timestamp. Acá corre en Go y Flutter solo
// manda el track por RPC (exports UpdateNowPlaying).

// UpdateNowPlaying reporta lo que se está reproduciendo a los servicios
// configurados. Los errores por servicio se agregan y se devuelven juntos.
func (c *Client) UpdateNowPlaying(track Track, sessionKey string) error {
	var errs []error
	if err := c.UpdateNowPlayingLastFM(track, sessionKey); err != nil {
		errs = append(errs, err)
	}
	if err := c.UpdateNowPlayingListenBrainz(track); err != nil {
		errs = append(errs, err)
	}
	if len(errs) > 0 {
		return fmt.Errorf("scrobble: now playing errors: %v", errs)
	}
	return nil
}

// UpdateNowPlayingLastFM envía track.updateNowPlaying a Last.fm (sin timestamp).
func (c *Client) UpdateNowPlayingLastFM(track Track, sessionKey string) error {
	if c.lastfmKey == "" || sessionKey == "" {
		return fmt.Errorf("scrobble: last.fm not configured")
	}
	data := url.Values{
		"method":  {"track.updateNowPlaying"},
		"api_key": {c.lastfmKey},
		"sk":      {sessionKey},
		"track":   {track.TrackName},
		"artist":  {track.ArtistName},
		"album":   {track.AlbumName},
		"format":  {"json"},
	}
	if track.DurationMs > 0 {
		data.Set("duration", fmt.Sprintf("%d", track.DurationMs/1000))
	}
	apiURL := c.lastfmURL
	if apiURL == "" {
		apiURL = "https://ws.audioscrobbler.com/2.0/"
	}
	return postForm(c, apiURL, data)
}

// UpdateNowPlayingListenBrainz envía listen_type "playing_now" a ListenBrainz.
func (c *Client) UpdateNowPlayingListenBrainz(track Track) error {
	if c.lbToken == "" {
		return fmt.Errorf("scrobble: listenbrainz not configured")
	}
	payload := map[string]interface{}{
		"listen_type": "playing_now",
		"payload": []map[string]interface{}{
			{
				"track_metadata": map[string]interface{}{
					"artist_name":  track.ArtistName,
					"track_name":   track.TrackName,
					"release_name": track.AlbumName,
				},
			},
		},
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	apiURL := c.lbURL
	if apiURL == "" {
		apiURL = "https://api.listenbrainz.org/1/submit-listens"
	}
	return postJSON(c, apiURL, body, c.lbToken)
}
