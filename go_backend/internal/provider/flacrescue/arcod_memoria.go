// ─────────────────────────────────────────────────────────────
// arcod_memoria.go — Estado del canal arcod que no depende de la red: la
// memoria de ISRC → id de pista y el mapeo de calidad del sitio.
//
// Por qué se memoriza el id: el catálogo del sitio ES el de Qobuz, así que
// la grabación de un ISRC no cambia de id. Guardarlo convierte las
// reproducciones siguientes en UNA petición en vez de dos.
//
// Se conecta con: arcod.go y client.go (estado del cliente).
// Parte del flujo: rescate de FLAC por stream y por descarga.
// ─────────────────────────────────────────────────────────────

package flacrescue

// Códigos de calidad del lector del sitio (los mismos que usa su cliente).
const (
	// calidadArcodFLAC es FLAC 16/44.1 (CD): 21,4 MB un tema de 3:03
	// medido, ~0,9 Mbps. El hi-res (24/96 = 37,6 MB) se probó y es el
	// doble de peso para la misma canción sin pérdida.
	calidadArcodFLAC = 6
	// calidadArcodMP3 es MP3 320.
	calidadArcodMP3 = 5
)

// calidadArcodStream traduce el formato pedido al código de calidad del
// sitio. Sin formato reconocible —o si el pedido es sin pérdida— se pide
// FLAC: es lo que el usuario quiere cuando no eligió nada.
func calidadArcodStream(formato string) int {
	switch normalizarFormato(formato) {
	case "MP3_128", "MP3_320":
		return calidadArcodMP3
	default:
		return calidadArcodFLAC
	}
}

// idArcodGuardado devuelve el id memorizado de un ISRC (vacío si no está).
func (c *Client) idArcodGuardado(isrc string) string {
	c.idsArcodsMu.Lock()
	defer c.idsArcodsMu.Unlock()
	return c.idsArcods[isrc]
}

// guardarIDArcod memoriza el id de un ISRC (y acota el tamaño de la memoria,
// igual que la caché de resoluciones).
func (c *Client) guardarIDArcod(isrc, id string) {
	if isrc == "" || id == "" {
		return
	}
	c.idsArcodsMu.Lock()
	defer c.idsArcodsMu.Unlock()
	if len(c.idsArcods) > maxCache {
		c.idsArcods = map[string]string{}
	}
	c.idsArcods[isrc] = id
}
