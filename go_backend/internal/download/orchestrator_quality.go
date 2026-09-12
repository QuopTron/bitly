package download

import (
	"log"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// effectiveQuality maps quality labels to a canonical set understood by extensions.
func calidadEfectiva(q string) string {
	if q == "" {
		return "LOSSLESS"
	}
	switch strings.ToUpper(q) {
	case "LOSSLESS", "HI_RES", "FLAC":
		return "LOSSLESS"
	case "MP3_128", "128":
		return "MP3_128"
	default:
		return strings.ToUpper(q)
	}
}

// quiereSinPerdida reporta si el usuario pidió audio sin pérdida.
func quiereSinPerdida(q string) bool {
	switch strings.ToUpper(strings.TrimSpace(q)) {
	case "FLAC", "LOSSLESS", "HI_RES", "HI_RES_LOSSLESS":
		return true
	}
	return false
}

// esOpcionSinPerdida reporta si una opción declarada por la extensión entrega
// audio sin pérdida. Se compara por nombre (las extensiones usan ids tipo
// HI_RES_LOSSLESS / LOSSLESS / FLAC), no por posición.
//
// DOLBY_ATMOS queda FUERA a propósito: es un encode con pérdida (E-AC3) y en
// Tidal está declarado PRIMERO, así que tomarlo como "el mejor" hacía que
// pedir FLAC bajara Atmos.
func esOpcionSinPerdida(o string) bool {
	n := strings.ToUpper(strings.TrimSpace(o))
	return strings.Contains(n, "LOSSLESS") || strings.Contains(n, "FLAC") || n == "HI_RES"
}

// qualityForProvider picks a quality token the given provider actually
// recognizes. Extensions declare qualityOptions in their manifest; when the
// requested quality isn't one of them (a source provider's token that doesn't
// map to this provider), it uses the extension's own highest quality — mirroring
// el reference middleware's por-proveedor calidad selection. When el requested// quality is unavailable, the best available quality is used (quality fallback).
func calidadParaProvider(p provider.Provider, requested string) string {
	if ep, ok := p.(*provider.ExtensionProvider); ok {
		opts := ep.QualityOptions()
		if len(opts) > 0 {
			req := strings.TrimSpace(requested)
			if req != "" {
				for _, o := range opts {
					if strings.EqualFold(strings.TrimSpace(o), req) {
						return o // canonical id the extension recognizes
					}
				}
				// El pedido no coincide por nombre. Antes se caía directo a
				// opts[0] ("el mejor" de la extensión), y en Tidal opts[0] es
				// DOLBY_ATMOS: pedir FLAC bajaba un Atmos (E-AC3, con pérdida).
				// Si el usuario pidió sin pérdida, se elige la MEJOR opción sin
				// pérdida que ofrezca la fuente, respetando su orden.
				if quiereSinPerdida(req) {
					for _, o := range opts {
						if esOpcionSinPerdida(o) {
							log.Printf("[orchestrator] quality fallback: requested=%q sin pérdida, usando %q de %v para provider=%s", req, o, opts, ep.Name())
							return o
						}
					}
				}
				// Requested quality not available: fall back to the extension's
				// best quality (opts[0]) so the download never fails due to a
				// quality mismatch — matching SpotiFLAC's quality fallback.
				log.Printf("[orchestrator] quality fallback: requested=%q not in %v for provider=%s, using best=%q", req, opts, ep.Name(), opts[0])
			}
			return opts[0] // fall back to the extension's best quality
		}
	}
	return calidadEfectiva(requested)
}
