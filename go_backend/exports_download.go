package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/download"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// =========================================================================
// DOWNLOAD
// =========================================================================

func DownloadTrack(requestJSON string) string {
	if premiumChecker != nil {
		if err := premiumChecker.CheckDownloadAllowed(); err != nil {
			return jsonError(err)
		}
	}
	var req download.Request
	if err := json.Unmarshal([]byte(requestJSON), &req); err != nil {
		return jsonError(err)
	}
	result := downloadOrch.Download(req)
	data, _ := json.Marshal(result)
	return string(data)
}

func GetDownloadProgress() string {
	if downloadOrch == nil {
		return `[]`
	}
	data, _ := json.Marshal(downloadOrch.Progress().GetAll())
	return string(data)
}

func CancelDownload(itemID string) bool {
	if downloadOrch == nil {
		return false
	}
	downloadOrch.Progress().Remove(itemID)
	return true
}

func DownloadBatch(tracksJSON string) string {
	if premiumChecker != nil {
		if err := premiumChecker.CheckDownloadAllowed(); err != nil {
			return jsonError(err)
		}
	}
	if downloadOrch == nil {
		return `{"error":"no inicializado"}`
	}
	var reqs []download.Request
	if err := json.Unmarshal([]byte(tracksJSON), &reqs); err != nil {
		return jsonError(err)
	}
	results := downloadOrch.DownloadBatch(reqs)
	data, _ := json.Marshal(results)
	return string(data)
}

// ExtensionDownload triggers a full JS extension download pipeline.
func ExtensionDownload(payload string) string {
	var params struct {
		ExtProvider string `json:"extProvider"`
		TrackID     string `json:"trackID"`
		Quality     string `json:"quality"`
		OutputPath  string `json:"outputPath"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	if premiumChecker != nil {
		if err := premiumChecker.CheckDownloadAllowed(); err != nil {
			return jsonError(err)
		}
	}
	p := reg.Get(params.ExtProvider)
	if p == nil {
		return jsonErrorStr("extensión no encontrada")
	}
	ep, ok := p.(*provider.ExtensionProvider)
	if !ok {
		return jsonErrorStr("no es una extensión válida")
	}
	progressID := "ext:" + params.ExtProvider + ":" + params.TrackID
	downloadOrch.Progress().Add(progressID, params.TrackID, params.ExtProvider)

	result := ep.Download(params.TrackID, params.Quality, params.OutputPath, func(percent int) {
		downloadOrch.Progress().Update(progressID, download.StatusDownloading, float64(percent)/100.0)
	})
	if result.Success {
		downloadOrch.Progress().SetOutputPath(progressID, result.FilePath)
	} else {
		downloadOrch.Progress().SetError(progressID, result.Error)
	}
	data, _ := json.Marshal(result)
	return string(data)
}
