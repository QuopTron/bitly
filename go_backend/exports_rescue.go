package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/rescue"
)

// =========================================================================
// RESCUE
// =========================================================================

func RescueTrack(payload string) string {
	if rescueSvc == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		ISRC       string `json:"isrc"`
		TrackName  string `json:"trackName"`
		ArtistName string `json:"artistName"`
		Quality    string `json:"quality"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	result := rescueSvc.RescueByISRC(params.ISRC, params.TrackName, params.ArtistName, params.Quality)
	data, _ := json.Marshal(result)
	return string(data)
}

func RescueBatch(tracksJSON string) string {
	if rescueSvc == nil {
		return `{"error":"no inicializado"}`
	}
	var reqs []rescue.RescueRequest
	if err := json.Unmarshal([]byte(tracksJSON), &reqs); err != nil {
		return jsonError(err)
	}
	results := rescueSvc.RescueBatch(reqs)
	data, _ := json.Marshal(results)
	return string(data)
}

func EnrichMetadata(isrc string) string {
	if enricher == nil {
		return `{"error":"no inicializado"}`
	}
	result, err := enricher.EnrichFromISRC(isrc)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(result)
	return string(data)
}

// =========================================================================
// RECOMMENDATIONS
// =========================================================================

func GetSimilarTracks(payload string) string {
	if recommendEng == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		TrackTitle  string `json:"trackTitle"`
		ArtistName  string `json:"artistName"`
		Limit       int    `json:"limit"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	results, err := recommendEng.SimilarTracks(params.TrackTitle, params.ArtistName, params.Limit)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(results)
	return string(data)
}

func GetSimilarArtists(payload string) string {
	if recommendEng == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		ArtistName string `json:"artistName"`
		Limit      int    `json:"limit"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	results, err := recommendEng.SimilarArtists(params.ArtistName, params.Limit)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(results)
	return string(data)
}
