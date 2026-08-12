package gobackend

import (
	"encoding/json"
	"time"

	"github.com/zarz/bitly/go_backend/internal/scrobble"
)

// =========================================================================
// SCROBBLING
// =========================================================================

func SetupScrobbling(configJSON string) bool {
	var cfg struct {
		LastFMKey    string `json:"lastfmKey"`
		LastFMSecret string `json:"lastfmSecret"`
		LBToken      string `json:"listenBrainzToken"`
	}
	if err := json.Unmarshal([]byte(configJSON), &cfg); err != nil {
		return false
	}
	scrobbleClient = scrobble.NewClient(cfg.LastFMKey, cfg.LastFMSecret, cfg.LBToken)
	return true
}

// ScrobbleTrack submits a playback scrobble to all configured services.
func ScrobbleTrack(payload string) string {
	if scrobbleClient == nil {
		return `{"error":"scrobbling no configurado"}`
	}
	var params struct {
		TrackJSON        string `json:"trackJSON"`
		LastfmSessionKey string `json:"lastfmSessionKey"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	var track scrobble.Track
	if err := json.Unmarshal([]byte(params.TrackJSON), &track); err != nil {
		return jsonError(err)
	}
	if track.Timestamp == 0 {
		track.Timestamp = time.Now().Unix()
	}
	var errors []string
	if err := scrobbleClient.ScrobbleLastFM(track, params.LastfmSessionKey); err != nil {
		errors = append(errors, "lastfm:"+err.Error())
	}
	if err := scrobbleClient.ScrobbleListenBrainz(track); err != nil {
		errors = append(errors, "lb:"+err.Error())
	}
	if len(errors) > 0 {
		resp := map[string]interface{}{"ok": false, "errors": errors}
		data, _ := json.Marshal(resp)
		return string(data)
	}
	return `{"ok":true}`
}
