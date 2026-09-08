package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/streaming"
)

// streamPackageFallback is the real-playback (AllowFallback=true) fast path of
// GetStreamPackage: it fails fast on cached failures, tries the preferred
// full-stream provider, then the multi-provider rescue, then the download
// pipeline, always returning a complete RPC response string.
func streamPackageFallback(params *streamPackageParams) string {
	// Fail fast: if this exact track just failed the full provider walk
	// (seconds ago), return the cached error immediately instead of walking
	// every provider + mirror again (10-30s) for a result that can't have
	// changed. Clear-on-success below keeps the window short and honest.
	failKey := streamFailKey(params.ISRC, params.SpotifyID, params.DeezerID, params.TidalID, params.QobuzID, params.TrackID)
	if failKey != "" {
		if cachedFail, hit := streamFailGet(failKey); hit {
			return streamFailErrorJSON(cachedFail)
		}
	}
	// Un veredicto de verificacion del proveedor preferido (su sesion
	// necesita completarse para streamear). Se recuerda abajo para que el
	// chance first: a playing song always beats a verification modal.
	var preferredVerify *streaming.VerifyRequiredError
	if streaming.IsFullStreamProvider(params.PreferredProvider) {
		url, name, err := streaming.StreamQuick(reg, params.PreferredProvider, params.TrackID, params.Quality, params.ISRC, params.SpotifyID, params.DeezerID, params.TidalID, params.QobuzID, params.TrackName, params.ArtistName)
		if err == nil && url != "" {
			streamFailClear(failKey)
			pkg := &streaming.StreamPackage{AudioURL: url, Provider: name, Quality: params.Quality}
			data, _ := json.Marshal(pkg)
			return string(data)
		}
		// El proveedor preferido tiene la cancion exacta pero necesita su
		// sesion firmada verificada (p. ej. deezer VERIFY_REQUIRED). Se
		// recuerda el veredicto
		// verdict but DON'T fail yet: another FULL-STREAM provider may
		// serve the exact same track via ISRC / cross-provider id, so fall
		// through to the rescue pass below and only surface verification
		// cuando nada mas puede streamearla.
		if verr, ok := err.(*streaming.VerifyRequiredError); ok {
			preferredVerify = verr
		}
	}

	// Cuando el proveedor preferido no expone un stream directo (fuentes
	// preview/drm: tidal, apple, amazon, qobuz, spotify-web — or a full-stream
	// source that is verification-blocked, e.g. deezer VERIFY_REQUIRED),
	// another FULL-STREAM provider (deezer/soundcloud/ytmusic/youtube)
	// may serve the same exact track via its ISRC / cross-provider id in
	// ~1-2s. Probe them before committing to the slow download pipeline.
	if url, name, err := streaming.RescueStreamURL(reg, params.Quality, params.ISRC, params.SpotifyID, params.DeezerID, params.TidalID, params.QobuzID, params.TrackName, params.ArtistName); err == nil && url != "" {
		streamFailClear(failKey)
		pkg := &streaming.StreamPackage{AudioURL: url, Provider: name, Quality: params.Quality}
		data, _ := json.Marshal(pkg)
		return string(data)
	} else if verr, ok := err.(*streaming.VerifyRequiredError); ok {
		// La cancion exacta se encontro en un proveedor full-stream pero su
		// sesion no esta verificada y nada mas pudo streamearla. El
		// client opens the modal for [service]; completing it makes the
		// song play. Skip the slow fallback download — it would walk every
		// provider (10-30s) and end on the same verification verdict.
		return streamVerifyErrorJSON(verr)
	}
	// Rescue found nothing at all: if the PREFERRED provider (the user's
	// source) was verification-blocked, that verdict is more actionable
	// than a generic "no stream" — surface it so the client can prompt
	// Al usuario para que complete la verificacion.
	if preferredVerify != nil {
		return streamVerifyErrorJSON(preferredVerify)
	}

	// Fast path exhausted: enrich the ISRC now (only on real playback, only
	// despues de los probes de stream directo) para que la descarga de
	// respaldo coincida con el track exacto entre proveedores en vez de
	// hacer una busqueda por nombre desde cero.
	streamEnrichISRC(params)
	out := streamFallbackDownload(params.TrackID, params.Quality, params.PreferredProvider, params.TrackName, params.ArtistName, params.ISRC, params.DurationMS, params.SpotifyID, params.DeezerID, params.TidalID, params.QobuzID)
	if out.encrypted != nil {
		return streamEncryptedJSON(out.encrypted, params.PreferredProvider)
	}
	if out.fileURL != "" {
		streamFailClear(failKey)
		pkg := &streaming.StreamPackage{
			AudioURL: out.fileURL,
			Provider: "fallback",
			Quality:  params.Quality,
		}
		data, _ := json.Marshal(pkg)
		return string(data)
	}
	if out.err != nil {
		// Everything failed. Remember this exact track so the next tap
		// Devuelve rapido en vez de re-recorrer todos los proveedores, y luego
		// expone el error estructurado (errorType/service con el nombre del
		// proveedor que realmente necesita verificacion, p. ej. amazon VERIFY_REQUIRED).
		streamFailSet(failKey, out.err.Error(), out.errorType, out.service)
		return streamFallbackErrorJSON(out.err, out)
	}
	return `{"error":"sin stream"}`
}
