package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/audio"
	"github.com/zarz/bitly/go_backend/internal/convert"
	"github.com/zarz/bitly/go_backend/internal/cue"
	"github.com/zarz/bitly/go_backend/internal/playlist"
)

// =========================================================================
// CONVERSION
// =========================================================================

func ConvertFile(requestJSON string) string {
	var req struct {
		convert.Config
		InputPath string `json:"inputPath"`
	}
	if err := json.Unmarshal([]byte(requestJSON), &req); err != nil {
		return jsonError(err)
	}
	result, err := convert.Convert(req.Config, req.InputPath)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(result)
	return string(data)
}

// =========================================================================
// PLAYLIST
// =========================================================================

func ExportPlaylistXSPF(payload string) string {
	var params struct {
		TracksJSON string `json:"tracksJSON"`
		Name       string `json:"name"`
		Creator    string `json:"creator"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	var tracks []playlist.PlaylistTrack
	if err := json.Unmarshal([]byte(params.TracksJSON), &tracks); err != nil {
		return jsonError(err)
	}
	pl := playlist.New(params.Name, params.Creator, tracks)
	xmlStr, err := pl.ExportXML()
	if err != nil {
		return jsonError(err)
	}
	result := map[string]string{"xspf": xmlStr}
	data, _ := json.Marshal(result)
	return string(data)
}

func ParsePlaylistXSPF(xspfContent string) string {
	x, err := playlist.Unmarshal(xspfContent)
	if err != nil {
		return jsonError(err)
	}
	pl := playlist.FromXSPF(x)
	data, _ := json.Marshal(pl)
	return string(data)
}

// =========================================================================
// CUE
// =========================================================================

func ParseCUE(cueContent string) string {
	result, err := cue.Parse(cueContent)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(result)
	return string(data)
}

func ReadFileMetadata(filePath string) string {
	meta, err := audio.ReadFileMetadata(filePath)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(meta)
	return string(data)
}

// EmbedCover writes cover art data into an audio file.
func EmbedCover(payload string) string {
	var params struct {
		FilePath  string `json:"path"`
		CoverData []byte `json:"data"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	if err := audio.WriteCover(params.FilePath, params.CoverData); err != nil {
		return jsonError(err)
	}
	return `{"ok":true}`
}
