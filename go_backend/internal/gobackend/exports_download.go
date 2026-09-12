package gobackend

import (
	"encoding/json"
	"os"

	"github.com/zarz/bitly/go_backend/internal/download"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// =========================================================================
// DOWNLOAD
// =========================================================================

// resultadoLocalSiExiste devuelve un resultado exitoso si la canción ya está en
// la biblioteca propia del usuario (importada desde sus archivos: compras de
// Amazon, iTunes Match, FLAC propios). Así la descarga no la vuelve a bajar ni
// gasta red, y la app usa el archivo que ya tiene en disco.
func resultadoLocalSiExiste(req download.Request) (*download.Result, bool) {
	if indiceLocal == nil || req.ISRC == "" {
		return nil, false
	}
	ruta := indiceLocal.RutaLocal(req.ISRC)
	if ruta == "" {
		return nil, false
	}
	return &download.Result{
		ItemID:   req.ItemID,
		Success:  true,
		Provider: "local",
		FilePath: ruta,
		Local:    true,
	}, true
}

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
	// Dedupe por ISRC: si ya lo tiene importado, no se descarga de nuevo.
	if local, yaEsta := resultadoLocalSiExiste(req); yaEsta {
		data, _ := json.Marshal(local)
		return string(data)
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
	// Cancel via cancel registry if available.
	if cancelReg != nil {
		cancelReg.CancelDownload(itemID)
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
	// Dedupe por ISRC manteniendo el orden original: las que ya están en la
	// biblioteca local se resuelven sin red y el resto va al orquestador.
	resultados := make([]*download.Result, len(reqs))
	pendientes := make([]download.Request, 0, len(reqs))
	indices := make([]int, 0, len(reqs))
	for i, req := range reqs {
		if local, yaEsta := resultadoLocalSiExiste(req); yaEsta {
			resultados[i] = local
			continue
		}
		pendientes = append(pendientes, req)
		indices = append(indices, i)
	}
	if len(pendientes) > 0 {
		parciales := downloadOrch.DownloadBatch(pendientes)
		for j, r := range parciales {
			resultados[indices[j]] = r
		}
	}
	data, _ := json.Marshal(resultados)
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
		return jsonErrorString("extensión no encontrada")
	}
	ep, ok := p.(*provider.ExtensionProvider)
	if !ok {
		return jsonErrorString("no es una extensión válida")
	}
	progressID := "ext:" + params.ExtProvider + ":" + params.TrackID
	downloadOrch.Progress().Add(progressID, params.TrackID, params.ExtProvider)

	// Register cancellation context for this download.
	if cancelReg != nil {
		ctx := cancelReg.InitDownloadCancel(progressID)
		defer cancelReg.ClearDownloadCancel(progressID)
		_ = ctx // context available for future cancellation checks
	}

	// Route output path through staging manager for atomic writes.
	outputPath := params.OutputPath
	if staging != nil {
		outputPath = download.StagePath(params.OutputPath)
	}

	result := ep.Download(params.TrackID, params.Quality, outputPath, func(percent int) {
		downloadOrch.Progress().Update(progressID, download.StatusDownloading, float64(percent)/100.0)
	})
	if result.Success {
		// Commit staged file to final location.
		if staging != nil {
			if err := os.Rename(outputPath, params.OutputPath); err != nil {
				result.Error = "staging commit failed: " + err.Error()
				result.Success = false
			}
		}
		downloadOrch.Progress().SetOutputPath(progressID, result.FilePath)
	} else {
		// Clean up staging on failure.
		if staging != nil {
			os.Remove(outputPath)
		}
		downloadOrch.Progress().SetError(progressID, result.Error)
	}
	data, _ := json.Marshal(result)
	return string(data)
}
