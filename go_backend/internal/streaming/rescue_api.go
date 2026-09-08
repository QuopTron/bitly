package streaming

import (
	"fmt"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// rescueByIdentifiers sondea todos los proveedores FULL-STREAM por la cancion
// EXACTA via sus identificadores cross-provider — la misma ruta CheckAvailability
// que StreamQuick usa para el proveedor preferido, pero corrida en paralelo a
// lo largo de todos los proveedores full-stream. Es la ruta mas rapida para una
// cancion tidal/amazon/qobuz/spotify con id cross-provider: cada proveedor
// resuelve el id (o ISRC) en ~1-2s sin ninguna busqueda por nombre.
func rescuePorIdentificadores(reg *provider.Registry, quality, isrc, spotifyID, deezerID, tidalID, qobuzID, trackName, artistName string) (string, string, bool) {
	if isrc == "" && spotifyID == "" && deezerID == "" && tidalID == "" && qobuzID == "" {
		return "", "", false
	}
	names := ordenProvidersStreaming(reg)
	url, prov, verified := carreraRescue(reg, names, 5*time.Second, 2, func(name string, p provider.Provider) (string, bool) {
		resolvedID := ""
		if ep, ok := p.(*provider.ExtensionProvider); ok {
			if id, found := ep.CheckAvailability(isrc, trackName, artistName, spotifyID, deezerID, tidalID, qobuzID, 0); found && id != "" {
				resolvedID = id
			}
		}
		if resolvedID == "" && isrc != "" {
			if t, err := p.GetTrackByISRC(isrc); err == nil && t != nil && t.ID != "" {
				resolvedID = t.ID
			}
		}
		if resolvedID == "" {
			return "", false
		}
		// Mismo guard que la fase 1 de rescueStream: nunca streamear un
		// candidato sin verificar cuando conocemos el titulo/artista pedido.
		if trackName != "" && verificarMatchStream(p, resolvedID, trackName, artistName, isrc, true) == "" {
			return "", false
		}
		return rescueProviderUnaVez(p, resolvedID, quality)
	})
	return url, prov, verified
}

// RescueStreamURL probes every registered FULL-STREAM provider (deezer,
// soundcloud, ytmusic, youtube) for a direct http stream of the exact track,
// resolved via its identifiers (ISRC / cross-provider ids, then a strict
// original-track name search) — the same fast route StreamQuick uses for the
// preferred provider, but across all full-stream providers. It is the "instant
// stream" pass used before the slow download pipeline for tracks whose
// preferred source (tidal/apple/amazon/qobuz/spotify-web) exposes no direct
// stream. Returns (url, provider, err).
func RescueStreamURL(reg *provider.Registry, quality, isrc, spotifyID, deezerID, tidalID, qobuzID, trackName, artistName string) (string, string, error) {
	if reg == nil {
		return "", "", fmt.Errorf("no inicializado")
	}
	// Serialize rescue walks so batch play (3+ concurrent getStreamPackage)
	// does not flood providers with parallel requests that trigger rate limits
	// (tidal 429 → VERIFY_REQUIRED, soundcloud 401).  A buffered channel of 2
	// Permite dos walks simultaneos (p. ej. cancion actual + prefetch del
	// siguiente) mientras bloquea un tercero hasta que uno termine.
	select {
	case rescueWalkGate <- struct{}{}:
		defer func() { <-rescueWalkGate }()
	case <-time.After(15 * time.Second):
		// Don't block playback forever — if the gate is saturated the caller
		// already has too many in-flight walks; fall through and try anyway.
	}
	// Si no hay identificador ni nombre, no hay nada con que resolver.
	if isrc == "" && spotifyID == "" && deezerID == "" && tidalID == "" && qobuzID == "" && trackName == "" {
		return "", "", fmt.Errorf("sin identificador de track")
	}
	// Phase 0 — identifiers first: the exact track resolved via cross-provider
	// ids / ISRC, raced in parallel across every full-stream provider. A track
	// from ANY source (search item, album/playlist/artist detail, feed) that
	// carries spotify/deezer/tidal/qobuz id or an ISRC starts playing in ~1-2s
	// instead of falling into the slow name-search below. Search results in
	// particular often lack an ISRC but always carry the source provider's id.
	// Una senal de verificacion aqui es RECORDADA, nunca fatal: las fases de
	// busqueda por nombre siguientes aun pueden encontrar la cancion en un
	// proveedor que no indexa ISRC / ids cross-provider (p. ej. youtube) — una
	// cancion sonando siempre gana a un modal de verificacion, asi que el
	// veredicto solo se devuelve cuando nada streamea.
	var idVerify string
	if url, prov, verified := rescuePorIdentificadores(reg, quality, isrc, spotifyID, deezerID, tidalID, qobuzID, trackName, artistName); url != "" {
		return url, prov, nil
	} else if verified {
		idVerify = prov
	}
	track := &provider.TrackResult{
		ISRC:   isrc,
		Title:  trackName,
		Artist: artistName,
	}
	url, prov, attempted, verified := rescueStream(reg, track, trackName, artistName, quality)
	if url != "" {
		return url, prov, nil
	}
	if verified {
		return "", prov, &VerifyRequiredError{Service: prov}
	}
	if idVerify != "" {
		return "", idVerify, &VerifyRequiredError{Service: idVerify}
	}
	if len(attempted) > 0 {
		return "", "", fmt.Errorf("sin stream en: %s", strings.Join(attempted, ", "))
	}
	return "", "", fmt.Errorf("sin stream en ningun proveedor")
}
