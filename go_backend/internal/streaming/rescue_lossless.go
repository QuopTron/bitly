// ─────────────────────────────────────────────────────────────
// rescue_lossless.go — Canal SIN PÉRDIDA de la reproducción: resuelve el
// FLAC por ISRC (flac-rescue → arcod / Internet Archive) EN PARALELO al
// camino rápido.
//
// Por qué existe: con calidad sin pérdida, el camino rápido devolvía el
// audio de YouTube y la reproducción terminaba ahí. El canal que SÍ tiene
// el FLAC (arcod: ~0,6 s, archivo completo de ~20 MB y con soporte de
// Range, así que se reproduce en vivo sin bajarlo antes) nunca llegaba a
// pedirse desde la reproducción: su audio aparecía solo en las DESCARGAS.
// Acá se lo consulta desde el primer instante y el llamador prefiere su
// resultado si llega dentro de la ventana (ver stream_package_fallback.go).
//
// Se conecta con: play_types.go (fuentesLosslessSiempre) y rescue_race.go
// (la carrera). Parte del flujo: reproducción sin pérdida.
// ─────────────────────────────────────────────────────────────

package streaming

import (
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

const (
	// VentanaSinPerdida es lo que el llamador espera al canal cuando ya
	// tiene un audio con pérdida en la mano. Es CORTA a propósito: el canal
	// resuelve en ~0,6 s cuando tiene el tema, y si no lo tiene no se puede
	// dejar al usuario en silencio (el tope de arranque es 4 s).
	VentanaSinPerdida = 900 * time.Millisecond
	// PresupuestoSinPerdida acota lo que el canal puede tardar por su
	// cuenta: dos peticiones al sitio (buscar el ISRC + pedir el enlace).
	PresupuestoSinPerdida = 2 * time.Second
	// VentanaSinPerdidaDerivada es la ventana del canal cuando el pedido NO
	// traía ISRC y hay que DERIVARLO antes de poder pedir el FLAC (título y
	// artista presentes). Es más larga que VentanaSinPerdida porque el canal
	// paga dos fases en serie —buscar el ISRC en los catálogos y recién
	// después pedir el enlace sin pérdida— y sin ese margen un tema de
	// YouTube/SoundCloud nunca alcanzaría a preferir el FLAC y se quedaría
	// con el stream lossy por nombre.
	//
	// Sigue siendo acotada a propósito: se paga recién cuando el camino
	// rápido YA tiene un audio en la mano (no es silencio lo que sufre el
	// usuario) y solo con calidad sin pérdida, que es el pedido explícito.
	// Es, además, una ventana TOTAL desde que se abrió el canal, no por
	// consulta: el llamador puede mirar el canal dos veces y no vuelve a
	// esperar el margen entero (ver paqueteConElMejorAudio).
	VentanaSinPerdidaDerivada = 2500 * time.Millisecond
)

// CalidadPideLossless informa si la calidad pedida es sin pérdida.
func CalidadPideLossless(quality string) bool { return calidadPideLossless(quality) }

// fuentesLosslessDeStreaming son las fuentes sin pérdida registradas que
// pueden entregar audio EN VIVO (flac-rescue, Internet Archive). Soulseek
// queda afuera: puede dar FLAC pero solo por descarga (de nada sirve
// esperarlo en la reproducción).
func fuentesLosslessDeStreaming(reg *provider.Registry) []string {
	if reg == nil {
		return nil
	}
	var out []string
	for _, name := range ordenProvidersStreaming(reg) {
		// Sin sesión: las de la lista fija (flac-rescue/Internet Archive).
		// Con sesión lista: también las extensiones de catálogo que pueden
		// entregar FLAC en vivo (deezer/qobuz-web/tidal-web/amazon), que son
		// las que un pedido sin ISRC no alcanzaba a aprovechar.
		if esFuenteLosslessSiempre(name) || (esProveedorLossless(name) && fuenteStreameableAhora(reg, name)) {
			out = append(out, name)
		}
	}
	return out
}

// StreamLosslessPorISRC resuelve el audio SIN PÉRDIDA de [isrc] y devuelve
// (url, proveedor). Vacío = el canal no tiene ese tema (nunca es un error
// para el llamador: su audio con pérdida sigue valiendo).
//
// Pide UNA sola calidad, la sin pérdida: la cascada de calidades
// (calidadesDisponibles) devolvería un MP3 y este canal existe justamente
// para no conformarse con el transcodificado cuando el FLAC está.
func StreamLosslessPorISRC(reg *provider.Registry, isrc, quality string) (string, string) {
	if reg == nil || isrc == "" || !calidadPideLossless(quality) {
		return "", ""
	}
	names := fuentesLosslessDeStreaming(reg)
	if len(names) == 0 {
		return "", ""
	}
	url, prov, _ := carreraRescueConFiltro(reg, names, PresupuestoSinPerdida, len(names),
		func(name string, p provider.Provider) (string, bool) {
			t, err := p.GetTrackByISRC(isrc)
			if err != nil || t == nil || t.ID == "" {
				return "", false
			}
			return pedirSinPerdida(p, t.ID)
		}, politicaCarrera{})
	return url, prov
}

// pedirSinPerdida pide el audio de [id] sin pérdida y devuelve la URL ("" si
// la fuente no lo tiene o está enfriada). El segundo valor es el veredicto
// de verificación, que en este canal no aplica: estas fuentes no piden
// sesión firmada.
func pedirSinPerdida(p provider.Provider, id string) (string, bool) {
	if id == "" || cooldown.IsCooled(p.Name()) {
		return "", false
	}
	url, err := p.GetStreamURL(id, "flac")
	if err != nil || url == "" || !esURLReproducible(url) {
		return "", false
	}
	cooldown.MarkOk(p.Name())
	return url, false
}
